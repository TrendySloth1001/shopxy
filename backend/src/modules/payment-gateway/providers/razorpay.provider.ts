/**
 * Razorpay adapter — the ONLY file that knows Razorpay's API, paise, signature
 * scheme, and webhook JSON shape. Implements PaymentGatewayPort. Adding another
 * gateway means adding a sibling file; nothing here changes.
 *
 * Uses Razorpay's REST API directly via global `fetch` + node `crypto`, so it
 * carries no SDK dependency. Swap to the official `razorpay` package later if
 * preferred — the port contract stays the same.
 *
 * Env (only read when RAZORPAY_KEY_ID is present; see registry.ts):
 *   RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET
 */
import type {
  CreateLinkedAccountParams,
  CreatePosQrParams,
  CreateSessionParams,
  ExistingTransfer,
  HandshakeParams,
  HeaderBag,
  LinkedAccountResult,
  OnboardingCapablePort,
  PaymentGatewayPort,
  PosQrResult,
  QrCapablePort,
  RefundParams,
  SplitCapablePort,
  TransferRequest,
  TransferResult,
} from '../ports/payment-provider.port.js';
import type {
  GatewayEventType,
  GatewaySession,
  NormalizedEvent,
  NormalizedOrderStatus,
  NormalizedRefund,
  NormalizedStatus,
} from '../ports/types.js';
import { hmacSha256Hex, timingSafeEqualHex, headerValue } from '../helpers.js';
import { mapProviderKyc, type KycState } from '../kyc-status.js';
import { requireEnv, envOr } from '../../../shared/env.js';

const RAZORPAY_API = 'https://api.razorpay.com/v1';
// The Accounts (onboarding) API lives under /v2, not /v1.
const RAZORPAY_API_V2 = 'https://api.razorpay.com/v2';

// Route transfer constraints (from the Route docs):
const MIN_TRANSFER_PAISE = 100; // amount must be ≥ ₹1
const ON_HOLD_UNTIL_MIN = 946684800; // 2000-01-01 — Razorpay's accepted lower bound
const ON_HOLD_UNTIL_MAX = 4765046400; // ~2121 — Razorpay's accepted upper bound

/** Maps Razorpay event names → our neutral event type. */
function mapEventType(event: string): GatewayEventType {
  switch (event) {
    case 'payment.captured':
    case 'order.paid':
    // A UPI-QR payment lands as `qr_code.credited` (the QR's payment captured).
    // The nested payment entity carries the amount/ref the intent path needs.
    case 'qr_code.credited':
      return 'PAID';
    case 'payment.failed':
      return 'FAILED';
    case 'refund.processed':
    case 'refund.created':
      return 'REFUNDED';
    case 'payment.authorized':
      return 'PENDING';
    case 'transfer.processed':
    case 'transfer.settled':
      return 'TRANSFER_PROCESSED';
    case 'transfer.failed':
      return 'TRANSFER_FAILED';
    case 'transfer.reversed':
      return 'TRANSFER_REVERSED';
    case 'account.activated':
    case 'account.under_review':
    case 'account.needs_clarification':
    case 'account.suspended':
    case 'account.funds_held':
    case 'account.funds_released':
      return 'ACCOUNT_UPDATED';
    case 'payment.dispute.lost':
      return 'DISPUTE_LOST';
    case 'payment.dispute.created':
    case 'payment.dispute.won':
    case 'payment.dispute.closed':
    case 'payment.dispute.under_review':
    case 'payment.dispute.action_required':
      return 'DISPUTE_OTHER';
    default:
      return 'UNKNOWN';
  }
}

/** Maps a Razorpay payment status → our neutral event type. */
function mapPaymentStatus(status: string): GatewayEventType {
  switch (status) {
    case 'captured':
      return 'PAID';
    case 'failed':
      return 'FAILED';
    case 'refunded':
      return 'REFUNDED';
    case 'authorized':
    case 'created':
      return 'PENDING';
    default:
      return 'UNKNOWN';
  }
}

/** Retry + circuit-breaker config (ported from tutorix infra/razorpay.ts). */
export interface RazorpayCallConfig {
  maxRetries?: number; // total attempts
  retryBaseMs?: number; // exponential backoff base (200 → 400 → 800ms)
  jitter?: boolean; // add ±random jitter to backoff
  circuitThreshold?: number; // open after this many failed CALLS (not attempts)…
  circuitWindowMs?: number; // …within this window
  circuitCooldownMs?: number; // stay open this long, then half-open
}

