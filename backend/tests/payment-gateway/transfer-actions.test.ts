/**
 * Unit tests for the buyer-driven half of the on-hold split
 * (settlement/transfer-actions.ts): release-on-confirm + reverse-on-return + P5.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';

const { gatewayTransfer, gatewayPayment, releaseTransfer, reverseTransfer, provider, flag } =
  vi.hoisted(() => {
    const gatewayTransfer = {
      findMany: vi.fn(),
      findFirst: vi.fn(),
      updateMany: vi.fn(),
      update: vi.fn(),
    };
    const gatewayPayment = { findUnique: vi.fn() };
    const releaseTransfer = vi.fn();
    const reverseTransfer = vi.fn();
    const provider = {
      name: 'RAZORPAY',
      createTransfers: vi.fn(),
      listTransfers: vi.fn(),
      releaseTransfer,
      reverseTransfer,
    };
    const flag = { enabled: true };
    return { gatewayTransfer, gatewayPayment, releaseTransfer, reverseTransfer, provider, flag };
  });

vi.mock('../../src/infra/db/prisma.js', () => ({
  default: { gatewayTransfer, gatewayPayment },
}));
vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: () => provider,
}));
vi.mock('../../src/modules/payment-gateway/settlement/order-split.js', () => ({
  isRouteSplitEnabled: () => flag.enabled,
}));

import {
  releaseTransfersForPurchaseRequest,
  reverseTransferForReturn,
} from '../../src/modules/payment-gateway/settlement/transfer-actions.js';

beforeEach(() => {
  vi.clearAllMocks();
  flag.enabled = true;
  gatewayPayment.findUnique.mockResolvedValue({ provider: 'RAZORPAY' });
  gatewayTransfer.updateMany.mockResolvedValue({ count: 1 });
});

describe('releaseTransfersForPurchaseRequest', () => {
  it('claim-once releases each held transfer for the child', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      { id: 1, gatewayPaymentId: 500, providerTransferRef: 'trf_1' },
    ]);

    const r = await releaseTransfersForPurchaseRequest(11);

    expect(r.released).toBe(1);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: expect.any(Date) },
    });
    expect(releaseTransfer).toHaveBeenCalledWith('trf_1');
  });

  it('skips when the claim is lost (count 0) — never releases after losing the row', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      { id: 1, gatewayPaymentId: 500, providerTransferRef: 'trf_1' },
    ]);
    gatewayTransfer.updateMany.mockResolvedValue({ count: 0 });

    const r = await releaseTransfersForPurchaseRequest(11);

    expect(r.released).toBe(0);
    expect(releaseTransfer).not.toHaveBeenCalled();
  });

  it('rolls the claim back to HELD when the provider release fails', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      { id: 1, gatewayPaymentId: 500, providerTransferRef: 'trf_1' },
    ]);
    releaseTransfer.mockRejectedValueOnce(new Error('rzp 503'));

    const r = await releaseTransfersForPurchaseRequest(11);

    expect(r.released).toBe(0);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: 'RELEASED' },
      data: { status: 'HELD', releasedAt: null },
    });
  });

  it('is a no-op when the split feature is off', async () => {
    flag.enabled = false;
    const r = await releaseTransfersForPurchaseRequest(11);
    expect(r.released).toBe(0);
    expect(gatewayTransfer.findMany).not.toHaveBeenCalled();
  });
});

describe('reverseTransferForReturn', () => {
  const transfer = (over: Record<string, unknown> = {}) => ({
    id: 1,
    gatewayPaymentId: 500,
    providerTransferRef: 'trf_1',
    amount: 60,
    reversedAmount: 0,
    ...over,
  });

  it('fully reverses and marks REVERSED', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer());

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });

    expect(r).toEqual({ reversed: true, flagged: false, shortfall: 0 });
    expect(reverseTransfer).toHaveBeenCalledWith('trf_1', 6000);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'REVERSED' }) }),
    );
  });

  it('partially reverses and marks PARTIALLY_REVERSED', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer({ amount: 60, reversedAmount: 0 }));

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 20 });

    expect(r.reversed).toBe(true);
    expect(reverseTransfer).toHaveBeenCalledWith('trf_1', 2000);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'PARTIALLY_REVERSED' }) }),
    );
  });

  it('caps the reversal at the remaining un-reversed amount (no shortfall when refund fits)', async () => {
    // ₹50 already reversed of ₹60 → ₹10 remains; a ₹10 refund fits exactly.
    gatewayTransfer.findFirst.mockResolvedValue(transfer({ amount: 60, reversedAmount: 50 }));

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 10 });

    expect(reverseTransfer).toHaveBeenCalledWith('trf_1', 1000); // ₹10
    expect(r).toEqual({ reversed: true, flagged: false, shortfall: 0 });
    // 50 + 10 == 60 → fully reversed.
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'REVERSED' }) }),
    );
  });

  it('PR-M2: reverses the seller slice AND flags the shortfall when the customer refund exceeds it', async () => {
    // ₹50 already reversed of ₹60 → only ₹10 of seller slice remains, but the
    // customer refund is ₹30 (e.g. platform-funded coupon). We claw back the
    // ₹10 we can and flag the ₹20 gap for manual recovery — never silently drop.
    gatewayTransfer.findFirst.mockResolvedValue(transfer({ amount: 60, reversedAmount: 50 }));

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 30 });

    expect(reverseTransfer).toHaveBeenCalledWith('trf_1', 1000); // ₹10 seller slice
    expect(r).toEqual({ reversed: true, flagged: true, shortfall: 20 });
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { failureReason: 'REVERSAL_SHORTFALL' },
    });
  });

  it('PR-M2: an already-fully-reversed transfer flags the entire refund as a shortfall', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer({ amount: 60, reversedAmount: 60 }));

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });

    // Nothing reversible at the provider; the whole ₹60 is unrecoverable → flag.
    expect(r).toEqual({ reversed: false, flagged: true, shortfall: 60 });
    expect(reverseTransfer).not.toHaveBeenCalled();
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { failureReason: 'REVERSAL_SHORTFALL' },
    });
  });

  it('P5: FLAGS an insufficient-balance reversal and does NOT throw (refund proceeds)', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer());
    reverseTransfer.mockRejectedValueOnce(Object.assign(new Error('insufficient'), { status: 402 }));

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });

    expect(r).toEqual({ reversed: false, flagged: true, shortfall: 0 });
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { failureReason: 'REVERSAL_INSUFFICIENT_BALANCE' },
    });
  });

  it('rethrows a non-402 provider error (reconciliation will retry)', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer());
    reverseTransfer.mockRejectedValueOnce(Object.assign(new Error('boom'), { status: 502 }));

    await expect(
      reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 }),
    ).rejects.toThrow('boom');
  });

  it('does NOT call the provider when the compare-and-set claim is lost (concurrent reversal)', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer());
    gatewayTransfer.updateMany.mockResolvedValue({ count: 0 }); // another reversal won the row

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });

    expect(r).toEqual({ reversed: false, flagged: false, shortfall: 0 });
    expect(reverseTransfer).not.toHaveBeenCalled(); // never double-reverses at the provider
  });

  it('rolls the claim back and FLAGS on a 400 insufficient-balance message', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(transfer());
    reverseTransfer.mockRejectedValueOnce(
      Object.assign(new Error('insufficient balance on account'), { status: 400 }),
    );

    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });

    expect(r).toEqual({ reversed: false, flagged: true, shortfall: 0 });
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { failureReason: 'REVERSAL_INSUFFICIENT_BALANCE' },
    });
  });

  it('is a no-op when there is no transfer for the child', async () => {
    gatewayTransfer.findFirst.mockResolvedValue(null);
    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });
    expect(r).toEqual({ reversed: false, flagged: false, shortfall: 0 });
    expect(reverseTransfer).not.toHaveBeenCalled();
  });

  it('is a no-op when the split feature is off', async () => {
    flag.enabled = false;
    const r = await reverseTransferForReturn({ purchaseRequestId: 11, reverseAmount: 60 });
    expect(r).toEqual({ reversed: false, flagged: false, shortfall: 0 });
    expect(gatewayTransfer.findFirst).not.toHaveBeenCalled();
  });
});
