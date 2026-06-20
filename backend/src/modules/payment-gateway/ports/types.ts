/**
 * Provider-neutral payment-gateway domain types.
 *
 * Nothing here knows about Razorpay, Stripe, paise, or webhook JSON shapes.
 * Adapters normalise into these types at the provider edge; the core service
 * and settlement handlers only ever see these. That is what lets a second
 * gateway slot in without touching the core (see PAYMENT_GATEWAY_ARCHITECTURE.md).
 */

/** Registered provider key, e.g. 'RAZORPAY'. String (not enum) so a new */
/** gateway is config, not a migration. */
export type ProviderName = string;

/**
 * Intent lifecycle. Transitions only advance:
 *   CREATED → PENDING → CAPTURED   (success)
 *   CREATED → PENDING → FAILED     (terminal failure)
 *   CAPTURED → REFUNDED            (after a full refund)
 * A webhook redelivering an older state is ignored (idempotent — the core
 * treats an already-CAPTURED intent as a no-op).
 */
export type GatewayPaymentStatus =
  | 'CREATED'
  | 'PENDING'
  | 'CAPTURED'
  | 'FAILED'
  | 'REFUNDED';

/** Which domain object the money settles against. */
export type SettlementTargetType = 'WALLET' | 'ORDER' | 'INVOICE' | 'CAUTION' | 'POS';

export interface SettlementTarget {
  type: SettlementTargetType;
  /**
   * Domain id the payment settles against. For WALLET this is the
   * customerUserId; for ORDER the CustomerOrder id; for INVOICE the Invoice
   * id; for CAUTION the CautionRequest id; for POS the Sale id (an in-store
   * UPI-QR tender — the capture is what turns the cart into a confirmed sale).
   */
  id: number;
}

/**
 * Provider-neutral record of one payment intent/attempt. Mirrors the future
 * `GatewayPayment` table (§7 of the design doc); defined here so the core
 * compiles and is unit-testable against the type rather than against Prisma.
 *
 * `amount` is in the domain unit (rupees). Minor units (paise) exist only at
 * the provider boundary — see helpers.toMinorUnits.
 */
export interface GatewayPaymentRecord {
  id: number;
  provider: ProviderName;
  status: GatewayPaymentStatus;
  amount: number;
  currency: string;
  target: SettlementTarget;
  shopId: number | null;
  customerUserId: number | null;
  providerOrderRef: string | null;
  providerPaymentRef: string | null;
  idempotencyKey: string | null;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Normalised webhook/poll outcome. Every provider's status strings map here.
 * The first five are payment-intent events; the rest are marketplace
 * settlement events (Route transfers, linked-account KYC, disputes) that the
 * core routes to the settlement webhook handlers instead of the intent path.
 */
export type GatewayEventType =
  | 'PAID'
  | 'FAILED'
  | 'REFUNDED'
  | 'PENDING'
  | 'UNKNOWN'
  | 'TRANSFER_PROCESSED'
  | 'TRANSFER_FAILED'
  | 'TRANSFER_REVERSED'
  | 'ACCOUNT_UPDATED'
  | 'DISPUTE_LOST'
  | 'DISPUTE_OTHER';

/** A Route transfer as a `transfer.*` webhook reports it. */
export interface NormalizedTransferEvent {
  ref: string;
  /** Provider transfer status, e.g. 'processed' | 'reversed' | 'failed'. */
  status: string;
  amountReversedMinor: number;
  onHold: boolean;
}

/** A linked account as an `account.*` webhook reports it. */
export interface NormalizedAccountEvent {
  ref: string;
  /** Provider account status, e.g. 'activated' | 'suspended' | 'needs_clarification'. */
  status: string;
}

/** A dispute as a `payment.dispute.*` webhook reports it. */
export interface NormalizedDisputeEvent {
  ref: string;
  providerPaymentRef: string | null;
}

export interface NormalizedEvent {
  type: GatewayEventType;
  /** Provider's webhook event id — the dedupe key. */
  eventId: string;
  providerOrderRef: string | null;
  providerPaymentRef: string | null;
  /** Minor units (paise) as the provider reported them; null if absent. */
  amountMinor: number | null;
  currency: string | null;
  /** Populated for TRANSFER_* events. */
  transfer?: NormalizedTransferEvent;
  /** Populated for ACCOUNT_UPDATED events. */
  account?: NormalizedAccountEvent;
  /** Populated for DISPUTE_* events. */
  dispute?: NormalizedDisputeEvent;
  /** Original payload, persisted for audit. */
  raw: unknown;
}

/** What the client SDK needs to open checkout. */
export interface GatewaySession {
  providerOrderRef: string;
  /** Provider-specific bag (Razorpay: key/order_id/amount; Stripe: clientSecret). */
  clientParams: Record<string, unknown>;
}

export interface NormalizedStatus {
  status: GatewayEventType;
  amountMinor: number | null;
  currency: string | null;
  providerPaymentRef: string | null;
}

export interface NormalizedRefund {
  providerRefundRef: string;
  amountMinor: number;
  status: 'PENDING' | 'PROCESSED' | 'FAILED';
}

/**
 * Live status of a provider ORDER (not a single payment), used to decide whether
 * a retry can safely reopen checkout. `PAID` means a payment was captured against
 * this order — reopening it would fail (Razorpay shows a frozen "something went
 * wrong"), so the caller must reconcile instead of re-presenting the sheet.
 */
export interface NormalizedOrderStatus {
  status: 'CREATED' | 'ATTEMPTED' | 'PAID';
  amountPaidMinor: number;
  /** The captured payment's provider ref when status === 'PAID', else null. */
  capturedPaymentRef: string | null;
}
