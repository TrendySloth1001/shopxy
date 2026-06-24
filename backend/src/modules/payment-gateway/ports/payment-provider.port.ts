/**
 * The port every payment gateway implements. This is the stable contract;
 * adapters (providers/<name>.provider.ts) are the swappable implementations.
 *
 * Rule: nothing provider-specific leaks past this interface. Inputs are minor
 * units + neutral params; outputs are the normalised DTOs from ./types.
 */
import type {
  GatewaySession,
  NormalizedEvent,
  NormalizedOrderStatus,
  NormalizedRefund,
  NormalizedStatus,
} from './types.js';

/** Raw HTTP header bag as Express delivers it. */
export type HeaderBag = Record<string, string | string[] | undefined>;

export interface CreateSessionParams {
  amountMinor: number;
  currency: string;
  /** Our intent id, threaded into provider notes so webhooks tie back. */
  intentRef: string;
  notes?: Record<string, string>;
}

export interface HandshakeParams {
  providerOrderRef: string;
  providerPaymentRef: string;
  signature: string;
}

export interface RefundParams {
  providerPaymentRef: string;
  amountMinor: number;
  idempotencyKey?: string;
  notes?: Record<string, string>;
}

export interface PaymentGatewayPort {
  /** Registry key, e.g. 'RAZORPAY'. */
  readonly name: string;

  /** Create the server-side order/session; returns ref + client params. */
  createSession(p: CreateSessionParams): Promise<GatewaySession>;

  /**
   * Rebuild the client checkout params for an existing provider order
   * (used on idempotent re-initiate so we don't mint a duplicate order).
   * createSession is expected to delegate to this internally.
   */
  buildClientParams(p: {
    providerOrderRef: string;
    amountMinor: number;
    currency: string;
  }): Record<string, unknown>;

  /** Verify the client-side handshake (order|payment|signature). UX only. */
  verifyHandshake(p: HandshakeParams): boolean;

  /** Verify the webhook HMAC over the RAW bytes. */
  verifyWebhookSignature(rawBody: Buffer, headers: HeaderBag): boolean;

  /** Normalise a webhook payload (+headers for the event id) to our shape. */
  parseWebhookEvent(rawBody: Buffer, headers: HeaderBag): NormalizedEvent;

  /** Server-side status fetch, for reconciliation of missed webhooks. */
  fetchPaymentStatus(providerPaymentRef: string): Promise<NormalizedStatus>;

  /**
   * Live status of a previously-created order. Lets the orchestrator decide, on
   * a retry, whether reopening checkout is safe (order still unpaid) or whether
   * it must reconcile (a payment already captured — common when the webhook
   * never arrived, e.g. a localhost dev server Razorpay can't reach).
   */
  fetchOrderStatus(providerOrderRef: string): Promise<NormalizedOrderStatus>;

  /** Issue a refund. */
  refund(p: RefundParams): Promise<NormalizedRefund>;

  /** Server-side status of a previously-issued refund, for the reconciliation
   *  sweep: heal a PENDING refund whose `refund.processed` webhook was missed,
   *  and confirm whether a re-driven refund settled. */
  fetchRefundStatus(providerRefundRef: string): Promise<NormalizedRefund>;
}

// ── Optional capability: marketplace split + on-hold settlement (Razorpay Route etc.) ──
//
// A gateway that can't do split settlement simply doesn't implement this. The
// core checks `isSplitCapable()` before using it, so the base port stays
// unchanged for non-split providers — preserving the isolation property.

export interface TransferRequest {
  /** Provider linked-account id the funds go to. */
  destinationAccount: string;
  amountMinor: number;
  /** On-hold settlement: park the transfer in the provider's balance instead
   *  of settling it to the seller immediately (Razorpay Route `on_hold`). */
  onHold?: boolean;
  /** Optional unix-seconds auto-release. */
  onHoldUntil?: number;
  notes?: Record<string, string>;
}

export interface TransferResult {
  transferRef: string;
  destinationAccount: string;
  amountMinor: number;
  onHold: boolean;
}

/** A transfer already created on a payment, as the provider reports it. The
 *  `notes` carry our deterministic idempotency key so fetch-before-create can
 *  match an existing transfer back to the row it belongs to. `status` and
 *  `amountReversedMinor` are what transfer-level reconciliation needs to tell
 *  HELD from RELEASED/REVERSED and to verify partial-reversal amounts — without
 *  them you cannot reconcile a hold lifecycle (lesson from the tutorix port). */
export interface ExistingTransfer {
  transferRef: string;
  destinationAccount: string;
  amountMinor: number;
  onHold: boolean;
  /** Provider transfer status, e.g. 'created' | 'processed' | 'reversed' | 'failed'. */
  status: string;
  /** Cumulative amount reversed so far (paise). 0 when none. */
  amountReversedMinor: number;
  notes: Record<string, string>;
}