type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

export class RazorpayProvider
  implements PaymentGatewayPort, SplitCapablePort, OnboardingCapablePort, QrCapablePort
{
  readonly name = 'RAZORPAY';

  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;

  // Retry / circuit-breaker config + state (instance-scoped; one provider
  // instance is shared via the registry, so the breaker is global in practice).
  private readonly cfg: Required<RazorpayCallConfig>;
  private circuitState: CircuitState = 'CLOSED';
  private failureTimestamps: number[] = [];
  private circuitOpenedAt = 0;
  // While OPEN cools down we admit exactly ONE probe; this guards against
  // concurrent calls all slipping through the half-open window at once.
  private halfOpenProbeInFlight = false;

  constructor(opts: RazorpayCallConfig = {}) {
    this.keyId = requireEnv('RAZORPAY_KEY_ID');
    this.keySecret = requireEnv('RAZORPAY_KEY_SECRET');
    // Dev: empty webhook secret => verifyWebhookSignature always fails closed
    // (webhooks are ignored, payments reconcile via polling). Prod: that same
    // silent failure would drop EVERY capture webhook with no error anywhere,
    // so refuse to boot instead — a half-configured gateway is a money bug,
    // not a degraded mode.
    this.webhookSecret = envOr('RAZORPAY_WEBHOOK_SECRET', '');
    if (!this.webhookSecret && process.env.NODE_ENV === 'production') {
      throw new Error(
        'RAZORPAY_WEBHOOK_SECRET is required in production when Razorpay keys are configured',
      );
    }
    this.cfg = {
      // Clamp to ≥1 so a degenerate config can't make the loop a no-op that
      // throws an undefined `lastErr`.
      maxRetries: Math.max(1, opts.maxRetries ?? 3),
      retryBaseMs: opts.retryBaseMs ?? 200,
      jitter: opts.jitter ?? true,
      circuitThreshold: opts.circuitThreshold ?? 5,
      circuitWindowMs: opts.circuitWindowMs ?? 60_000,
      circuitCooldownMs: opts.circuitCooldownMs ?? 30_000,
    };
  }

  private authHeader(): string {
    const token = Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64');
    return `Basic ${token}`;
  }

  // ── Circuit breaker ────────────────────────────────────────────────────
  private recordTransientFailure(): void {
    const now = Date.now();
    this.halfOpenProbeInFlight = false;
    // A failed half-open probe means the upstream is still down → re-open and
    // restart the cooldown (the original bug: this only handled CLOSED→OPEN, so
    // a probe failure left it HALF_OPEN forever and the gate stopped protecting).
    if (this.circuitState === 'HALF_OPEN') {
      this.circuitState = 'OPEN';
      this.circuitOpenedAt = now;
      return;
    }
    this.failureTimestamps.push(now);
    this.failureTimestamps = this.failureTimestamps.filter(
      (t) => now - t < this.cfg.circuitWindowMs,
    );
    if (
      this.failureTimestamps.length >= this.cfg.circuitThreshold &&
      this.circuitState === 'CLOSED'
    ) {
      this.circuitState = 'OPEN';
      this.circuitOpenedAt = now;
    }
  }

  /** The upstream responded (success, or a permanent 4xx — it's alive either
   *  way). Closes a half-open probe and clears the failure window. */
  private recordUpstreamResponsive(): void {
    this.halfOpenProbeInFlight = false;
    if (this.circuitState === 'HALF_OPEN') {
      this.circuitState = 'CLOSED';
    }
    this.failureTimestamps = [];
  }

  private canProceed(): boolean {
    if (this.circuitState === 'CLOSED') return true;
    // OPEN or HALF_OPEN. Admit at most one probe at a time.
    if (this.halfOpenProbeInFlight) return false;
    if (Date.now() - this.circuitOpenedAt >= this.cfg.circuitCooldownMs) {
      this.circuitState = 'HALF_OPEN';
      this.halfOpenProbeInFlight = true; // exactly one probe through
      return true;
    }
    return false;
  }

  /**
   * Transient = worth retrying / counts toward the breaker. By the time rawCall
   * has mapped the upstream status: 429 (rate limit) and 502 (real 5xx) are
   * transient; a network error throws with no status (also transient). 400/401/
   * 402 and the catch-all 500 are permanent client/config errors.
   */
  private isTransient(status: number | undefined): boolean {
    return status === undefined || status === 429 || status === 502;
  }

  /**
   * Wrap a Razorpay call with retry + circuit breaker. The idempotency split is
   * the load-bearing correctness rule (vs tutorix, which retries everything and
   * leans on fetch-before-create to clean up): RETRYING A NON-IDEMPOTENT POST
   * ON AN AMBIGUOUS 5xx/NETWORK COULD DOUBLE-ACT (e.g. create two transfers).
   * So idempotent calls (GET/PATCH) retry on any transient error; non-idempotent
   * POSTs retry ONLY on 429 (rate-limited ⇒ definitely not processed) and
   * otherwise fail fast, letting reconciliation's fetch-before-create heal it.
   */
  private async call<T>(
    method: 'GET' | 'POST' | 'PATCH',
    path: string,
    body?: unknown,
    opts?: { idempotent?: boolean },
  ): Promise<T> {
    // GET/PATCH are idempotent; POST is not, unless a caller overrides.
    const idempotent = opts?.idempotent ?? (method === 'GET' || method === 'PATCH');

    let lastErr: unknown;
    for (let attempt = 0; attempt < this.cfg.maxRetries; attempt++) {
      if (!this.canProceed()) {
        throw Object.assign(
          new Error('Razorpay temporarily unavailable — circuit breaker open'),
          { status: 503 },
        );
      }
      try {
        const result = await this.rawCall<T>(method, path, body);
        this.recordUpstreamResponsive();
        return result;
      } catch (err) {
        lastErr = err;
        const status = (err as { status?: number }).status;
        if (!this.isTransient(status)) {
          // Permanent 4xx — upstream responded, so it's alive (closes a probe);
          // don't retry a client/config error that won't self-correct.
          this.recordUpstreamResponsive();
          throw err;
        }
        // Transient. Idempotent calls retry on any transient; non-idempotent
        // POSTs only on 429 (rate-limited ⇒ definitely not processed) so an
        // ambiguous 5xx/network can't double-act — reconciliation heals those.
        const retryable = idempotent ? true : status === 429;
        if (retryable && attempt < this.cfg.maxRetries - 1) {
          await this.backoff(attempt);
          continue;
        }
        this.recordTransientFailure();
        throw err;
      }
    }
    throw lastErr; // unreachable (loop always returns/throws), kept for types
  }

  private async backoff(attempt: number): Promise<void> {
    const base = this.cfg.retryBaseMs * Math.pow(2, attempt);
    const delay = this.cfg.jitter ? base + Math.random() * 50 : base;
    if (delay > 0) await new Promise((r) => setTimeout(r, delay));
  }

  /** One raw HTTP call to Razorpay + status classification (no retry). */
  private async rawCall<T>(
    method: 'GET' | 'POST' | 'PATCH',
    path: string,
    body?: unknown,
  ): Promise<T> {
    // Absolute paths (e.g. the /v2 Accounts API) pass through; relative paths
    // are resolved against the /v1 base.
    const url = path.startsWith('http') ? path : `${RAZORPAY_API}${path}`;
    const res = await fetch(url, {
      method,
      headers: {
        Authorization: this.authHeader(),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const text = await res.text();
    let json: unknown;
    try {
      json = text ? JSON.parse(text) : {};
    } catch {
      json = { raw: text };
    }
    if (!res.ok) {
      const desc =
        (json as { error?: { description?: string } })?.error?.description ??
        `Razorpay ${method} ${path} failed (${res.status})`;
      // Preserve enough of the upstream status for callers to classify:
      //  400 bad request, 401 auth (permanent config fix), 402 insufficient
      //  balance (not retryable — surface for reconciliation), 429 rate limit
      //  (caller backoff), 5xx → 502 transient, other 4xx → 500.
      const status =
        res.status === 400
          ? 400
          : res.status === 401
            ? 401
            : res.status === 402
              ? 402
              : res.status === 429
                ? 429
                : res.status >= 500
                  ? 502
                  : 500;
      throw Object.assign(new Error(desc), { status });
    }
    return json as T;
  }

  buildClientParams(p: {
    providerOrderRef: string;
    amountMinor: number;
    currency: string;
  }): Record<string, unknown> {
    // What the Razorpay Checkout SDK (web/Flutter) needs to open the sheet.
    return {
      key: this.keyId,
      order_id: p.providerOrderRef,
      amount: p.amountMinor,
      currency: p.currency,
    };
  }

  async createSession(p: CreateSessionParams): Promise<GatewaySession> {
    const order = await this.call<{ id: string }>('POST', '/orders', {
      amount: p.amountMinor,
      currency: p.currency,
      receipt: p.intentRef,
      notes: p.notes ?? {},
    });
    return {
      providerOrderRef: order.id,
      clientParams: this.buildClientParams({
        providerOrderRef: order.id,
        amountMinor: p.amountMinor,
        currency: p.currency,
      }),
    };
  }

  verifyHandshake(p: HandshakeParams): boolean {
    // Razorpay handshake: HMAC(order_id|payment_id, keySecret).
    const expected = hmacSha256Hex(
      this.keySecret,
      `${p.providerOrderRef}|${p.providerPaymentRef}`,
    );
    return timingSafeEqualHex(expected, p.signature);
  }

  verifyWebhookSignature(rawBody: Buffer, headers: HeaderBag): boolean {
    if (!this.webhookSecret) return false; // fail closed if unconfigured
    const signature = headerValue(headers, 'x-razorpay-signature');
    if (!signature) return false;
    const expected = hmacSha256Hex(this.webhookSecret, rawBody);
    return timingSafeEqualHex(expected, signature);
  }

  parseWebhookEvent(rawBody: Buffer, headers: HeaderBag): NormalizedEvent {
    let payload: {
      event?: string;
      payload?: {
        payment?: { entity?: { id?: string; order_id?: string; amount?: number; currency?: string } };
        order?: { entity?: { id?: string; amount?: number; currency?: string } };
        refund?: { entity?: { id?: string; payment_id?: string; amount?: number; currency?: string } };
        qr_code?: { entity?: { id?: string } };
        transfer?: {
          entity?: { id?: string; status?: string; amount_reversed?: number; on_hold?: boolean };
        };
        account?: { entity?: { id?: string; status?: string } };
        dispute?: { entity?: { id?: string; payment_id?: string; status?: string } };
      };
    };
    try {
      payload = JSON.parse(rawBody.toString('utf8'));
    } catch (err) {
      // Malformed body is a permanent client error → 400 so the webhook is
      // acked (not retried forever) on a shared account.
      throw Object.assign(
        new Error(`Invalid webhook JSON: ${err instanceof Error ? err.message : 'parse error'}`),
        { status: 400 },
      );
    }
    const event = payload.event ?? '';
    let type = mapEventType(event);
    const payEntity = payload.payload?.payment?.entity;
    const orderEntity = payload.payload?.order?.entity;
    const refundEntity = payload.payload?.refund?.entity;
    const qrEntity = payload.payload?.qr_code?.entity;
    const transferEntity = payload.payload?.transfer?.entity;
    const accountEntity = payload.payload?.account?.entity;
    const disputeEntity = payload.payload?.dispute?.entity;

    // A lost dispute can arrive as `payment.dispute.lost` OR as
    // `payment.dispute.closed` with the entity status `lost` — treat both as the
    // clawback trigger so the platform isn't silently left eating a chargeback.
    if (disputeEntity?.status === 'lost' && type === 'DISPUTE_OTHER') {
      type = 'DISPUTE_LOST';
    }

    // Razorpay's per-delivery event id header is the dedupe key.
    const eventId =
      headerValue(headers, 'x-razorpay-event-id') ??
      // Fallback: an entity id + event name (still stable per delivery).
      `${payEntity?.id ?? refundEntity?.id ?? orderEntity?.id ?? qrEntity?.id ?? transferEntity?.id ?? accountEntity?.id ?? disputeEntity?.id ?? 'unknown'}:${event}`;

    return {
      type,
      eventId,
      // A UPI-QR payment has no order; the intent stores the QR id as its order
      // ref, so resolve ownership by the QR id first (a regular payment still
      // resolves by its order_id).
      providerOrderRef: qrEntity?.id ?? payEntity?.order_id ?? orderEntity?.id ?? null,
      // dispute events carry the disputed payment id on the dispute entity.
      providerPaymentRef:
        payEntity?.id ?? refundEntity?.payment_id ?? disputeEntity?.payment_id ?? null,
      amountMinor: payEntity?.amount ?? orderEntity?.amount ?? refundEntity?.amount ?? null,
      currency: payEntity?.currency ?? orderEntity?.currency ?? refundEntity?.currency ?? null,
      ...(transferEntity?.id
        ? {
            transfer: {
              ref: transferEntity.id,
              status: transferEntity.status ?? 'unknown',
              amountReversedMinor: transferEntity.amount_reversed ?? 0,
              onHold: !!transferEntity.on_hold,
            },
          }
        : {}),
      ...(accountEntity?.id
        ? { account: { ref: accountEntity.id, status: accountEntity.status ?? 'unknown' } }
        : {}),
      ...(type === 'DISPUTE_LOST' || type === 'DISPUTE_OTHER'
        ? {
            dispute: {
              ref: disputeEntity?.id ?? 'unknown',
              providerPaymentRef: disputeEntity?.payment_id ?? payEntity?.id ?? null,
            },
          }
        : {}),
      raw: payload,
    };
  }

  async fetchOrderStatus(providerOrderRef: string): Promise<NormalizedOrderStatus> {
    // A POS UPI-QR intent stores the QR id (qr_XXXX) as its order ref — it has no
    // Razorpay order. Route those through the QR payments endpoint so the generic
    // reconciliation sweep heals a missed `qr_code.credited` with no special-casing.
    if (providerOrderRef.startsWith('qr_')) {
      return this.fetchQrOrderStatus(providerOrderRef);
    }
    // GET /orders/:id → { status: 'created'|'attempted'|'paid', amount_paid }.
    const order = await this.call<{ status: string; amount_paid?: number }>(
      'GET',
      `/orders/${providerOrderRef}`,
    );
    let capturedPaymentRef: string | null = null;
    if (order.status === 'paid') {
      // Find the payment that actually settled so we can record its ref.
      const pays = await this.call<{ items?: Array<{ id: string; status: string }> }>(
        'GET',
        `/orders/${providerOrderRef}/payments`,
      );
      const items = pays.items ?? [];
      const cap =
        items.find((p) => p.status === 'captured') ??
        items.find((p) => p.status === 'authorized');
      capturedPaymentRef = cap?.id ?? null;
    }
    const status =
      order.status === 'paid' ? 'PAID' : order.status === 'attempted' ? 'ATTEMPTED' : 'CREATED';
    return { status, amountPaidMinor: order.amount_paid ?? 0, capturedPaymentRef };
  }

  async fetchPaymentStatus(providerPaymentRef: string): Promise<NormalizedStatus> {
    const pay = await this.call<{ status: string; amount: number; currency: string; id: string }>(
      'GET',
      `/payments/${providerPaymentRef}`,
    );
    return {
      status: mapPaymentStatus(pay.status),
      amountMinor: pay.amount,
      currency: pay.currency,
      providerPaymentRef: pay.id,
    };
  }

  async refund(p: RefundParams): Promise<NormalizedRefund> {
    const refund = await this.call<{ id: string; amount: number; status: string }>(
      'POST',
      `/payments/${p.providerPaymentRef}/refund`,
      {
        amount: p.amountMinor,
        ...(p.idempotencyKey ? { receipt: p.idempotencyKey } : {}),
        ...(p.notes ? { notes: p.notes } : {}),
      },
    );
    const status =
      refund.status === 'processed'
        ? 'PROCESSED'
        : refund.status === 'failed'
          ? 'FAILED'
          : 'PENDING';
    return { providerRefundRef: refund.id, amountMinor: refund.amount, status };
  }

  // ── SplitCapablePort: marketplace split + on-hold settlement (Razorpay Route) ─
  //
  // Terminology: this is NOT a licensed escrow arrangement and we never call it
  // one in product-facing copy. It is Razorpay Route's `on_hold` flag. A transfer
  // created with `on_hold: true` parks the seller's share in RAZORPAY's
  // settlement balance (a regulated PA holding the funds — not us, not our
  // account) past the normal settlement schedule, until we either release it
  // (PATCH on_hold:false) or reverse it (in-hold return/refund). Razorpay is the
  // custodian throughout; the platform is a facilitator.
  //
  // Edge cases enforced/relevant here (from the Route docs):
  //  - amount ≥ ₹1 (100 paise); INR only.
  //  - `on_hold_until` must be a unix ts within Razorpay's accepted bounds;
  //    omit it for an indefinite hold released explicitly by your flow.
  //  - A transfer CANNOT be created on a payment once a refund is initiated —
  //    so split BEFORE refunding (the caller/settlement layer must order this).
  //  - Reversal moves funds Linked Account → platform; only the platform can
  //    initiate it; partial + multiple reversals are allowed. A reversal can
  //    fail if the linked account lacks balance (already settled/withdrawn) —
  //    the caller should surface that for manual reconciliation.

  /**
   * Create transfers (splits) on a payment for marketplace settlement.
   * IMPORTANT: the payment must have no initiated refunds — Razorpay enforces
   * this server-side and rejects with a 400. Callers MUST order transfers
   * BEFORE refunds.
   * @throws {Error & { status: 400 }} if validation fails or Razorpay rejects
   */
  async createTransfers(
    providerPaymentRef: string,
    transfers: TransferRequest[],
  ): Promise<TransferResult[]> {
    // Validate the whole batch upfront so a failure names the offending index
    // (the .map() payload build below is then guaranteed exception-free).
    const errors: { index: number; field: string; message: string }[] = [];
    for (let i = 0; i < transfers.length; i++) {
      const t = transfers[i];
      if (t.amountMinor < MIN_TRANSFER_PAISE) {
        errors.push({
          index: i,
          field: 'amountMinor',
          message: `amount must be ≥ ₹1 (got ${t.amountMinor} paise)`,
        });
      }
      if (
        t.onHoldUntil != null &&
        (t.onHoldUntil < ON_HOLD_UNTIL_MIN || t.onHoldUntil > ON_HOLD_UNTIL_MAX)
      ) {
        errors.push({
          index: i,
          field: 'onHoldUntil',
          message: `must be within ${ON_HOLD_UNTIL_MIN}-${ON_HOLD_UNTIL_MAX} (got ${t.onHoldUntil})`,
        });
      }
    }
    if (errors.length > 0) {
      const summary = errors
        .map((e) => `transfers[${e.index}].${e.field}: ${e.message}`)
        .join('; ');
      throw Object.assign(new Error(`Transfer validation failed: ${summary}`), {
        status: 400,
        errors,
      });
    }

    const payload = {
      transfers: transfers.map((t) => ({
        account: t.destinationAccount,
        amount: t.amountMinor,
        currency: 'INR',
        ...(t.onHold != null ? { on_hold: t.onHold } : {}),
        ...(t.onHoldUntil != null ? { on_hold_until: t.onHoldUntil } : {}),
        ...(t.notes ? { notes: t.notes } : {}),
      })),
    };
    try {
      const res = await this.call<{
        items?: Array<{ id: string; recipient: string; amount: number; on_hold: boolean }>;
      }>('POST', `/payments/${providerPaymentRef}/transfers`, payload);
      return (res.items ?? []).map((it) => ({
        transferRef: it.id,
        destinationAccount: it.recipient,
        amountMinor: it.amount,
        onHold: !!it.on_hold,
      }));
    } catch (err) {
      // Surface the transfer-before-refund ordering violation with a clear
      // domain message (Razorpay rejects transfers on refunded payments w/ 400).
      const e = err as { status?: number; message?: string };
      if (
        e?.status === 400 &&
        typeof e.message === 'string' &&
        (e.message.includes('refund') || e.message.includes('transfer'))
      ) {
        throw Object.assign(
          new Error(
            `Cannot create transfer: payment may have an initiated refund. ` +
              `Transfers must be created BEFORE refunds. Original error: ${e.message}`,
          ),
          { status: 400 },
        );
      }
      throw err;
    }
  }

  /**
   * Fetch-before-create idempotency: list the transfers already created on a
   * payment. A retried split (or a reconciliation heal of a null-ref row) calls
   * this first and matches each existing transfer to its row via the
   * deterministic key we stamp into `notes` — so it reconciles instead of
   * minting a duplicate transfer that would double-pay the seller.
   */
  async listTransfers(providerPaymentRef: string): Promise<ExistingTransfer[]> {
    const res = await this.call<{
      items?: Array<{
        id: string;
        recipient: string;
        amount: number;
        on_hold: boolean;
        status?: string;
        amount_reversed?: number;
        notes?: Record<string, string> | string[];
      }>;
    }>('GET', `/payments/${providerPaymentRef}/transfers`);
    return (res.items ?? []).map((it) => ({
      transferRef: it.id,
      destinationAccount: it.recipient,
      amountMinor: it.amount,
      onHold: !!it.on_hold,
      // status/amount_reversed drive HELD↔RELEASED↔REVERSED reconciliation.
      status: it.status ?? 'unknown',
      amountReversedMinor: it.amount_reversed ?? 0,
      // Razorpay returns notes as an object; normalise the rare array form to {}.
      notes: Array.isArray(it.notes) ? {} : (it.notes ?? {}),
    }));
  }

  async releaseTransfer(transferRef: string): Promise<void> {
    // Modify settlement hold → release. Settles to the linked account by the
    // next working day (subject to the account's settlement schedule).
    await this.call('PATCH', `/transfers/${transferRef}`, { on_hold: false });
  }

  async reverseTransfer(transferRef: string, amountMinor?: number): Promise<void> {
    if (amountMinor != null && amountMinor < MIN_TRANSFER_PAISE) {
      throw Object.assign(new Error('Reversal amount must be ≥ ₹1'), { status: 400 });
    }
    // Omit amount for a full reversal; pass it for a partial one.
    const body = amountMinor != null ? { amount: amountMinor } : {};
    await this.call('POST', `/transfers/${transferRef}/reversals`, body);
  }

  // ── OnboardingCapablePort: linked-account KYC (Razorpay Accounts /v2) ──────
  //
  // Creates a Route linked account (a payout destination). KYC activation is
  // asynchronous: the create returns status 'created'; the account becomes
  // settle-able only once Razorpay finishes verification, surfaced via the
  // account.* webhooks and fetchAccountStatus. We submit the full identity
  // Razorpay needs for a submittable account: business identity, profile
  // (category + registered address) and legal_info (PAN, optional GST). Any
  // residual document KYC the merchant completes via Razorpay's hosted flow.

  async createLinkedAccount(p: CreateLinkedAccountParams): Promise<LinkedAccountResult> {
    // Step 1 — create the linked account (identity + profile + legal_info).
    // legal_info carries PAN/GST; profile carries category + registered address.
    // Optional fields are omitted (not sent as undefined) so Razorpay validation
    // doesn't choke on empty strings.
    const legalInfo: Record<string, string> = { pan: p.pan };
    if (p.gst) legalInfo.gst = p.gst;

    const registered: Record<string, string> = {
      street1: p.registeredAddress.street1,
      city: p.registeredAddress.city,
      state: p.registeredAddress.state,
      postal_code: p.registeredAddress.postalCode,
      country: p.registeredAddress.country,
    };
    if (p.registeredAddress.street2) registered.street2 = p.registeredAddress.street2;

    const profile: Record<string, unknown> = {
      category: p.category,
      addresses: { registered },
    };
    if (p.subcategory) profile.subcategory = p.subcategory;

    const res = await this.call<{ id: string; status?: string }>(
      'POST',
      `${RAZORPAY_API_V2}/accounts`,
      {
        email: p.email,
        phone: p.phone,
        type: 'route',
        // Deterministic so a retried create maps back to the same shop.
        reference_id: `shop_${p.shopId}`,
        legal_business_name: p.legalBusinessName,
        customer_facing_business_name:
          p.customerFacingBusinessName || p.legalBusinessName,
        business_type: p.businessType,
        contact_name: p.contactName,
        profile,
        legal_info: legalInfo,
        // Tag so a SHARED Razorpay account stays filterable in the dashboard.
        notes: { shopId: String(p.shopId), app: 'shopxy' },
      },
    );
    const accountId = res.id;

    // Step 2 — request the Route product configuration. WITHOUT this the account
    // is just an identity, not a payout destination — no transfers can settle to
    // it. Returns a product-config id we then attach the bank account to.
    // (Verify the exact /v2/accounts product+settlements contract against the
    // current Razorpay docs in sandbox before enabling — same caveat as the rest
    // of this gated feature.)
    const product = await this.call<{ id: string }>(
      'POST',
      `${RAZORPAY_API_V2}/accounts/${accountId}/products`,
      { product_name: 'route', tnc_accepted: true },
    );

    // Step 3 — submit the SETTLEMENT BANK ACCOUNT. This is what ultimately lets
    // the seller be paid out. The bank details flow straight to Razorpay and are
    // never persisted by us.
    await this.call('PATCH', `${RAZORPAY_API_V2}/accounts/${accountId}/products/${product.id}`, {
      settlements: {
        account_number: p.bankAccountNumber,
        ifsc_code: p.bankIfsc,
        beneficiary_name: p.beneficiaryName,
      },
      tnc_accepted: true,
    });

    // payoutsEnabled is derived ONLY from current status (shared mapper) — never
    // a sticky activated_at that would survive a later suspension. The account
    // still has to clear Razorpay KYC before it actually activates.
    return { providerAccountId: accountId, ...mapProviderKyc(res.status ?? 'created') };
  }

  async fetchAccountStatus(providerAccountId: string): Promise<KycState> {
    const res = await this.call<{ status?: string }>(
      'GET',
      `${RAZORPAY_API_V2}/accounts/${providerAccountId}`,
    );
    return mapProviderKyc(res.status ?? 'created');
  }

  /** Fetch identity + status for the connect-an-existing-account flow. A GET on
   *  a non-existent / not-ours account id throws (→ surfaced as NOT_FOUND). */
  async fetchAccount(providerAccountId: string): Promise<{
    accountId: string;
    kycStatus: string;
    payoutsEnabled: boolean;
    email: string | null;
    legalBusinessName: string | null;
    contactName: string | null;
    businessType: string | null;
  }> {
    const res = await this.call<{
      id?: string;
      status?: string;
      email?: string;
      legal_business_name?: string;
      business_type?: string;
      contact_name?: string;
    }>('GET', `${RAZORPAY_API_V2}/accounts/${providerAccountId}`);
    const { kycStatus, payoutsEnabled } = mapProviderKyc(res.status ?? 'created');
    return {
      accountId: res.id ?? providerAccountId,
      kycStatus,
      payoutsEnabled,
      email: res.email ?? null,
      legalBusinessName: res.legal_business_name ?? null,
      contactName: res.contact_name ?? null,
      businessType: res.business_type ?? null,
    };
  }

  // ── QrCapablePort: dynamic UPI QR (Razorpay QR Codes API) ──────────────────
  //
  // A fixed-amount, single-use UPI QR. The customer scans it with any UPI app
  // and pays; Razorpay fires `qr_code.credited` (carrying the captured payment)
  // which the intent webhook path settles. The QR id is what the intent stores
  // as its order ref, so the existing ownership lookup resolves it.

  async createPosQr(p: CreatePosQrParams): Promise<PosQrResult> {
    const qr = await this.call<{ id: string; image_url?: string }>('POST', '/payments/qr_codes', {
      type: 'upi_qr',
      // One sale, one QR: a single-use, fixed-amount QR closes itself after the
      // first successful payment so it can't be paid twice.
      usage: 'single_use',
      fixed_amount: true,
      payment_amount: p.amountMinor,
      notes: p.notes ?? {},
    });
    return { qrId: qr.id, imageUrl: qr.image_url ?? '' };
  }

  async fetchQr(qrId: string): Promise<{ imageUrl: string; closed: boolean }> {
    const qr = await this.call<{ image_url?: string; status?: string }>(
      'GET',
      `/payments/qr_codes/${qrId}`,
    );
    return { imageUrl: qr.image_url ?? '', closed: qr.status === 'closed' };
  }

  async closeQr(qrId: string): Promise<void> {
    // Idempotent server-side: closing an already-closed QR is harmless. A 400
    // ("already closed") is swallowed so cancel/abandon never wedges on a QR the
    // first-payment auto-close already retired.
    try {
      await this.call('POST', `/payments/qr_codes/${qrId}/close`, {});
    } catch (err) {
      if ((err as { status?: number }).status === 400) return;
      throw err;
    }
  }

  /** QR-payment liveness for {@link fetchOrderStatus}: list the QR's payments and
   *  report PAID with the captured ref/amount, else CREATED. */
  private async fetchQrOrderStatus(qrId: string): Promise<NormalizedOrderStatus> {
    const res = await this.call<{
      items?: Array<{ id: string; status: string; amount: number }>;
    }>('GET', `/payments/qr_codes/${qrId}/payments`);
    const items = res.items ?? [];
    const cap = items.find((p) => p.status === 'captured') ?? items.find((p) => p.status === 'authorized');
    if (cap) {
      return { status: 'PAID', amountPaidMinor: cap.amount, capturedPaymentRef: cap.id };
    }
    return { status: 'CREATED', amountPaidMinor: 0, capturedPaymentRef: null };
  }
}
