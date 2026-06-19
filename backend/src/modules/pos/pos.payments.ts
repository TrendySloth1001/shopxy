/**
 * POS online-payment orchestration — the seam between the POS cart (pos.service)
 * and the payment gateway (paymentGatewayService). Kept OUT of pos.service so
 * pos.service has no dependency on the gateway (the gateway's settlement handler
 * imports pos.service; routing the orchestration through here keeps that edge
 * one-way and cycle-free).
 *
 * Flow: the till opens **Razorpay Checkout** for the "Online" tender (Checkout
 * itself shows a UPI QR + cards). We create a Razorpay ORDER (the same path the
 * customer online-order flow uses — enabled on the account, unlike the standalone
 * QR Codes API) and hand the client the `clientParams`. The sale settles on the
 * `payment.captured`/`order.paid` webhook via the POS settlement handler; the
 * client also calls `syncOnline` after the sheet closes so it settles even when
 * the webhook can't reach the server (localhost / delayed delivery).
 *
 * Functional module, no classes — matches the rest of POS.
 */
import * as pos from './pos.service.js';
import type { SaleSnapshot, PosError } from './pos.service.js';
import { paymentGatewayService } from '../payment-gateway/index.js';

const PROVIDER = 'RAZORPAY';

/** Pay session handed to the till to open Razorpay Checkout. */
export interface PosPaySession {
  intentId: number;
  provider: string;
  providerOrderRef: string;
  /** Rupees. */
  amount: number;
  currency: string;
  /** Razorpay Checkout params: { key, order_id, amount(paise), currency }. */
  clientParams: Record<string, unknown>;
  reused: boolean;
}

const isErr = (r: unknown): r is PosError =>
  typeof r === 'object' && r !== null && 'error' in r && typeof (r as { error?: unknown }).error === 'string';

const idemKey = (saleId: number) => `pos-online:${saleId}`;

/**
 * Start an online payment for a sale: lock the cart and create a Razorpay order.
 * Returns the Checkout session for the till to open the Razorpay sheet. The cart
 * is locked (AWAITING_PAYMENT) so the order amount can't drift under it.
 */
export async function payOnline(shopId: number, saleId: number): Promise<PosPaySession | PosError> {
  // Lock the cart so its total is frozen for the order.
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
      // The order was already captured — don't unlock; let the till sync/refresh.
      return { error: 'This sale is already paid' };
    }
    // Order creation failed — unlock so the till can retry / use another tender.
    await pos.unlockSale(shopId, saleId);
    return { error: err.message || 'Could not start the online payment' };
  }
}

/**
 * Settle backstop after the Razorpay sheet reports success: re-checks the live
 * order and, if paid, settles the sale (same path the webhook uses; idempotent).
 * Returns the fresh snapshot — CHECKED_OUT once settled.
 */
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

/**
 * Cancel an outstanding online payment (sheet dismissed/failed): abandon the
 * intent and unlock the cart. If it was paid in the race, leaves it to settle
 * via the webhook and returns the current snapshot.
 */
export async function cancelOnline(shopId: number, saleId: number): Promise<SaleSnapshot | PosError> {
  const intentId = await pos.getOutstandingIntent(shopId, saleId);
  if (intentId != null) {
    const intent = await paymentGatewayService.getIntent(intentId);
    if (intent?.status === 'CAPTURED' || intent?.status === 'REFUNDED') {
      return pos.snapshot(shopId, saleId);
    }
    await paymentGatewayService.abandonIntent(intentId); // unlock + fail (closes QR only if one)
  } else {
    await pos.unlockSale(shopId, saleId);
  }
  return pos.snapshot(shopId, saleId);
}
