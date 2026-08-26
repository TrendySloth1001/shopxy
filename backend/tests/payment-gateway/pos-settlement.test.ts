import { describe, it, expect, beforeEach, vi } from 'vitest';

const {
  settlePaidSaleInTx,
  unlockSale,
  saleBusPublish,
  settlePosTransfer,
  getProvider,
  saleFindUnique,
  closeQr,
} = vi.hoisted(() => ({
  settlePaidSaleInTx: vi.fn(),
  unlockSale: vi.fn(),
  saleBusPublish: vi.fn(),
  settlePosTransfer: vi.fn(),
  getProvider: vi.fn(),
  saleFindUnique: vi.fn(),
  closeQr: vi.fn(),
}));

vi.mock('../../src/modules/pos/pos.service.js', () => ({ settlePaidSaleInTx, unlockSale }));
vi.mock('../../src/modules/pos/pos.bus.js', () => ({ saleBus: { publish: saleBusPublish } }));
vi.mock('../../src/modules/payment-gateway/settlement/pos-split.js', () => ({ settlePosTransfer }));
vi.mock('../../src/modules/payment-gateway/providers/registry.js', () => ({ getProvider }));
vi.mock('../../src/infra/db/prisma.js', () => ({ default: { sale: { findUnique: saleFindUnique } } }));

const { settlementFor } = await import(
  '../../src/modules/payment-gateway/settlement/settlement.js'
);
import type { GatewayPaymentRecord } from '../../src/modules/payment-gateway/ports/types.js';

const provider = { name: 'RAZORPAY', createPosQr: vi.fn(), closeQr };

function intent(over: Partial<GatewayPaymentRecord> = {}): GatewayPaymentRecord {
  return {
    id: 1,
    provider: 'RAZORPAY',
    status: 'CAPTURED',
    amount: 100,
    currency: 'INR',
    target: { type: 'POS', id: 55 },
    shopId: 7,
    customerUserId: null,
    providerOrderRef: 'qr_1',
    providerPaymentRef: 'pay_1',
    idempotencyKey: 'pos-qr:55',
    createdAt: new Date(0),
    updatedAt: new Date(0),
    ...over,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  getProvider.mockReturnValue(provider);
});

describe('POS settlement handler', () => {
  const h = settlementFor('POS');

  it('is registered with onPaid', () => {
    expect(typeof h.onPaid).toBe('function');
  });

  it('onPaid settles the locked sale in the tx with the captured payment ref', async () => {
    const tx = { marker: true } as never;
    await h.onPaid(intent(), tx);
    expect(settlePaidSaleInTx).toHaveBeenCalledWith(tx, {
      shopId: 7,
      saleId: 55,
      modeReference: 'pay_1',
    });
  });

  it('onPaid rejects when the intent has no shopId', async () => {
    await expect(h.onPaid(intent({ shopId: null }), {} as never)).rejects.toMatchObject({
      status: 400,
    });
    expect(settlePaidSaleInTx).not.toHaveBeenCalled();
  });

  it('afterCommit routes the Route transfer and broadcasts pos.checkout', async () => {
    saleFindUnique.mockResolvedValue({ invoiceId: 900 });
    await h.afterCommit!(intent());
    expect(settlePosTransfer).toHaveBeenCalledTimes(1);
    expect(saleBusPublish).toHaveBeenCalledWith(7, {
      type: 'pos.checkout',
      saleId: 55,
      invoiceId: 900,
    });
  });

  it('afterCommit does not broadcast when no invoice exists yet', async () => {
    saleFindUnique.mockResolvedValue(null);
    await h.afterCommit!(intent());
    expect(settlePosTransfer).toHaveBeenCalledTimes(1);
    expect(saleBusPublish).not.toHaveBeenCalled();
  });

  it('onAbandon closes the QR and unlocks the cart', async () => {
    await h.onAbandon!(intent());
    expect(closeQr).toHaveBeenCalledWith('qr_1');
    expect(unlockSale).toHaveBeenCalledWith(7, 55);
  });

  it('onAbandon still unlocks the cart when closing the QR fails', async () => {
    closeQr.mockRejectedValue(new Error('already closed'));
    await h.onAbandon!(intent());
    expect(unlockSale).toHaveBeenCalledWith(7, 55);
  });
});
