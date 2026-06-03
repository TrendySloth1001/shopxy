/**
 * Unit tests for the settlement webhook handlers (settlement/webhook-handlers.ts).
 * prisma and reverseTransferForReturn are vi.mock'd.
 */
import { describe, it, expect, beforeEach, vi } from 'vitest';

const { gatewayTransfer, linkedAccount, gatewayPayment, reverseTransferForReturn } = vi.hoisted(
  () => {
    const gatewayTransfer = {
      count: vi.fn(),
      updateMany: vi.fn(),
      findFirst: vi.fn(),
      findMany: vi.fn(),
    };
    const linkedAccount = { count: vi.fn(), updateMany: vi.fn() };
    const gatewayPayment = { count: vi.fn(), findFirst: vi.fn() };
    const reverseTransferForReturn = vi.fn();
    return { gatewayTransfer, linkedAccount, gatewayPayment, reverseTransferForReturn };
  },
);

vi.mock('../../src/infra/db/prisma.js', () => ({
  default: { gatewayTransfer, linkedAccount, gatewayPayment },
}));
vi.mock('../../src/modules/payment-gateway/settlement/transfer-actions.js', () => ({
  reverseTransferForReturn,
}));

import {
  isSettlementEvent,
  ownsSettlementEvent,
  handleSettlementEvent,
} from '../../src/modules/payment-gateway/settlement/webhook-handlers.js';
import type { NormalizedEvent } from '../../src/modules/payment-gateway/ports/types.js';

function evt(over: Partial<NormalizedEvent>): NormalizedEvent {
  return {
    type: 'TRANSFER_PROCESSED',
    eventId: 'e1',
    providerOrderRef: null,
    providerPaymentRef: null,
    amountMinor: null,
    currency: null,
    raw: {},
    ...over,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  gatewayTransfer.count.mockResolvedValue(0);
  linkedAccount.count.mockResolvedValue(0);
  gatewayPayment.count.mockResolvedValue(0);
  reverseTransferForReturn.mockResolvedValue({ reversed: true, flagged: false });
});

describe('isSettlementEvent', () => {
  it('classifies the settlement event types and excludes payment ones', () => {
    expect(isSettlementEvent('TRANSFER_PROCESSED')).toBe(true);
    expect(isSettlementEvent('ACCOUNT_UPDATED')).toBe(true);
    expect(isSettlementEvent('DISPUTE_LOST')).toBe(true);
    expect(isSettlementEvent('PAID')).toBe(false);
    expect(isSettlementEvent('FAILED')).toBe(false);
  });
});

describe('ownsSettlementEvent — ack-and-ignore foreign events', () => {
  it('owns a transfer event when the transfer ref exists', async () => {
    gatewayTransfer.count.mockResolvedValue(1);
    expect(
      await ownsSettlementEvent(
        evt({ type: 'TRANSFER_PROCESSED', transfer: { ref: 'trf_1', status: 'processed', amountReversedMinor: 0, onHold: false } }),
      ),
    ).toBe(true);
  });

  it('disowns a transfer event for an unknown ref (foreign account)', async () => {
    gatewayTransfer.count.mockResolvedValue(0);
    expect(
      await ownsSettlementEvent(
        evt({ type: 'TRANSFER_PROCESSED', transfer: { ref: 'trf_other', status: 'processed', amountReversedMinor: 0, onHold: false } }),
      ),
    ).toBe(false);
  });

  it('owns an account event when the linked account exists', async () => {
    linkedAccount.count.mockResolvedValue(1);
    expect(
      await ownsSettlementEvent(evt({ type: 'ACCOUNT_UPDATED', account: { ref: 'acc_1', status: 'activated' } })),
    ).toBe(true);
  });

  it('owns a dispute event when the disputed payment exists', async () => {
    gatewayPayment.count.mockResolvedValue(1);
    expect(
      await ownsSettlementEvent(evt({ type: 'DISPUTE_LOST', dispute: { ref: 'd1', providerPaymentRef: 'pay_9' } })),
    ).toBe(true);
  });
});

