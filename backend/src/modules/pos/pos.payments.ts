import * as pos from './pos.service.js';
import type { SaleSnapshot, PosError } from './pos.service.js';
import { paymentGatewayService } from '../payment-gateway/index.js';

const PROVIDER = 'RAZORPAY';

export interface PosPaySession {
  intentId: number;
  provider: string;
  providerOrderRef: string;
  amount: number;
  currency: string;
  clientParams: Record<string, unknown>;
  reused: boolean;
}

const isErr = (r: unknown): r is PosError =>
  typeof r === 'object' && r !== null && 'error' in r && typeof (r as { error?: unknown }).error === 'string';

const idemKey = (saleId: number) => `pos-online:${saleId}`;

export async function payOnline(shopId: number, saleId: number): Promise<PosPaySession | PosError> {
  const locked = await pos.lockSaleForPayment(shopId, saleId);
  if (isErr(locked)) return locked;
  const amount = locked.totals.total;
  if (amount <= 0) {
    await pos.unlockSale(shopId, saleId);
    return { error: 'Cannot charge a zero-value sale' };
  }

  try {
    const res = await paymentGatewayService.initiatePayment({
      provider: PROVIDER,
      target: { type: 'POS', id: saleId },
      amount,
      currency: 'INR',
      shopId,
      customerUserId: null,
      idempotencyKey: idemKey(saleId),
    });
    await pos.attachSaleGatewayPayment(shopId, saleId, res.intentId);
    return {
      intentId: res.intentId,
      provider: res.provider,
      providerOrderRef: res.providerOrderRef,
      amount: res.amount,
      currency: res.currency,
      clientParams: res.clientParams,
      reused: res.reused,
    };
  } catch (e) {
    const err = e as { code?: string; message?: string };
    if (err.code === 'ALREADY_PAID') {
      return { error: 'This sale is already paid' };
    }
    await pos.unlockSale(shopId, saleId);
    return { error: err.message || 'Could not start the online payment' };
  }
}

export async function syncOnline(shopId: number, saleId: number): Promise<SaleSnapshot | PosError> {
  const intentId = await pos.getOutstandingIntent(shopId, saleId);
  if (intentId != null) {
    await paymentGatewayService.syncIntentStatus({
      customerUserId: null,
      idempotencyKey: idemKey(saleId),
    });
  }
  return pos.snapshot(shopId, saleId);
}

export async function cancelOnline(shopId: number, saleId: number): Promise<SaleSnapshot | PosError> {
  const intentId = await pos.getOutstandingIntent(shopId, saleId);
  if (intentId != null) {
    const intent = await paymentGatewayService.getIntent(intentId);
    if (intent?.status === 'CAPTURED' || intent?.status === 'REFUNDED') {
      return pos.snapshot(shopId, saleId);
    }
    await paymentGatewayService.abandonIntent(intentId);
  } else {
    await pos.unlockSale(shopId, saleId);
  }
  return pos.snapshot(shopId, saleId);
}
