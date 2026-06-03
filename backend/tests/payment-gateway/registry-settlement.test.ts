import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

/// Pure unit tests — NO database, NO network.
///
/// The wallet.service module imports Prisma at module load, so we mock the
/// WHOLE module before importing settlement.ts (which imports walletService
/// at its top). This keeps the suite DB-free while letting us assert the
/// exact args the WALLET settlement handler hands to walletService.credit.
/// vi.mock is hoisted above imports, so the spy must be hoisted too — hence
/// vi.hoisted rather than a plain top-level const.
const { creditSpy } = vi.hoisted(() => ({ creditSpy: vi.fn() }));
vi.mock('../../src/modules/wallet/wallet.service.js', () => ({
  walletService: { credit: creditSpy },
}));

import {
  getProvider,
  listEnabledProviders,
  resetProviderRegistry,
} from '../../src/modules/payment-gateway/providers/registry.js';
import { isSplitCapable } from '../../src/modules/payment-gateway/ports/payment-provider.port.js';
import { settlementFor } from '../../src/modules/payment-gateway/settlement/settlement.js';
import type {
  GatewayPaymentRecord,
  SettlementTargetType,
} from '../../src/modules/payment-gateway/ports/types.js';

/// Build a minimal CAPTURED intent for the WALLET handler. Only the fields the
/// handler reads matter; the rest satisfy the type.
function makeIntent(
  over: Partial<GatewayPaymentRecord> = {},
): GatewayPaymentRecord {
  const now = new Date();
  return {
    id: 42,
    provider: 'RAZORPAY',
    status: 'CAPTURED',
    amount: 500,
    currency: 'INR',
    target: { type: 'WALLET', id: 7 },
    shopId: null,
    customerUserId: 7,
    providerOrderRef: 'order_x',
    providerPaymentRef: 'pay_x',
    idempotencyKey: null,
    createdAt: now,
    updatedAt: now,
    ...over,
  };
}

describe('provider registry', () => {
  const prevId = process.env.RAZORPAY_KEY_ID;
  const prevSecret = process.env.RAZORPAY_KEY_SECRET;

  beforeEach(() => {
    process.env.RAZORPAY_KEY_ID = 'rzp_test_key';
    process.env.RAZORPAY_KEY_SECRET = 'rzp_test_secret';
    // Forget the lazily-built map so it re-reads the env we just set.
    resetProviderRegistry();
  });

  afterEach(() => {
    if (prevId === undefined) delete process.env.RAZORPAY_KEY_ID;
    else process.env.RAZORPAY_KEY_ID = prevId;
    if (prevSecret === undefined) delete process.env.RAZORPAY_KEY_SECRET;
    else process.env.RAZORPAY_KEY_SECRET = prevSecret;
    resetProviderRegistry();
  });

  it('lists RAZORPAY when its credentials are present', () => {
    expect(listEnabledProviders()).toContain('RAZORPAY');
  });

  it('resolves RAZORPAY case-insensitively', () => {
    expect(getProvider('razorpay').name).toBe('RAZORPAY');
    expect(getProvider('RAZORPAY').name).toBe('RAZORPAY');
  });

  it('reports the Razorpay provider as split-capable', () => {
    expect(isSplitCapable(getProvider('RAZORPAY'))).toBe(true);
  });

  it('throws a 400 for an unknown provider name', () => {
    let caught: unknown;
    try {
      getProvider('NOPE');
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(Error);
    expect((caught as { status?: number }).status).toBe(400);
    expect((caught as Error).message).toContain('NOPE');
  });

  it('drops RAZORPAY when credentials are absent (after reset)', () => {
    delete process.env.RAZORPAY_KEY_ID;
    delete process.env.RAZORPAY_KEY_SECRET;
    resetProviderRegistry();
    expect(listEnabledProviders()).not.toContain('RAZORPAY');
    expect(() => getProvider('RAZORPAY')).toThrow();
  });
});

describe('settlement — WALLET handler', () => {
  beforeEach(() => {
    creditSpy.mockReset();
    creditSpy.mockResolvedValue({
      id: 1,
      amount: 500,
      balanceAfter: 500,
      source: 'TOPUP',
      description: '',
      createdAt: new Date(),
    });
  });

  it('credits the wallet with source TOPUP and key gw:<id>', async () => {
    const intent = makeIntent({ id: 99, amount: 750, customerUserId: 7 });
    await settlementFor('WALLET').onPaid(intent);

    expect(creditSpy).toHaveBeenCalledTimes(1);
    const arg = creditSpy.mock.calls[0][0];
    expect(arg.source).toBe('TOPUP');
    expect(arg.idempotencyKey).toBe('gw:99');
    expect(arg.amount).toBe(750);
    expect(arg.userId).toBe(7);
    expect(arg.sourceId).toBe(99);
  });

  it('threads the outer transaction client through to credit', async () => {
    const tx = { marker: true } as never;
    await settlementFor('WALLET').onPaid(makeIntent(), tx);
    expect(creditSpy.mock.calls[0][0].tx).toBe(tx);
  });

  it('throws a 400 when customerUserId is null and never credits', async () => {
    const intent = makeIntent({ customerUserId: null });
    let caught: unknown;
    try {
      await settlementFor('WALLET').onPaid(intent);
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(Error);
    expect((caught as { status?: number }).status).toBe(400);
    expect(creditSpy).not.toHaveBeenCalled();
  });
});

describe('settlement — unwired targets', () => {
  // ORDER is now wired (checkout online payment → CustomerOrder.paymentStatus);
  // it is covered by order-settlement.test.ts. INVOICE/CAUTION remain stubs.
  it.each<SettlementTargetType>(['INVOICE', 'CAUTION'])(
    'throws 501 for %s (not wired yet)',
    async (type) => {
      let caught: unknown;
      try {
        await settlementFor(type).onPaid(makeIntent({ target: { type, id: 1 } }));
      } catch (err) {
        caught = err;
      }
      expect((caught as { status?: number }).status).toBe(501);
    },
  );
});
