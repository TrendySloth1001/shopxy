/**
 * Unit tests for the Route on-hold split (settlement/order-split.ts).
 *
 * No DB, no network. prisma and the provider registry are vi.mock'd. Focus:
 *  - writeHeldTransferRows: per-child HELD vs KYC_GATED rows + allocation.
 *  - executeHeldTransfers: the #8 idempotency guard — fetch-before-create
 *    reconciles an already-created transfer instead of double-paying, and a
 *    fresh run creates on-hold with the deterministic notes key.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';

// Hoisted so the (hoisted) vi.mock factories below can reference these without
// the "cannot access before initialization" trap.
const { gatewayPayment, gatewayTransfer, createTransfers, listTransfers, provider } = vi.hoisted(
  () => {
    const gatewayPayment = { findUnique: vi.fn() };
    const gatewayTransfer = { findMany: vi.fn(), update: vi.fn() };
    const createTransfers = vi.fn();
    const listTransfers = vi.fn();
    const provider = {
      name: 'RAZORPAY',
      createTransfers,
      listTransfers,
      releaseTransfer: vi.fn(),
      reverseTransfer: vi.fn(),
    };
    return { gatewayPayment, gatewayTransfer, createTransfers, listTransfers, provider };
  },
);

vi.mock('../../src/infra/db/prisma.js', () => ({
  default: { gatewayPayment, gatewayTransfer },
}));
vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({
  getProvider: () => provider,
}));

import {
  writeHeldTransferRows,
  executeHeldTransfers,
} from '../../src/modules/payment-gateway/settlement/order-split.js';
import type { GatewayPaymentRecord } from '../../src/modules/payment-gateway/ports/types.js';

function intent(over: Partial<GatewayPaymentRecord> = {}): GatewayPaymentRecord {
  return {
    id: 500,
    provider: 'RAZORPAY',
    status: 'CAPTURED',
    amount: 100,
    currency: 'INR',
    target: { type: 'ORDER', id: 42 },
    shopId: null,
    customerUserId: 7,
    providerOrderRef: 'order_X',
    providerPaymentRef: 'pay_X',
    idempotencyKey: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
    ...over,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe('writeHeldTransferRows (in-tx, phase 1)', () => {
  it('writes a HELD row for a KYC-activated shop and a KYC_GATED row for one without', async () => {
    const upsert = vi.fn();
    const tx = {
      purchaseRequest: {
        findMany: vi.fn().mockResolvedValue([
          {
            id: 11,
            estimatedTotal: 60,
            shop: {
              returnWindowDays: 7,
              linkedAccount: { id: 9, providerAccountId: 'acc_OK', payoutsEnabled: true },
            },
          },
          {
            id: 12,
            estimatedTotal: 40,
            shop: { returnWindowDays: 7, linkedAccount: null }, // not onboarded
          },
        ]),
      },
      gatewayTransfer: { upsert },
    };

    await writeHeldTransferRows(intent({ amount: 100 }), tx as never);

    expect(upsert).toHaveBeenCalledTimes(2);
    const first = upsert.mock.calls[0][0];
    const second = upsert.mock.calls[1][0];

    // KYC'd child → HELD, has the destination account + deterministic key.
    expect(first.create).toMatchObject({
      gatewayPaymentId: 500,
      purchaseRequestId: 11,
      providerAccountId: 'acc_OK',
      status: 'HELD',
      idempotencyKey: 'gw:500:pr:11',
    });
    expect(Number(first.create.amount)).toBeCloseTo(60); // 60% of ₹100

    // Non-KYC'd child → KYC_GATED, no destination account, reason recorded.
    expect(second.create).toMatchObject({
      purchaseRequestId: 12,
      providerAccountId: null,
      status: 'KYC_GATED',
      failureReason: 'KYC_NOT_ACTIVATED',
    });

    // Idempotent: the upsert is keyed on (paymentId, requestId), update is a no-op.
    expect(first.where).toEqual({
      gateway_transfers_payment_request: { gatewayPaymentId: 500, purchaseRequestId: 11 },
    });
    expect(first.update).toEqual({});
  });

  it('is a no-op when the order has no children', async () => {
    const upsert = vi.fn();
    const tx = {
      purchaseRequest: { findMany: vi.fn().mockResolvedValue([]) },
      gatewayTransfer: { upsert },
    };
    await writeHeldTransferRows(intent(), tx as never);
    expect(upsert).not.toHaveBeenCalled();
  });
});

describe('executeHeldTransfers (post-commit, phase 2) — idempotency', () => {
  beforeEach(() => {
    gatewayPayment.findUnique.mockResolvedValue({
      provider: 'RAZORPAY',
      providerPaymentRef: 'pay_X',
    });
  });

  it('creates an on-hold transfer for a fresh HELD row, stamping the deterministic notes key', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      {
        id: 1,
        purchaseRequestId: 11,
        providerAccountId: 'acc_OK',
        amount: 60,
        idempotencyKey: 'gw:500:pr:11',
        holdUntil: new Date('2026-06-08T00:00:00Z'),
      },
    ]);
    listTransfers.mockResolvedValue([]); // nothing exists yet
    createTransfers.mockResolvedValue([{ transferRef: 'trf_NEW', destinationAccount: 'acc_OK', amountMinor: 6000, onHold: true }]);

    await executeHeldTransfers(500);

    // Created exactly once, on-hold, with on_hold_until + our deterministic key.
    expect(createTransfers).toHaveBeenCalledTimes(1);
    const [payRef, [req]] = createTransfers.mock.calls[0];
    expect(payRef).toBe('pay_X');
    expect(req).toMatchObject({ destinationAccount: 'acc_OK', amountMinor: 6000, onHold: true });
    expect(req.notes.shopxy_transfer_key).toBe('gw:500:pr:11');
    expect(typeof req.onHoldUntil).toBe('number');

    // Ref patched back onto the row.
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { providerTransferRef: 'trf_NEW' },
    });
  });

  it('DOES NOT double-pay: a transfer already at the provider (matched by key) is reconciled, not re-created', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      {
        id: 1,
        purchaseRequestId: 11,
        providerAccountId: 'acc_OK',
        amount: 60,
        idempotencyKey: 'gw:500:pr:11',
        holdUntil: null,
      },
    ]);
    // We created it before but crashed before patching the ref. It comes back
    // from listTransfers tagged with our key.
    listTransfers.mockResolvedValue([
      { transferRef: 'trf_EXISTING', destinationAccount: 'acc_OK', amountMinor: 6000, onHold: true, notes: { shopxy_transfer_key: 'gw:500:pr:11' } },
    ]);

    await executeHeldTransfers(500);

    // The double-pay guard: no new transfer created; the existing one adopted.
    expect(createTransfers).not.toHaveBeenCalled();
    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { providerTransferRef: 'trf_EXISTING' },
    });
  });

  it('marks a row FAILED (does not throw) when the provider rejects the transfer', async () => {
    gatewayTransfer.findMany.mockResolvedValue([
      { id: 1, purchaseRequestId: 11, providerAccountId: 'acc_OK', amount: 60, idempotencyKey: 'gw:500:pr:11', holdUntil: null },
    ]);
    listTransfers.mockResolvedValue([]);
    createTransfers.mockRejectedValue(Object.assign(new Error('insufficient balance'), { status: 402 }));

    // Returns a summary (does not throw) and records the failure on the row.
    await expect(executeHeldTransfers(500)).resolves.toMatchObject({ failed: 1 });

    expect(gatewayTransfer.update).toHaveBeenCalledWith({
      where: { id: 1 },
      data: { status: 'FAILED', failureReason: 'insufficient balance' },
    });
  });

  it('is a no-op when there are no null-ref HELD rows left', async () => {
    gatewayTransfer.findMany.mockResolvedValue([]);
    await executeHeldTransfers(500);
    expect(listTransfers).not.toHaveBeenCalled();
    expect(createTransfers).not.toHaveBeenCalled();
  });

  it('does nothing when the intent has no captured payment ref', async () => {
    gatewayPayment.findUnique.mockResolvedValue({ provider: 'RAZORPAY', providerPaymentRef: null });
    await executeHeldTransfers(500);
    expect(gatewayTransfer.findMany).not.toHaveBeenCalled();
  });
});