export interface SplitCapablePort {
  createTransfers(
    providerPaymentRef: string,
    transfers: TransferRequest[],
  ): Promise<TransferResult[]>;
  /**
   * List transfers already created on a payment. The idempotency primitive:
   * before creating, callers fetch what exists and match on the deterministic
   * key in `notes`, so a retry/heal reconciles instead of double-paying.
   */
  listTransfers(providerPaymentRef: string): Promise<ExistingTransfer[]>;
  /** Release an on-hold transfer so it settles to the seller. */
  releaseTransfer(transferRef: string): Promise<void>;
  /** Reverse a transfer (in-hold return, dispute, refund). */
  reverseTransfer(transferRef: string, amountMinor?: number): Promise<void>;
}

export function isSplitCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & SplitCapablePort {
  return typeof (p as Partial<SplitCapablePort>).createTransfers === 'function';
}

// ── Optional capability: linked-account KYC onboarding (Razorpay Route etc.) ──
//
// A provider that can onboard payout destinations implements this. The
// linked-accounts service checks `isOnboardingCapable()` before using it.

/** Registered business address (profile.addresses.registered at Razorpay).
 *  Forwarded to the provider, never stored by us. */
export interface RegisteredAddress {
  street1: string;
  street2?: string;
  city: string;
  /** State name as the provider expects it, e.g. "KARNATAKA". */
  state: string;
  postalCode: string;
  /** ISO country, e.g. "IN". */
  country: string;
}

export interface CreateLinkedAccountParams {
  shopId: number;
  email: string;
  phone: string;
  legalBusinessName: string;
  /** Brand/display name shown to customers; defaults to legalBusinessName. */
  customerFacingBusinessName?: string;
  businessType: string;
  contactName: string;
  /** Business category (profile.category), e.g. "ecommerce". */
  category: string;
  /** Business subcategory (profile.subcategory) — optional at creation. */
  subcategory?: string;
  registeredAddress: RegisteredAddress;
  /** KYC identity — submitted to the provider, NEVER stored by us. PAN is
   *  mandatory for activation; GST is optional. */
  pan: string;
  gst?: string;
  /** Settlement bank account — submitted to the provider, NEVER stored by us
   *  (data minimization). This is what actually lets the seller be paid out. */
  beneficiaryName: string;
  bankAccountNumber: string;
  bankIfsc: string;
}

export interface LinkedAccountResult {
  /** Provider linked-account id (acc_XXXX). */
  providerAccountId: string;
  /** Provider KYC status string, e.g. 'created' | 'activated'. */
  kycStatus: string;
  /** True only when the account can actually be settled to. */
  payoutsEnabled: boolean;
}

export interface OnboardingCapablePort {
  /** Create a payout destination (Route linked account) for a shop. */
  createLinkedAccount(p: CreateLinkedAccountParams): Promise<LinkedAccountResult>;
  /** Server-side status fetch — the source of truth for KYC, and the
   *  self-heal for a dropped account.* webhook. */
  fetchAccountStatus(
    providerAccountId: string,
  ): Promise<{ kycStatus: string; payoutsEnabled: boolean }>;
  /** Fetch an existing account's identity + status — for the "connect an
   *  existing acc_XXXX" flow (verify the id, show details to confirm). Rejects
   *  if the id isn't a linked account under this platform. */
  fetchAccount(providerAccountId: string): Promise<{
    accountId: string;
    kycStatus: string;
    payoutsEnabled: boolean;
    email: string | null;
    legalBusinessName: string | null;
    contactName: string | null;
    businessType: string | null;
  }>;
}

export function isOnboardingCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & OnboardingCapablePort {
  return typeof (p as Partial<OnboardingCapablePort>).createLinkedAccount === 'function';
}

// ── Optional capability: dynamic UPI QR (Razorpay QR Codes) ────────────────
//
// A provider that can mint a fixed-amount, single-use UPI QR implements this.
// The POS uses it to take an in-store online payment: the customer scans the
// QR with any UPI app, and the `qr_code.credited` webhook drives settlement.
// Non-QR providers simply don't implement it; the POS checks `isQrCapable()`
// before offering the QR tender — same isolation discipline as Split/Onboarding.

export interface CreatePosQrParams {
  amountMinor: number;
  /** Our intent id, threaded into notes so the webhook ties back. */
  intentRef: string;
  notes?: Record<string, string>;
}

export interface PosQrResult {
  /** Provider QR id (Razorpay: qr_XXXX) — stored as the intent's order ref so
   *  the webhook ownership lookup resolves it without a new column. */
  qrId: string;
  /** Image to render at the till (a hosted PNG/SVG URL). */
  imageUrl: string;
}

export interface QrCapablePort {
  /** Create a fixed-amount, single-use UPI QR for one sale. */
  createPosQr(p: CreatePosQrParams): Promise<PosQrResult>;
  /** Re-fetch a QR's image + closed flag (for a resumed/replayed pay request). */
  fetchQr(qrId: string): Promise<{ imageUrl: string; closed: boolean }>;
  /** Close a QR so it stops accepting payments (cancel / abandon-sweep). */
  closeQr(qrId: string): Promise<void>;
}

export function isQrCapable(
  p: PaymentGatewayPort,
): p is PaymentGatewayPort & QrCapablePort {
  return typeof (p as Partial<QrCapablePort>).createPosQr === 'function';
}
