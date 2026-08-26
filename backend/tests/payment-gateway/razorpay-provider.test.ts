import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import crypto from 'crypto';

const KEY_ID = 'rzp_test_key';
const KEY_SECRET = 'rzp_test_secret';
const WEBHOOK_SECRET = 'whsec_test';
process.env.RAZORPAY_KEY_ID = KEY_ID;
process.env.RAZORPAY_KEY_SECRET = KEY_SECRET;
process.env.RAZORPAY_WEBHOOK_SECRET = WEBHOOK_SECRET;

const { RazorpayProvider } = await import(
  '../../src/modules/payment-gateway/providers/razorpay.provider.js'
);

function hmacHex(secret: string, body: string | Buffer): string {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('RazorpayProvider — constructor', () => {
  it('exposes the registry name', () => {
    expect(new RazorpayProvider().name).toBe('RAZORPAY');
  });
});

describe('RazorpayProvider — verifyWebhookSignature', () => {
  const provider = new RazorpayProvider();
  const rawBody = Buffer.from(JSON.stringify({ event: 'payment.captured' }));

  it('returns true for a valid signature over the raw bytes', () => {
    const sig = hmacHex(WEBHOOK_SECRET, rawBody);
    expect(
      provider.verifyWebhookSignature(rawBody, { 'x-razorpay-signature': sig }),
    ).toBe(true);
  });

  it('returns false for a tampered signature', () => {
    const sig = hmacHex(WEBHOOK_SECRET, rawBody);
    const tampered = sig.slice(0, -1) + (sig.endsWith('a') ? 'b' : 'a');
    expect(
      provider.verifyWebhookSignature(rawBody, { 'x-razorpay-signature': tampered }),
    ).toBe(false);
  });

  it('returns false when a valid signature is checked against a different body', () => {
    const sig = hmacHex(WEBHOOK_SECRET, rawBody);
    const otherBody = Buffer.from(JSON.stringify({ event: 'payment.failed' }));
    expect(
      provider.verifyWebhookSignature(otherBody, { 'x-razorpay-signature': sig }),
    ).toBe(false);
  });

  it('returns false when the signature header is missing', () => {
    expect(provider.verifyWebhookSignature(rawBody, {})).toBe(false);
  });

  it('fails closed (false) when the webhook secret is unconfigured', () => {
    const prev = process.env.RAZORPAY_WEBHOOK_SECRET;
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    try {
      const noSecret = new RazorpayProvider();
      const sig = hmacHex('', rawBody);
      expect(
        noSecret.verifyWebhookSignature(rawBody, { 'x-razorpay-signature': sig }),
      ).toBe(false);
    } finally {
      process.env.RAZORPAY_WEBHOOK_SECRET = prev;
    }
  });
});

describe('RazorpayProvider — verifyHandshake', () => {
  const provider = new RazorpayProvider();
  const providerOrderRef = 'order_ABC';
  const providerPaymentRef = 'pay_XYZ';

  it('returns true for the correct HMAC(order|payment, keySecret)', () => {
    const signature = hmacHex(KEY_SECRET, `${providerOrderRef}|${providerPaymentRef}`);
    expect(
      provider.verifyHandshake({ providerOrderRef, providerPaymentRef, signature }),
    ).toBe(true);
  });

  it('returns false for a wrong signature', () => {
    expect(
      provider.verifyHandshake({
        providerOrderRef,
        providerPaymentRef,
        signature: 'deadbeef',
      }),
    ).toBe(false);
  });

  it('returns false when order/payment refs are swapped (order matters)', () => {
    const signature = hmacHex(KEY_SECRET, `${providerPaymentRef}|${providerOrderRef}`);
    expect(
      provider.verifyHandshake({ providerOrderRef, providerPaymentRef, signature }),
    ).toBe(false);
  });
});

describe('RazorpayProvider — parseWebhookEvent', () => {
  const provider = new RazorpayProvider();

  function captured(extra: Record<string, unknown> = {}) {
    return {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_1',
            order_id: 'order_1',
            amount: 5000,
            currency: 'INR',
            ...extra,
          },
        },
      },
    };
  }

  it('maps payment.captured → PAID and pulls payment fields', () => {
    const body = Buffer.from(JSON.stringify(captured()));
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_1' });
    expect(ev.type).toBe('PAID');
    expect(ev.eventId).toBe('evt_1');
    expect(ev.providerOrderRef).toBe('order_1');
    expect(ev.providerPaymentRef).toBe('pay_1');
    expect(ev.amountMinor).toBe(5000);
    expect(ev.currency).toBe('INR');
  });

  it('maps payment.failed → FAILED', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'payment.failed',
        payload: { payment: { entity: { id: 'pay_2', order_id: 'order_2', amount: 100, currency: 'INR' } } },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_2' });
    expect(ev.type).toBe('FAILED');
    expect(ev.providerPaymentRef).toBe('pay_2');
  });

  it('maps refund.processed → REFUNDED and reads refund entity', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'refund.processed',
        payload: {
          refund: { entity: { id: 'rfnd_1', payment_id: 'pay_3', amount: 250, currency: 'INR' } },
        },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_3' });
    expect(ev.type).toBe('REFUNDED');
    expect(ev.providerOrderRef).toBeNull();
    expect(ev.providerPaymentRef).toBe('pay_3');
    expect(ev.amountMinor).toBe(250);
    expect(ev.currency).toBe('INR');
  });

  it('maps an unknown event → UNKNOWN', () => {
    const body = Buffer.from(JSON.stringify({ event: 'subscription.charged', payload: {} }));
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_4' });
    expect(ev.type).toBe('UNKNOWN');
  });

  it('uses the x-razorpay-event-id header as the dedupe eventId', () => {
    const body = Buffer.from(JSON.stringify(captured()));
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'hdr_evt' });
    expect(ev.eventId).toBe('hdr_evt');
  });

  it('falls back to "<entityId>:<event>" when the event-id header is absent', () => {
    const body = Buffer.from(JSON.stringify(captured()));
    const ev = provider.parseWebhookEvent(body, {});
    expect(ev.eventId).toBe('pay_1:payment.captured');
  });

  it('falls back to "unknown:<event>" when no entity id is present either', () => {
    const body = Buffer.from(JSON.stringify({ event: 'payment.captured', payload: {} }));
    const ev = provider.parseWebhookEvent(body, {});
    expect(ev.eventId).toBe('unknown:payment.captured');
  });

  it('is null-safe when payload entities are missing entirely', () => {
    const body = Buffer.from(JSON.stringify({}));
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_empty' });
    expect(ev.type).toBe('UNKNOWN');
    expect(ev.providerOrderRef).toBeNull();
    expect(ev.providerPaymentRef).toBeNull();
    expect(ev.amountMinor).toBeNull();
    expect(ev.currency).toBeNull();
    expect(ev.eventId).toBe('evt_empty');
  });

  it('maps transfer.processed → TRANSFER_PROCESSED with the transfer entity', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'transfer.processed',
        payload: {
          transfer: { entity: { id: 'trf_1', status: 'processed', amount_reversed: 0, on_hold: false } },
        },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_t1' });
    expect(ev.type).toBe('TRANSFER_PROCESSED');
    expect(ev.transfer).toEqual({
      ref: 'trf_1',
      status: 'processed',
      amountReversedMinor: 0,
      onHold: false,
    });
  });

  it('maps transfer.reversed → TRANSFER_REVERSED carrying amount_reversed', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'transfer.reversed',
        payload: { transfer: { entity: { id: 'trf_2', status: 'reversed', amount_reversed: 2000, on_hold: false } } },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_t2' });
    expect(ev.type).toBe('TRANSFER_REVERSED');
    expect(ev.transfer?.amountReversedMinor).toBe(2000);
  });

  it('maps account.activated → ACCOUNT_UPDATED with the account entity', () => {
    const body = Buffer.from(
      JSON.stringify({ event: 'account.activated', payload: { account: { entity: { id: 'acc_1', status: 'activated' } } } }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_a1' });
    expect(ev.type).toBe('ACCOUNT_UPDATED');
    expect(ev.account).toEqual({ ref: 'acc_1', status: 'activated' });
  });

  it('maps payment.dispute.lost → DISPUTE_LOST with the disputed payment id', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'payment.dispute.lost',
        payload: { dispute: { entity: { id: 'disp_1', payment_id: 'pay_9' } } },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_d1' });
    expect(ev.type).toBe('DISPUTE_LOST');
    expect(ev.dispute).toEqual({ ref: 'disp_1', providerPaymentRef: 'pay_9' });
    expect(ev.providerPaymentRef).toBe('pay_9');
  });

  it('treats payment.dispute.closed with entity status "lost" as DISPUTE_LOST (clawback)', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'payment.dispute.closed',
        payload: { dispute: { entity: { id: 'disp_2', payment_id: 'pay_7', status: 'lost' } } },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_d2' });
    expect(ev.type).toBe('DISPUTE_LOST');
    expect(ev.dispute?.providerPaymentRef).toBe('pay_7');
  });

  it('treats payment.dispute.closed that was WON as DISPUTE_OTHER (no clawback)', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'payment.dispute.closed',
        payload: { dispute: { entity: { id: 'disp_3', payment_id: 'pay_8', status: 'won' } } },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_d3' });
    expect(ev.type).toBe('DISPUTE_OTHER');
  });

  it('throws a 400-tagged error on malformed JSON', () => {
    const body = Buffer.from('not json {');
    try {
      provider.parseWebhookEvent(body, {});
      throw new Error('expected parseWebhookEvent to throw');
    } catch (err) {
      const e = err as { status?: number; message?: string };
      expect(e.status).toBe(400);
      expect(e.message).toContain('Invalid webhook JSON');
    }
  });
});

