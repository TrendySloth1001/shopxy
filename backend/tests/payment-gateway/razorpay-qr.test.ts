import { describe, it, expect, afterEach, vi } from 'vitest';

process.env.RAZORPAY_KEY_ID = 'rzp_test_key';
process.env.RAZORPAY_KEY_SECRET = 'rzp_test_secret';
process.env.RAZORPAY_WEBHOOK_SECRET = 'whsec_test';

const { RazorpayProvider } = await import(
  '../../src/modules/payment-gateway/providers/razorpay.provider.js'
);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('RazorpayProvider — parseWebhookEvent (qr_code.credited)', () => {
  const provider = new RazorpayProvider();

  it('maps a QR credit to PAID and resolves ownership by the QR id', () => {
    const body = Buffer.from(
      JSON.stringify({
        event: 'qr_code.credited',
        payload: {
          qr_code: { entity: { id: 'qr_abc' } },
          payment: { entity: { id: 'pay_xyz', amount: 15000, currency: 'INR' } },
        },
      }),
    );
    const ev = provider.parseWebhookEvent(body, { 'x-razorpay-event-id': 'evt_qr' });
    expect(ev.type).toBe('PAID');
    expect(ev.providerOrderRef).toBe('qr_abc');
    expect(ev.providerPaymentRef).toBe('pay_xyz');
    expect(ev.amountMinor).toBe(15000);
    expect(ev.eventId).toBe('evt_qr');
  });
});

describe('RazorpayProvider — createPosQr', () => {
  const provider = new RazorpayProvider();

  it('POSTs a single-use, fixed-amount UPI QR and returns id + image', async () => {
    const fetchSpy = vi.fn(async () =>
      jsonResponse({ id: 'qr_new', image_url: 'https://rzp/qr.png' }),
    );
    vi.stubGlobal('fetch', fetchSpy);

    const res = await provider.createPosQr({
      amountMinor: 5000,
      intentRef: '42',
      notes: { app: 'shopxy' },
    });
    expect(res).toEqual({ qrId: 'qr_new', imageUrl: 'https://rzp/qr.png' });

    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/payments/qr_codes');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toMatchObject({
      type: 'upi_qr',
      usage: 'single_use',
      fixed_amount: true,
      payment_amount: 5000,
      notes: { app: 'shopxy' },
    });
  });
});

describe('RazorpayProvider — fetchOrderStatus routes qr_ refs to the QR endpoint', () => {
  const provider = new RazorpayProvider();

  it('reports PAID + captured ref when the QR has a captured payment', async () => {
    const fetchSpy = vi.fn(async () =>
      jsonResponse({ items: [{ id: 'pay_1', status: 'captured', amount: 5000 }] }),
    );
    vi.stubGlobal('fetch', fetchSpy);

    const st = await provider.fetchOrderStatus('qr_abc');
    expect(st).toEqual({ status: 'PAID', amountPaidMinor: 5000, capturedPaymentRef: 'pay_1' });
    expect((fetchSpy.mock.calls[0] as [string])[0]).toBe(
      'https://api.razorpay.com/v1/payments/qr_codes/qr_abc/payments',
    );
  });

  it('reports CREATED when the QR has no captured payment yet', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({ items: [] })));
    const st = await provider.fetchOrderStatus('qr_abc');
    expect(st).toEqual({ status: 'CREATED', amountPaidMinor: 0, capturedPaymentRef: null });
  });
});

describe('RazorpayProvider — closeQr', () => {
  const provider = new RazorpayProvider();

  it('POSTs to the QR close endpoint', async () => {
    const fetchSpy = vi.fn(async () => jsonResponse({ id: 'qr_x', status: 'closed' }));
    vi.stubGlobal('fetch', fetchSpy);
    await provider.closeQr('qr_x');
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/payments/qr_codes/qr_x/close');
    expect(init.method).toBe('POST');
  });

  it('swallows a 400 (already closed) so cancel/abandon never wedges', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse({ error: { description: 'already closed' } }, 400)),
    );
    await expect(provider.closeQr('qr_x')).resolves.toBeUndefined();
  });
});
