/**
 * Lightweight audit tracker for the gateway lifecycle. Structured, non-throwing,
 * non-blocking — mirrors the prior project's PaymentTracker but logs only for
 * now. When the `GatewayPaymentEvent` table lands, back this with a DB writer
 * (keep the same call sites); the in-memory fallback pattern from the prior
 * implementation is the model.
 */
export type GatewayStep =
  | 'INTENT_CREATED'
  | 'INTENT_REUSED'
  | 'SESSION_CREATED'
  | 'WEBHOOK_RECEIVED'
  | 'WEBHOOK_DEDUPED'
  | 'WEBHOOK_IGNORED'
  | 'PAYMENT_CONFIRMED'
  | 'PAYMENT_FAILED'
  | 'SETTLEMENT_DONE'
  | 'AMOUNT_MISMATCH'
  | 'SIGNATURE_FAILED'
  | 'ORDER_STATUS_UNAVAILABLE'
  | 'INTENT_RETRIED'
  | 'RECONCILE_PAID'
  | 'RECONCILE_SWEEP'
  | 'RECONCILE_ABANDONED'
  | 'ROUTE_SPLIT_ROWS'
  | 'ROUTE_SPLIT_EXECUTED'
  | 'ROUTE_SPLIT_RECONCILED'
  | 'ROUTE_SPLIT_FAILED'
  | 'REFUND_ISSUED'
  | 'REFUND_REPLAYED'
  | 'REFUND_SKIPPED'
  | 'REFUND_FAILED'
  | 'REFUND_PROCESSED';

export interface GatewayTrackEvent {
  step: GatewayStep;
  provider?: string;
  intentId?: number;
  providerOrderRef?: string | null;
  providerPaymentRef?: string | null;
  targetType?: string;
  status?: 'INFO' | 'SUCCESS' | 'FAILED';
  error?: string;
  meta?: Record<string, unknown>;
}

export const tracker = {
  track(evt: GatewayTrackEvent): void {
    try {
      // eslint-disable-next-line no-console
      console.log(
        JSON.stringify({ tag: 'payment-gateway', ts: new Date().toISOString(), ...evt }),
      );
    } catch {
      /* never let audit logging break the payment path */
    }
  },
};