describe('RazorpayProvider — buildClientParams', () => {
  it('returns the Razorpay Checkout shape (key/order_id/amount/currency)', () => {
    const provider = new RazorpayProvider();
    expect(
      provider.buildClientParams({
        providerOrderRef: 'order_99',
        amountMinor: 12345,
        currency: 'INR',
      }),
    ).toEqual({
      key: KEY_ID,
      order_id: 'order_99',
      amount: 12345,
      currency: 'INR',
    });
  });
});

describe('RazorpayProvider — createTransfers (escrow validation)', () => {
  const provider = new RazorpayProvider();

  it('throws a 400 when an amount is below ₹1 (100 paise)', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    await expect(
      provider.createTransfers('pay_1', [{ destinationAccount: 'acc_1', amountMinor: 99 }]),
    ).rejects.toMatchObject({ status: 400 });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('throws a 400 when on_hold_until is out of the accepted range', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    await expect(
      provider.createTransfers('pay_1', [
        { destinationAccount: 'acc_1', amountMinor: 500, onHoldUntil: 1 },
      ]),
    ).rejects.toMatchObject({ status: 400 });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('names the offending index/field in the validation error', async () => {
    vi.stubGlobal('fetch', vi.fn());
    await expect(
      provider.createTransfers('pay_1', [
        { destinationAccount: 'acc_1', amountMinor: 500 },
        { destinationAccount: 'acc_2', amountMinor: 50 },
      ]),
    ).rejects.toMatchObject({
      status: 400,
      errors: [{ index: 1, field: 'amountMinor' }],
    });
  });

  it('maps Razorpay items → TransferResult[] on the happy path', async () => {
    const fetchSpy = vi.fn(async () =>
      new Response(
        JSON.stringify({
          items: [
            { id: 'trf_1', recipient: 'acc_1', amount: 600, on_hold: true },
            { id: 'trf_2', recipient: 'acc_2', amount: 400, on_hold: 0 },
          ],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    vi.stubGlobal('fetch', fetchSpy);

    const result = await provider.createTransfers('pay_happy', [
      { destinationAccount: 'acc_1', amountMinor: 600, onHold: true },
      { destinationAccount: 'acc_2', amountMinor: 400 },
    ]);

    expect(result).toEqual([
      { transferRef: 'trf_1', destinationAccount: 'acc_1', amountMinor: 600, onHold: true },
      { transferRef: 'trf_2', destinationAccount: 'acc_2', amountMinor: 400, onHold: false },
    ]);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/payments/pay_happy/transfers');
    expect(init.method).toBe('POST');
    const sentBody = JSON.parse(init.body as string);
    expect(sentBody.transfers[0]).toMatchObject({
      account: 'acc_1',
      amount: 600,
      currency: 'INR',
      on_hold: true,
    });
    expect(sentBody.transfers[1]).not.toHaveProperty('on_hold');
  });

  it('returns [] when Razorpay responds without an items array', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify({}), { status: 200 })),
    );
    const result = await provider.createTransfers('pay_1', [
      { destinationAccount: 'acc_1', amountMinor: 100 },
    ]);
    expect(result).toEqual([]);
  });

  it('rewrites a refund/transfer 400 into the ordering-violation domain error', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        new Response(
          JSON.stringify({ error: { description: 'The transfer was refunded' } }),
          { status: 400 },
        ),
      ),
    );
    await expect(
      provider.createTransfers('pay_1', [{ destinationAccount: 'acc_1', amountMinor: 100 }]),
    ).rejects.toThrow(/Transfers must be created BEFORE refunds/);
  });
});

