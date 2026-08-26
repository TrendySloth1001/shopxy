import type { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { paymentGatewayService, listEnabledProviders } from './index.js';

const topUpSchema = z.object({
  amount: z.number().positive().max(200000),
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
  return decodeId(raw);
}

export class PaymentGatewayController {
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

  async providers(_req: Request, res: Response): Promise<void> {
    res.json({ providers: listEnabledProviders() });
  }

  async webhook(req: Request, res: Response): Promise<void> {
    const provider = req.params.provider;
    const rawBody: Buffer = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(typeof req.body === 'string' ? req.body : '');
    if (rawBody.length === 0) {
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
      if (status && status >= 400 && status < 500) {
        res.status(200).json({ received: true, ignored: true });
        return;
      }
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
