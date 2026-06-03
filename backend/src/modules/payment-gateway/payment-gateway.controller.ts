import type { Request, Response } from 'express';
import { z } from 'zod';
import { paymentGatewayService, listEnabledProviders } from './index.js';

/**
 * First slice: wallet top-up. The customer principal (req.user.sub) tops up
 * their own wallet, so the settlement target is always WALLET → self. Other
 * targets (ORDER/INVOICE/CAUTION) plug in here later via the same service call.
 */
const topUpSchema = z.object({
  amount: z.number().positive().max(200000), // ₹2L sane cap; tune per policy
  provider: z.string().min(1).max(40).optional(),
});

function requireUserId(req: Request, res: Response): number | null {
  const sub = req.user?.sub;
  if (!sub) {
    res.status(401).json({ error: 'Authentication required' });
    return null;
  }
  return sub;
}

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class PaymentGatewayController {
  /** POST /me/wallet/topup — create a checkout session funding the wallet. */
  async initiateWalletTopUp(req: Request, res: Response): Promise<void> {
    const userId = requireUserId(req, res);
    if (userId == null) return;

    const payload = topUpSchema.parse(req.body);
    const rawKey = req.get('x-idempotency-key') ?? req.get('X-Idempotency-Key');
    if (rawKey && rawKey.length > 120) {
      res.status(400).json({ error: 'Idempotency key must not exceed 120 characters' });
      return;
    }
    const idempotencyKey =
      typeof rawKey === 'string' && rawKey.length > 0 && rawKey.length <= 120
        ? rawKey
        : null;

    try {
      const result = await paymentGatewayService.initiatePayment({
        provider: (payload.provider ?? 'RAZORPAY').toUpperCase(),
        target: { type: 'WALLET', id: userId },
        amount: payload.amount,
        currency: 'INR',
        shopId: null,
        customerUserId: userId,
        idempotencyKey,
      });
      res.status(201).json(result);
    } catch (err) {
      const status = (err as { status?: number })?.status ?? 400;
      const message = err instanceof Error ? err.message : 'Failed to start payment';
      res.status(status).json({ error: message });
    }
  }

  /** GET /me/wallet/topup/:id — read one intent (scoped to the caller). */
  async getIntent(req: Request, res: Response): Promise<void> {
    const userId = requireUserId(req, res);
    if (userId == null) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const intent = await paymentGatewayService.getIntent(id);
    if (!intent || intent.customerUserId !== userId) {
      res.status(404).json({ error: 'Payment not found' });
      return;
    }
    res.json(intent);
  }

  /** GET /payment-gateway/providers — which gateways are enabled. */
  async providers(_req: Request, res: Response): Promise<void> {
    res.json({ providers: listEnabledProviders() });
  }

  /**
   * POST /payment-gateway/webhook/:provider — provider → us. UNAUTHENTICATED;
   * trust comes from the signature, not a JWT. Requires the RAW body (see
   * routes + WIRING.md). Returns 200 on success, 500 on transient error so the
   * provider retries.
   */
  async webhook(req: Request, res: Response): Promise<void> {
    const provider = req.params.provider;
    const rawBody: Buffer = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(typeof req.body === 'string' ? req.body : '');
    if (rawBody.length === 0) {
      // Empty/uncaptured body → permanent. Ack with 200 so the provider stops
      // retrying (a 4xx-class issue must never surface as a retry-forcing 5xx
      // on a shared account).
      res.status(200).json({ received: true, ignored: true });
      return;
    }
    try {
      await paymentGatewayService.handleWebhook(
        provider,
        rawBody,
        req.headers as Record<string, string | string[] | undefined>,
      );
      res.status(200).json({ received: true });
    } catch (err) {
      const status = (err as { status?: number })?.status;
      // 4xx = permanent (bad signature/data) → ack so the provider stops.
      // Anything else = transient → 500 so the provider retries.
      if (status && status >= 400 && status < 500) {
        res.status(200).json({ received: true, ignored: true });
        return;
      }
      // A malformed body (SyntaxError) is a permanent client error → ack so the
      // provider stops retrying rather than hammering a shared endpoint.
      if (err instanceof SyntaxError) {
        res.status(200).json({ received: true, ignored: true });
        return;
      }
      // eslint-disable-next-line no-console
      console.error('[payment-gateway] webhook error:', err);
      res.status(500).json({ error: 'Transient processing error' });
    }
  }
}

export const paymentGatewayController = new PaymentGatewayController();