describe('RazorpayProvider — reverseTransfer', () => {
  const provider = new RazorpayProvider();

  it('throws a 400 when the partial reversal amount is below ₹1', async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal('fetch', fetchSpy);
    await expect(provider.reverseTransfer('trf_1', 99)).rejects.toMatchObject({
      status: 400,
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('posts an empty body (full reversal) when no amount is given', async () => {
    const fetchSpy = vi.fn(async () => new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetchSpy);
    await provider.reverseTransfer('trf_1');
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/transfers/trf_1/reversals');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({});
  });

  it('posts the amount for a valid partial reversal', async () => {
    const fetchSpy = vi.fn(async () => new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetchSpy);
    await provider.reverseTransfer('trf_1', 250);
    const [, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(JSON.parse(init.body as string)).toEqual({ amount: 250 });
  });
});

describe('RazorpayProvider — onboarding (Accounts /v2)', () => {
  const provider = new RazorpayProvider();

  it('createLinkedAccount creates the account, requests the Route product, and submits the bank', async () => {
    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'acc_NEW', status: 'created' }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'acc_prod_1' }), { status: 200 }))
      .mockResolvedValueOnce(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetchSpy);

    const res = await provider.createLinkedAccount({
      shopId: 7,
      email: 'm@shop.test',
      phone: '9999999999',
      legalBusinessName: 'Shop LLP',
      businessType: 'partnership',
      contactName: 'Owner',
      category: 'ecommerce',
      registeredAddress: {
        street1: '1 MG Road',
        city: 'Bengaluru',
        state: 'KARNATAKA',
        postalCode: '560001',
        country: 'IN',
      },
      pan: 'AAACL1234C',
      gst: '29AABCU9603R1ZX',
      beneficiaryName: 'Shop LLP',
      bankAccountNumber: '1234567890',
      bankIfsc: 'HDFC0001234',
    });

    expect(res).toEqual({ providerAccountId: 'acc_NEW', kycStatus: 'ACTIVATED', payoutsEnabled: true });
    expect(fetchSpy).toHaveBeenCalledTimes(3);

    const [url1, init1] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url1).toBe('https://api.razorpay.com/v2/accounts');
    expect(init1.method).toBe('POST');
    const body1 = JSON.parse(init1.body as string);
    expect(body1).toMatchObject({
      type: 'route',
      legal_business_name: 'Shop LLP',
      reference_id: 'shop_7',
      legal_info: { pan: 'AAACL1234C', gst: '29AABCU9603R1ZX' },
      profile: {
        category: 'ecommerce',
        addresses: {
          registered: { city: 'Bengaluru', state: 'KARNATAKA', postal_code: '560001', country: 'IN' },
        },
      },
    });
    expect(body1.customer_facing_business_name).toBe('Shop LLP');

    const [url2, init2] = fetchSpy.mock.calls[1] as [string, RequestInit];
    expect(url2).toBe('https://api.razorpay.com/v2/accounts/acc_NEW/products');
    expect(JSON.parse(init2.body as string)).toMatchObject({ product_name: 'route' });

    const [url3, init3] = fetchSpy.mock.calls[2] as [string, RequestInit];
    expect(url3).toBe('https://api.razorpay.com/v2/accounts/acc_NEW/products/acc_prod_1');
    expect(init3.method).toBe('PATCH');
    expect(JSON.parse(init3.body as string).settlements).toEqual({
      account_number: '1234567890',
      ifsc_code: 'HDFC0001234',
      beneficiary_name: 'Shop LLP',
    });
  });

  it('fetchAccountStatus reports payoutsEnabled once activated', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify({ status: 'activated' }), { status: 200 })),
    );
    const res = await provider.fetchAccountStatus('acc_1');
    expect(res).toEqual({ kycStatus: 'ACTIVATED', payoutsEnabled: true });
  });

  it('fetchAccountStatus is not-yet-enabled while under review', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify({ status: 'under_review' }), { status: 200 })),
    );
    const res = await provider.fetchAccountStatus('acc_1');
    expect(res).toEqual({ kycStatus: 'UNDER_REVIEW', payoutsEnabled: false });
  });
});

