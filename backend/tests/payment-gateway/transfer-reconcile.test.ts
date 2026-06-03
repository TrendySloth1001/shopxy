/**
 * Unit tests for transfer-level reconciliation (settlement/transfer-reconcile.ts).
 * prisma, the provider registry, and executeHeldTransfers are vi.mock'd.
 *   P1 — null-ref HELD heal re-drives executeHeldTransfers per stale payment.
 *   P2 — overdue holds release (claim-once), EXCEPT children with an open return.
 *   P3/P4 — reconcile each row against the provider (auto-release, re-release,
 *           full/partial reversal sync, mismatch flag).
 *   P7 — promote KYC_GATED rows once their linked account activates.
 *
 * findMany is routed by its `where` clause (not call order) so adding phases
 * doesn't shuffle the mocks.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';

const {
  gatewayTransfer,
  returnRequest,
  gatewayPayment,
  executeHeldTransfers,
  releaseTransfer,
  listTransfers,
  provider,
} = vi.hoisted(() => {
  const gatewayTransfer = {
    findMany: vi.fn(),
    update: vi.fn(),
    updateMany: vi.fn(),
    count: vi.fn(),
  };
  const returnRequest = { findFirst: vi.fn() };
  const gatewayPayment = { findUnique: vi.fn() };
  const executeHeldTransfers = vi.fn();
  const releaseTransfer = vi.fn();
  const listTransfers = vi.fn();
  const provider = {
    name: 'RAZORPAY',
    createTransfers: vi.fn(),
    listTransfers,
    releaseTransfer,
    reverseTransfer: vi.fn(),
  };
  return {
    gatewayTransfer,
    returnRequest,
    gatewayPayment,
    executeHeldTransfers,
    releaseTransfer,
    listTransfers,
    provider,
  };
});

vi.mock('../../src/infra/db/prisma.js', () => ({
  default: { gatewayTransfer, returnRequest, gatewayPayment },
}));
vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: () => provider,
}));
vi.mock('../../src/modules/payment-gateway/settlement/order-split.js', () => ({
  executeHeldTransfers,
}));

import { reconcileStaleTransfers } from '../../src/modules/payment-gateway/settlement/transfer-reconcile.js';

const NOW = new Date('2026-06-01T12:00:00Z');

// Per-phase row fixtures (default empty); set in a test before calling.
let rows: { p1: unknown[]; p2: unknown[]; verify: unknown[]; kyc: unknown[] };

beforeEach(() => {
  vi.clearAllMocks();
  rows = { p1: [], p2: [], verify: [], kyc: [] };
  // Route findMany to the right phase by its where clause.
  gatewayTransfer.findMany.mockImplementation((args: { where: Record<string, unknown> }) => {
    const w = args.where;
    if (w.status === 'KYC_GATED') return Promise.resolve(rows.kyc);
    if (w.status && typeof w.status === 'object') return Promise.resolve(rows.verify); // status.in → P3
    if (w.providerTransferRef === null) return Promise.resolve(rows.p1);
    if (w.holdUntil) return Promise.resolve(rows.p2);
    return Promise.resolve([]);
  });
  returnRequest.findFirst.mockResolvedValue(null);
  gatewayPayment.findUnique.mockResolvedValue({ provider: 'RAZORPAY', providerPaymentRef: 'pay_X' });
  gatewayTransfer.updateMany.mockResolvedValue({ count: 1 });
  gatewayTransfer.count.mockResolvedValue(0);
  listTransfers.mockResolvedValue([]);
});

describe('reconcileStaleTransfers — P1 null-ref HELD heal', () => {
  it('re-drives executeHeldTransfers once per stale payment and aggregates the result', async () => {
    rows.p1 = [{ gatewayPaymentId: 500 }, { gatewayPaymentId: 501 }];
    executeHeldTransfers
      .mockResolvedValueOnce({ created: 1, reconciled: 0, failed: 0 })
      .mockResolvedValueOnce({ created: 0, reconciled: 1, failed: 0 });

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.healPaymentsScanned).toBe(2);
    expect(s.healed).toEqual({ created: 1, reconciled: 1, failed: 0 });
    expect(executeHeldTransfers).toHaveBeenCalledWith(500);
    expect(executeHeldTransfers).toHaveBeenCalledWith(501);
  });

  it('isolates a per-payment heal failure and keeps going', async () => {
    rows.p1 = [{ gatewayPaymentId: 500 }, { gatewayPaymentId: 501 }];
    executeHeldTransfers
      .mockRejectedValueOnce(new Error('rzp 503'))
      .mockResolvedValueOnce({ created: 1, reconciled: 0, failed: 0 });

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.errors).toBe(1);
    expect(s.healed.created).toBe(1);
  });
});

describe('reconcileStaleTransfers — P2 overdue release', () => {
  it('releases an overdue hold with a claim-once guard', async () => {
    rows.p2 = [{ id: 1, gatewayPaymentId: 500, purchaseRequestId: 11, providerTransferRef: 'trf_1' }];

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.released).toBe(1);
    expect(releaseTransfer).toHaveBeenCalledWith('trf_1');
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: expect.any(Date) },
    });
  });

  it('defers a hold whose child has an open return (race guard)', async () => {
    rows.p2 = [
      { id: 1, gatewayPaymentId: 500, purchaseRequestId: 11, providerTransferRef: 'trf_1' },
      { id: 2, gatewayPaymentId: 500, purchaseRequestId: 12, providerTransferRef: 'trf_2' },
    ];
    returnRequest.findFirst.mockImplementation(({ where }: { where: { requestId: number } }) =>
      Promise.resolve(where.requestId === 12 ? { id: 99 } : null),
    );

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.released).toBe(1);
    expect(s.deferredOpenReturn).toBe(1);
    expect(releaseTransfer).toHaveBeenCalledWith('trf_1');
    expect(releaseTransfer).toHaveBeenCalledTimes(1);
  });

  it('skips releasing when the claim is lost to a concurrent path (count 0)', async () => {
    rows.p2 = [{ id: 1, gatewayPaymentId: 500, purchaseRequestId: 11, providerTransferRef: 'trf_1' }];
    gatewayTransfer.updateMany.mockResolvedValue({ count: 0 });

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.released).toBe(0);
    expect(releaseTransfer).not.toHaveBeenCalled();
  });

  it('rolls the claim back to HELD when the provider release fails', async () => {
    rows.p2 = [{ id: 1, gatewayPaymentId: 500, purchaseRequestId: 11, providerTransferRef: 'trf_1' }];
    releaseTransfer.mockRejectedValueOnce(new Error('rzp 503'));

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.errors).toBe(1);
    expect(s.released).toBe(0);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: 'RELEASED' },
      data: { status: 'HELD', releasedAt: null },
    });
  });

  it('surfaces a dead-letter signal when transfers are stuck FAILED', async () => {
    gatewayTransfer.count.mockResolvedValue(3);
    const s = await reconcileStaleTransfers({ now: NOW });
    expect(s.failedTransfers).toBe(3);
  });

  it('is a clean no-op when there is nothing to do', async () => {
    const s = await reconcileStaleTransfers({ now: NOW });
    expect(s).toMatchObject({ released: 0, healPaymentsScanned: 0, verified: 0, kycRetried: 0, errors: 0 });
    expect(releaseTransfer).not.toHaveBeenCalled();
  });
});

describe('reconcileStaleTransfers — P3/P4 verify against provider', () => {
  const verifyRow = (over: Record<string, unknown> = {}) => ({
    id: 1,
    gatewayPaymentId: 500,
    providerTransferRef: 'trf_1',
    status: 'HELD',
    amount: 60,
    reversedAmount: 0,
    ...over,
  });
  const provTransfer = (over: Record<string, unknown> = {}) => ({
    transferRef: 'trf_1',
    destinationAccount: 'acc_OK',
    amountMinor: 6000,
    onHold: true,
    status: 'created',
    amountReversedMinor: 0,
    notes: {},
    ...over,
  });

  it('catches up a HELD row that Razorpay already auto-released', async () => {
    rows.verify = [verifyRow({ status: 'HELD' })];
    listTransfers.mockResolvedValue([provTransfer({ onHold: false, status: 'processed' })]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.autoReleased).toBe(1);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: expect.any(Date) },
    });
  });

  it('re-drives release when DB says RELEASED but provider still on_hold (crash gap)', async () => {
    rows.verify = [verifyRow({ status: 'RELEASED' })];
    listTransfers.mockResolvedValue([provTransfer({ onHold: true })]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.reReleased).toBe(1);
    expect(releaseTransfer).toHaveBeenCalledWith('trf_1');
  });

  it('syncs a fully-reversed transfer to REVERSED (claim-once)', async () => {
    rows.verify = [verifyRow({ status: 'HELD', amount: 60 })];
    listTransfers.mockResolvedValue([
      provTransfer({ status: 'reversed', amountReversedMinor: 6000, onHold: false }),
    ]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.reversalSynced).toBe(1);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 1, status: { not: 'REVERSED' } },
        data: expect.objectContaining({ status: 'REVERSED' }),
      }),
    );
  });

  it('moves a partially-reversed HELD row to PARTIALLY_REVERSED (keeps it out of auto-release)', async () => {
    rows.verify = [verifyRow({ status: 'HELD', amount: 60, reversedAmount: 0 })];
    // ₹20 of ₹60 reversed, still on hold.
    listTransfers.mockResolvedValue([provTransfer({ amountReversedMinor: 2000, onHold: true })]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.reversalSynced).toBe(1);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 1, status: { in: ['HELD', 'PARTIALLY_REVERSED'] } },
        data: expect.objectContaining({ status: 'PARTIALLY_REVERSED' }),
      }),
    );
  });

  it('FLAGS (does not shrink) when the provider reversed LESS than our DB', async () => {
    rows.verify = [verifyRow({ status: 'PARTIALLY_REVERSED', amount: 60, reversedAmount: 30 })];
    // provider says only ₹10 reversed, DB recorded ₹30 — discrepancy.
    listTransfers.mockResolvedValue([provTransfer({ amountReversedMinor: 1000 })]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.reversalMismatchFlagged).toBe(1);
    expect(s.reversalSynced).toBe(0);
  });

  it('FLAGS an over-reversal (provider reversed MORE than the amount) but still marks REVERSED', async () => {
    rows.verify = [verifyRow({ status: 'HELD', amount: 60 })];
    listTransfers.mockResolvedValue([
      provTransfer({ status: 'reversed', amountReversedMinor: 7000, onHold: false }),
    ]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.reversalMismatchFlagged).toBe(1);
    expect(s.reversalSynced).toBe(1);
  });

  it('leaves a still-held transfer untouched', async () => {
    rows.verify = [verifyRow({ status: 'HELD' })];
    listTransfers.mockResolvedValue([provTransfer({ onHold: true })]);

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.verified).toBe(1);
    expect(s.autoReleased).toBe(0);
    expect(s.reReleased).toBe(0);
    expect(releaseTransfer).not.toHaveBeenCalled();
  });
});

describe('reconcileStaleTransfers — P7 KYC retry', () => {
  it('promotes a KYC_GATED row to HELD once its account activates and drives the transfer', async () => {
    rows.kyc = [
      {
        id: 7,
        gatewayPaymentId: 500,
        purchaseRequest: {
          shop: { linkedAccount: { id: 9, providerAccountId: 'acc_NOW', payoutsEnabled: true } },
        },
      },
    ];
    executeHeldTransfers.mockResolvedValue({ created: 1, reconciled: 0, failed: 0 });

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.kycRetried).toBe(1);
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { id: 7, status: 'KYC_GATED' },
      data: { status: 'HELD', linkedAccountId: 9, providerAccountId: 'acc_NOW', failureReason: null },
    });
    expect(executeHeldTransfers).toHaveBeenCalledWith(500);
  });

  it('leaves a KYC_GATED row gated while its account is still not payouts-enabled', async () => {
    rows.kyc = [
      {
        id: 7,
        gatewayPaymentId: 500,
        purchaseRequest: {
          shop: { linkedAccount: { id: 9, providerAccountId: null, payoutsEnabled: false } },
        },
      },
    ];

    const s = await reconcileStaleTransfers({ now: NOW });

    expect(s.kycRetried).toBe(0);
    expect(gatewayTransfer.updateMany).not.toHaveBeenCalled();
    expect(executeHeldTransfers).not.toHaveBeenCalled();
  });
});