describe('handleSettlementEvent', () => {
  it('TRANSFER_PROCESSED marks HELD/RELEASED → RELEASED', async () => {
    await handleSettlementEvent(
      evt({ type: 'TRANSFER_PROCESSED', transfer: { ref: 'trf_1', status: 'processed', amountReversedMinor: 0, onHold: false } }),
    );
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { providerTransferRef: 'trf_1', status: { in: ['HELD', 'RELEASED'] } },
      data: { status: 'RELEASED', releasedAt: expect.any(Date) },
    });
  });

  it('TRANSFER_FAILED marks the transfer FAILED', async () => {
    await handleSettlementEvent(
      evt({ type: 'TRANSFER_FAILED', transfer: { ref: 'trf_1', status: 'failed', amountReversedMinor: 0, onHold: false } }),
    );
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith({
      where: { providerTransferRef: 'trf_1', status: { in: ['HELD', 'RELEASED'] } },
      data: { status: 'FAILED', failureReason: 'TRANSFER_FAILED_WEBHOOK' },
    });
  });

  it('TRANSFER_REVERSED syncs reversedAmount and flips to REVERSED when full', async () => {
    gatewayTransfer.findFirst.mockResolvedValue({ id: 1, amount: 60, reversedAmount: 0 });
    await handleSettlementEvent(
      evt({ type: 'TRANSFER_REVERSED', transfer: { ref: 'trf_1', status: 'reversed', amountReversedMinor: 6000, onHold: false } }),
    );
    expect(gatewayTransfer.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'REVERSED' }) }),
    );
  });

  it('TRANSFER_REVERSED is a no-op when the event reports nothing new (replay)', async () => {
    gatewayTransfer.findFirst.mockResolvedValue({ id: 1, amount: 60, reversedAmount: 20 });
    await handleSettlementEvent(
      evt({ type: 'TRANSFER_REVERSED', transfer: { ref: 'trf_1', status: 'reversed', amountReversedMinor: 2000, onHold: false } }),
    );
    expect(gatewayTransfer.updateMany).not.toHaveBeenCalled();
  });

  it('ACCOUNT_UPDATED activation enables payouts', async () => {
    await handleSettlementEvent(evt({ type: 'ACCOUNT_UPDATED', account: { ref: 'acc_1', status: 'activated' } }));
    expect(linkedAccount.updateMany).toHaveBeenCalledWith({
      where: { providerAccountId: 'acc_1' },
      data: { kycStatus: 'ACTIVATED', payoutsEnabled: true },
    });
  });

  it('ACCOUNT_UPDATED suspension disables payouts', async () => {
    await handleSettlementEvent(evt({ type: 'ACCOUNT_UPDATED', account: { ref: 'acc_1', status: 'suspended' } }));
    expect(linkedAccount.updateMany).toHaveBeenCalledWith({
      where: { providerAccountId: 'acc_1' },
      data: { kycStatus: 'SUSPENDED', payoutsEnabled: false },
    });
  });

  it('DISPUTE_LOST reverses the held transfers for the disputed payment', async () => {
    gatewayPayment.findFirst.mockResolvedValue({ id: 500 });
    gatewayTransfer.findMany.mockResolvedValue([
      { purchaseRequestId: 11, amount: 60, reversedAmount: 0 },
      { purchaseRequestId: 12, amount: 40, reversedAmount: 0 },
    ]);

    await handleSettlementEvent(evt({ type: 'DISPUTE_LOST', dispute: { ref: 'd1', providerPaymentRef: 'pay_9' } }));

    expect(reverseTransferForReturn).toHaveBeenCalledWith({ purchaseRequestId: 11, reverseAmount: 60 });
    expect(reverseTransferForReturn).toHaveBeenCalledWith({ purchaseRequestId: 12, reverseAmount: 40 });
  });

  it('DISPUTE_LOST is a no-op when the disputed payment is not ours', async () => {
    gatewayPayment.findFirst.mockResolvedValue(null);
    await handleSettlementEvent(evt({ type: 'DISPUTE_LOST', dispute: { ref: 'd1', providerPaymentRef: 'pay_x' } }));
    expect(reverseTransferForReturn).not.toHaveBeenCalled();
  });
});