describe('RazorpayProvider — retry + circuit breaker', () => {
  const fast = () => new RazorpayProvider({ retryBaseMs: 0, jitter: false });

  it('retries an idempotent GET on a 5xx, then succeeds', async () => {
    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(new Response('{}', { status: 503 }))
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({ id: 'pay_1', status: 'captured', amount: 5000, currency: 'INR' }),
          { status: 200 },
        ),
      );
    vi.stubGlobal('fetch', fetchSpy);

    const res = await fast().fetchPaymentStatus('pay_1');

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(res.status).toBe('PAID');
  });

  it('does NOT retry a non-idempotent POST on a 5xx (avoids double-act)', async () => {
    const fetchSpy = vi.fn(async () =>
      new Response(JSON.stringify({ error: { description: 'server error' } }), { status: 503 }),
    );
    vi.stubGlobal('fetch', fetchSpy);

    await expect(fast().reverseTransfer('trf_1')).rejects.toMatchObject({ status: 502 });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('DOES retry a non-idempotent POST on a 429 (rate-limited ⇒ not processed)', async () => {
    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ error: { description: 'rate limited' } }), { status: 429 }),
      )
      .mockResolvedValueOnce(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetchSpy);

    await expect(fast().reverseTransfer('trf_1')).resolves.toBeUndefined();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it('does NOT retry a permanent 400 on a GET', async () => {
    const fetchSpy = vi.fn(async () =>
      new Response(JSON.stringify({ error: { description: 'bad id' } }), { status: 400 }),
    );
    vi.stubGlobal('fetch', fetchSpy);

    await expect(fast().fetchPaymentStatus('pay_bad')).rejects.toMatchObject({ status: 400 });
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('opens the circuit after the threshold of transient failures and fails fast', async () => {
    const fetchSpy = vi.fn(async () => new Response('{}', { status: 503 }));
    vi.stubGlobal('fetch', fetchSpy);
    const provider = new RazorpayProvider({
      maxRetries: 1,
      circuitThreshold: 2,
      retryBaseMs: 0,
      jitter: false,
    });

    await expect(provider.fetchPaymentStatus('p1')).rejects.toBeDefined();
    await expect(provider.fetchPaymentStatus('p2')).rejects.toBeDefined();
    await expect(provider.fetchPaymentStatus('p3')).rejects.toMatchObject({ status: 503 });
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it('half-open probe SUCCESS closes the circuit (recovery)', async () => {
    const provider = new RazorpayProvider({
      maxRetries: 1,
      circuitThreshold: 2,
      circuitCooldownMs: 0,
      retryBaseMs: 0,
      jitter: false,
    });
    const ok = () =>
      new Response(
        JSON.stringify({ id: 'pay_x', status: 'captured', amount: 100, currency: 'INR' }),
        { status: 200 },
      );
    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(new Response('{}', { status: 503 }))
      .mockResolvedValueOnce(new Response('{}', { status: 503 }))
      .mockResolvedValueOnce(ok())
      .mockResolvedValueOnce(ok());
    vi.stubGlobal('fetch', fetchSpy);

    await expect(provider.fetchPaymentStatus('p1')).rejects.toBeDefined();
    await expect(provider.fetchPaymentStatus('p2')).rejects.toBeDefined();
    await expect(provider.fetchPaymentStatus('p3')).resolves.toMatchObject({ status: 'PAID' });
    await expect(provider.fetchPaymentStatus('p4')).resolves.toMatchObject({ status: 'PAID' });
    expect(fetchSpy).toHaveBeenCalledTimes(4);
  });

  it('half-open probe FAILURE re-opens the circuit (does not get stuck passing)', async () => {
    vi.useFakeTimers();
    try {
      const provider = new RazorpayProvider({
        maxRetries: 1,
        circuitThreshold: 2,
        circuitCooldownMs: 30_000,
        retryBaseMs: 0,
        jitter: false,
      });
      const fetchSpy = vi.fn(async () => new Response('{}', { status: 503 }));
      vi.stubGlobal('fetch', fetchSpy);

      await expect(provider.fetchPaymentStatus('p1')).rejects.toBeDefined();
      await expect(provider.fetchPaymentStatus('p2')).rejects.toBeDefined();
      await expect(provider.fetchPaymentStatus('p3')).rejects.toMatchObject({ status: 503 });
      expect(fetchSpy).toHaveBeenCalledTimes(2);

      vi.advanceTimersByTime(31_000);
      await expect(provider.fetchPaymentStatus('p4')).rejects.toBeDefined();
      expect(fetchSpy).toHaveBeenCalledTimes(3);

      await expect(provider.fetchPaymentStatus('p5')).rejects.toMatchObject({ status: 503 });
      expect(fetchSpy).toHaveBeenCalledTimes(3);
    } finally {
      vi.useRealTimers();
    }
  });
});
