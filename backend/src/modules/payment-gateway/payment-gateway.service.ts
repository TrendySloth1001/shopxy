/**
 * Core, provider-agnostic orchestration. Knows nothing about Razorpay or about
 * the wallet/order/invoice domain — it wires the registry (which gateway), the
 * repository (persistence), and the settlement bridge (which domain) together.
 *
 * Two entry points:
 *   initiatePayment — create an intent + a checkout session for the client.
 *   handleWebhook   — verify, dedupe, transition, settle (source of truth).
 */
import type {
  GatewayPaymentRepository,
  GatewayRefundRepository,
  WebhookEventRepository,
} from './ports/repository.port.js';
import type { HeaderBag } from './ports/payment-provider.port.js';
import { isQrCapable } from './ports/payment-provider.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  GatewayRefundRecord,
  NormalizedEvent,
  NormalizedOrderStatus,
  SettlementTarget,
  SettlementTargetType,
} from './ports/types.js';
import { getProvider } from './providers/registry.js';
import { settlementFor } from './settlement/settlement.js';
import {
  isSettlementEvent,
  ownsSettlementEvent,
  handleSettlementEvent,
} from './settlement/webhook-handlers.js';
import { toMinorUnits } from './helpers.js';
import { tracker } from './tracker.js';
import prisma from '../../infra/db/prisma.js';
import { round2 } from '../../shared/numbering/decimal.js';

/**
 * Signals that the target is already paid — the caller must NOT reopen the
 * checkout sheet (doing so wedges Razorpay). status 409 + code for the API.
 */
function alreadyPaidError(): Error & { status: number; code: string } {
  return Object.assign(new Error('This order is already paid'), {
    status: 409,
    code: 'ALREADY_PAID',
  });
}

export interface InitiateInput {
  provider: string;
  target: SettlementTarget;
  amount: number;
  currency?: string;
  shopId: number | null;
  customerUserId: number | null;
  idempotencyKey: string | null;
}

export interface InitiateResult {
  intentId: number;
  provider: string;
  providerOrderRef: string;
  amount: number;
  currency: string;
  clientParams: Record<string, unknown>;
  reused: boolean;
}

/** Per-tick outcome of the intent-reconciliation sweep (logged + returned). */
export interface ReconcileSummary {
  /** Open intents fetched this tick (≤ batchSize). */
  scanned: number;
  /** Provider reported PAID → marked CAPTURED + settled (missed-webhook heal). */
  captured: number;
  /** Past the abandon window and confirmed unpaid → marked FAILED. */
  abandoned: number;
  /** Not paid yet but within the window → left for a later tick. */
  stillOpen: number;
  /** Per-intent failures (provider down, amount mismatch…); intent left open. */
  errors: number;
}

/** What the caller asks the engine to refund to source. */
export interface RefundToSourceInput {
  /** Which captured payment to reverse against (ORDER → CustomerOrder id…). */
  targetType: SettlementTargetType;
  targetId: number;
  /** Rupees to return to the original instrument. Capped at what's left of the
   *  capture (amount − already-refunded); a value above that is clamped, never
   *  rejected, so a rounding overshoot can't strand a legitimate refund. */
  amount: number;
  /** Domain trigger, for the audit trail + idempotency namespace. */
  sourceType: 'RETURN' | 'CANCEL';
  sourceId: number;
  /** Deterministic dedupe key. A retried trigger re-uses the same refund. */
  idempotencyKey: string;
  reason?: string;
  /** Carried into the provider's notes (filterable in the dashboard). */
  notes?: Record<string, string>;
}

/**
 * Outcome of a refund-to-source attempt. Discriminated so a caller can tell a
 * real money movement (`REFUNDED`) from the legitimate "nothing online to
 * refund" cases (`NO_PAYMENT` = COD/never-captured; `NOTHING_TO_REFUND` =
 * already fully reversed) without treating them as errors.
 */
export type RefundToSourceResult =
  | { status: 'REFUNDED'; refund: GatewayRefundRecord }
  | { status: 'FAILED'; refund: GatewayRefundRecord }
  | { status: 'NO_PAYMENT' }
  | { status: 'NOTHING_TO_REFUND' };

/** Per-tick outcome of the refund-reconciliation sweep. */
export interface RefundReconcileSummary {
  /** Non-terminal refunds fetched this tick (≤ batchSize). */
  scanned: number;
  /** PENDING refunds the provider confirmed PROCESSED (missed-webhook heal). */
  processed: number;
  /** FAILED refunds successfully re-issued (now PENDING/PROCESSED). */
  redriven: number;
  /** Still in flight at the provider — left for a later tick. */
  stillPending: number;
  /** FAILED past the give-up window — left for manual handling. */
  gaveUp: number;
  /** Per-refund failures (provider down, still rejecting); left for next tick. */
  errors: number;
}

export class PaymentGatewayService {
  constructor(
    private readonly repo: GatewayPaymentRepository,
    private readonly events: WebhookEventRepository,
    private readonly refunds: GatewayRefundRepository,
  ) {}

  /**
   * Refund real money back to the customer's original payment instrument.
   *
   * This is the LEGALLY-REQUIRED settlement for a return/cancellation of an
   * online (card/UPI/netbanking) payment: the money goes back to source, never
   * into wallet/store credit (RBI "refund to source"; Consumer Protection
   * (E-Commerce) Rules 2020, Rule 4(7)). Wallet credit as a refund vehicle has
   * been removed — this method is the only refund path.
   *
   * Flow (idempotent + crash-safe):
   *   1. Replay: a GatewayRefund already exists for this idempotency key →
   *      return it (no second provider call).
   *   2. Resolve the CAPTURED payment for (targetType, targetId). None → the
   *      order was COD / never captured online → NO_PAYMENT (caller skips).
   *   3. Cap the amount at (capture.amount − capture.amountRefunded). ≤0 →
   *      NOTHING_TO_REFUND (already fully reversed).
   *   4. Call the provider's refund API (external — NOT inside a DB tx).
   *   5. In one tx: write the GatewayRefund row and bump the capture's
   *      amount_refunded (flipping it to REFUNDED once fully reversed).
   *
   * Never silently swallows: a provider rejection is persisted as a FAILED
   * refund row and returned as `{ status: 'FAILED' }` so the caller/ops can act.
   */
  async refundToSource(input: RefundToSourceInput): Promise<RefundToSourceResult> {
    // (1) Idempotent replay — a retried return/cancel must not double-refund.
    const prior = await this.refunds.findByIdempotencyKey(input.idempotencyKey);
    if (prior) {
      tracker.track({
        step: 'REFUND_REPLAYED',
        provider: prior.provider,
        meta: { idempotencyKey: input.idempotencyKey, status: prior.status },
      });
      return prior.status === 'FAILED'
        ? { status: 'FAILED', refund: prior }
        : { status: 'REFUNDED', refund: prior };
    }

    // (2) The captured online payment to reverse against.
    const capture = await this.repo.findCapturedByTarget(input.targetType, input.targetId);
    if (!capture || !capture.providerPaymentRef) {
      tracker.track({
        step: 'REFUND_SKIPPED',
        meta: {
          targetType: input.targetType,
          targetId: input.targetId,
          reason: 'no captured online payment (COD / wallet / never captured)',
        },
      });
      return { status: 'NO_PAYMENT' };
    }

    // (3) Cap at what's left of the capture. Clamp (don't reject) an overshoot.
    const refundable = round2(capture.amount - capture.amountRefunded);
    const amount = round2(Math.min(input.amount, refundable));
    if (!(amount > 0)) {
      tracker.track({
        step: 'REFUND_SKIPPED',
        provider: capture.provider,
        intentId: capture.id,
        meta: { reason: 'nothing left to refund', refundable, requested: input.amount },
      });
      return { status: 'NOTHING_TO_REFUND' };
    }

    // (4) External provider call — outside any DB tx so a crash can't hold the
    // tx open or leave money moved against an uncommitted row.
    const provider = getProvider(capture.provider);
    let providerRefundRef: string | null = null;
    let providerStatus: GatewayRefundRecord['status'] = 'PENDING';
    let failed = false;
    try {
      const res = await provider.refund({
        providerPaymentRef: capture.providerPaymentRef,
        amountMinor: toMinorUnits(amount),
        idempotencyKey: input.idempotencyKey,
        notes: {
          app: 'shopxy',
          sourceType: input.sourceType,
          sourceId: String(input.sourceId),
          ...(input.notes ?? {}),
        },
      });
      providerRefundRef = res.providerRefundRef;
      providerStatus = res.status; // PENDING | PROCESSED (FAILED handled below)
      failed = res.status === 'FAILED';
    } catch (err) {
      // Provider rejected (e.g. payment already fully refunded on their side,
      // network, validation). Persist a FAILED row for the audit trail + ops.
      failed = true;
      tracker.track({
        step: 'REFUND_FAILED',
        provider: capture.provider,
        intentId: capture.id,
        meta: { error: err instanceof Error ? err.message : 'unknown', amount },
      });
    }

    // (5) Record the refund + advance the capture's cap, atomically. A FAILED
    // refund records the row (audit) but does NOT consume any refundable amount.
    const fullyRefunded = !failed && round2(capture.amountRefunded + amount) >= capture.amount;
    const refund = await prisma.$transaction(async (tx) => {
      const row = await this.refunds.create(
        {
          gatewayPaymentId: capture.id,
          provider: capture.provider,
          amount,
          currency: capture.currency,
          status: failed ? 'FAILED' : providerStatus,
          providerRefundRef,
          sourceType: input.sourceType,
          sourceId: input.sourceId,
          reason: input.reason ?? null,
          idempotencyKey: input.idempotencyKey,
        },
        tx,
      );
      if (!failed) {
        await this.repo.addRefundedAmount(capture.id, amount, fullyRefunded, tx);
      }
      return row;
    });

    tracker.track({
      step: failed ? 'REFUND_FAILED' : 'REFUND_ISSUED',
      provider: capture.provider,
      intentId: capture.id,
      meta: {
        refundId: refund.id,
        providerRefundRef,
        amount,
        status: refund.status,
        fullyRefunded,
      },
    });
    return failed ? { status: 'FAILED', refund } : { status: 'REFUNDED', refund };
  }

  /**
   * Refund-reconciliation sweep — the liveness net that makes a legally-required
   * refund ALWAYS eventually settle, even when the happy path stalls:
   *   • a PENDING refund whose `refund.processed` webhook was missed (localhost
   *     dev; a dropped/delayed delivery in prod) → re-fetch from the provider
   *     and confirm PROCESSED, or release + fail it if the provider rejected it.
   *   • a FAILED refund (provider rejected, or our process crashed between the
   *     provider call and the DB write) → re-issue it. The provider Idempotency-
   *     Key makes the re-issue safe: a refund that actually went through returns
   *     the SAME refund instead of paying the customer twice.
   *
   * Without this, a return whose refund failed once would never be retried (the
   * return's state machine blocks re-triggering), leaving the buyer un-refunded
   * — a breach of the auto-refund obligation (Consumer Protection (E-Commerce)
   * Rules 2020, Rule 4(7)). Idempotent, lock-guarded by the scheduler, never
   * throws: a per-row failure is counted and the batch continues.
   */
  async reconcileStaleRefunds(opts?: {
    now?: Date;
    /** Only touch refunds untouched for this long — give the webhook a chance. */
    recheckAfterMs?: number;
    /** Stop re-driving a FAILED refund older than this; leave it for manual. */
    giveUpAfterMs?: number;
    batchSize?: number;
  }): Promise<RefundReconcileSummary> {
    const now = opts?.now ?? new Date();
    const recheckAfterMs = opts?.recheckAfterMs ?? 10 * 60_000; // 10 min
    const giveUpAfterMs = opts?.giveUpAfterMs ?? 7 * 24 * 60 * 60_000; // 7 days
    const batchSize = opts?.batchSize ?? 50;

    const recheckBefore = new Date(now.getTime() - recheckAfterMs);
    const giveUpBefore = new Date(now.getTime() - giveUpAfterMs);

    const stale = await this.refunds.findStaleForReconcile({
      updatedBefore: recheckBefore,
      limit: batchSize,
    });
    const summary: RefundReconcileSummary = {
      scanned: stale.length,
      processed: 0,
      redriven: 0,
      stillPending: 0,
      gaveUp: 0,
      errors: 0,
    };

    for (const row of stale) {
      try {
        const capture = await this.repo.findById(row.gatewayPaymentId);
        if (!capture || !capture.providerPaymentRef) {
          // Orphaned refund (capture vanished) — can't act; surface and skip.
          summary.errors++;
          continue;
        }
        const provider = getProvider(row.provider);

        if (row.status === 'PENDING' && row.providerRefundRef) {
          // Heal a missed webhook: ask the provider for the live refund status.
          const live = await provider.fetchRefundStatus(row.providerRefundRef);
          if (live.status === 'PROCESSED') {
            await this.refunds.update(row.id, { status: 'PROCESSED' });
            summary.processed++;
          } else if (live.status === 'FAILED') {
            // A PENDING row had RESERVED the cap at create. The provider now
            // says it failed → release the reservation and mark FAILED so a
            // later tick re-drives it (re-reserving only on success).
            await this.releaseAndFail(row, capture);
            summary.errors++;
          } else {
            summary.stillPending++;
          }
          continue;
        }

        // FAILED (or a stuck PENDING with no provider ref) → re-issue. Bounded:
        // past the give-up window we stop auto-retrying and leave it for ops.
        if (row.createdAt < giveUpBefore) {
          summary.gaveUp++;
          continue;
        }
        const ok = await this.redriveRefund(row, capture);
        if (ok) summary.redriven++;
        else summary.errors++;
      } catch (err) {
        summary.errors++;
        tracker.track({
          step: 'REFUND_FAILED',
          provider: row.provider,
          meta: {
            phase: 'reconcile-sweep',
            refundId: row.id,
            error: err instanceof Error ? err.message : 'unknown',
          },
        });
      }
    }

    tracker.track({ step: 'REFUND_RECONCILE_SWEEP', meta: { ...summary } });
    return summary;
  }

  /**
   * Re-issue a refund that has not settled (a FAILED row that never reserved the
   * cap, or a stuck PENDING with no provider ref that DID reserve it). The
   * provider Idempotency-Key dedupes, so re-calling cannot double-pay. On success
   * we reserve the cap ONLY if this row hadn't already (FAILED hadn't; PENDING
   * had). Returns true when the refund is now in flight / settled.
   */
  private async redriveRefund(
    row: GatewayRefundRecord,
    capture: GatewayPaymentRecord,
  ): Promise<boolean> {
    const alreadyReserved = row.status !== 'FAILED'; // PENDING reserved at create
    const provider = getProvider(row.provider);
    const res = await provider.refund({
      providerPaymentRef: capture.providerPaymentRef!,
      amountMinor: toMinorUnits(row.amount),
      idempotencyKey: row.idempotencyKey,
      notes: {
        app: 'shopxy',
        sourceType: row.sourceType,
        sourceId: String(row.sourceId),
        redrive: 'true',
      },
    });

    if (res.status === 'FAILED') {
      // Still failing. If it had reserved the cap (PENDING), release it.
      if (alreadyReserved) {
        await this.releaseAndFail(row, capture);
      } else {
        await this.refunds.update(row.id, {
          status: 'FAILED',
          ...(res.providerRefundRef ? { providerRefundRef: res.providerRefundRef } : {}),
        });
      }
      return false;
    }

    // Accepted (PENDING) or settled (PROCESSED). Record the ref + status, and
    // reserve the cap iff this row hadn't reserved it yet.
    const fullyRefunded =
      !alreadyReserved && round2(capture.amountRefunded + row.amount) >= capture.amount;
    await prisma.$transaction(async (tx) => {
      await this.refunds.update(
        row.id,
        {
          status: res.status,
          ...(res.providerRefundRef ? { providerRefundRef: res.providerRefundRef } : {}),
        },
        tx,
      );
      if (!alreadyReserved) {
        await this.repo.addRefundedAmount(capture.id, row.amount, fullyRefunded, tx);
      }
    });
    tracker.track({
      step: 'REFUND_REDRIVEN',
      provider: row.provider,
      intentId: capture.id,
      meta: { refundId: row.id, status: res.status, providerRefundRef: res.providerRefundRef },
    });
    return true;
  }

  /** Mark a reserved (PENDING) refund FAILED and release the cap it held. */
  private async releaseAndFail(
    row: GatewayRefundRecord,
    capture: GatewayPaymentRecord,
  ): Promise<void> {
    const stillFully = round2(capture.amountRefunded - row.amount) >= capture.amount;
    await prisma.$transaction(async (tx) => {
      await this.refunds.update(row.id, { status: 'FAILED' }, tx);
      await this.repo.releaseRefundedAmount(capture.id, row.amount, stillFully, tx);
    });
    tracker.track({
      step: 'REFUND_FAILED',
      provider: row.provider,
      intentId: capture.id,
      meta: { refundId: row.id, phase: 'pending-turned-failed; reservation released' },
    });
  }

  /** Create (or replay) an intent and return checkout params for the client. */
  async initiatePayment(input: InitiateInput): Promise<InitiateResult> {
    const provider = getProvider(input.provider);
    const currency = input.currency ?? 'INR';

    // Re-initiate handling. The SAME (customer, key) may map to a prior intent
    // in any state — resuming blindly is what wedged Razorpay's sheet (reopening
    // an already-paid order). Decide per the prior intent's state:
    if (input.idempotencyKey) {
      const existing = await this.repo.findByIdempotencyKey(
        input.customerUserId,
        input.idempotencyKey,
      );
      // Idempotency window: a key only means "the same request retried" for
      // so long. A still-open intent from last week is an abandoned checkout,
      // not a retry — resuming it would reopen a stale provider order at
      // whatever the price was then. Stale open intents are retired (FAILED
      // + key released) and a fresh one is minted — but ONLY after the live
      // provider check below proves the old order wasn't actually paid;
      // expiring a paid-but-unsynced intent would re-charge the customer.
      // Settled intents are NOT expired: "already paid" stays true forever.
      const IDEMPOTENCY_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
      const isStale = (r: { createdAt: Date }) =>
        Date.now() - r.createdAt.getTime() > IDEMPOTENCY_WINDOW_MS;
      // Free the key from a row we've decided not to reuse, so the fresh
      // insert below can't trip the (customerUserId, idempotencyKey) unique.
      const retireExisting = async (r: { id: number; status: string }) => {
        if (r.status === 'CREATED' || r.status === 'PENDING') {
          await this.repo.updateStatus(r.id, 'FAILED');
        }
        await this.repo.detachIdempotencyKey(r.id);
      };
      if (existing) {
        // (a) Already settled locally → never reopen checkout on a paid order.
        if (existing.status === 'CAPTURED' || existing.status === 'REFUNDED') {
          throw alreadyPaidError();
        }

        // (b) Still open with a live provider order → resume or reconcile.
        if (
          (existing.status === 'CREATED' || existing.status === 'PENDING') &&
          existing.providerOrderRef
        ) {
          // Idempotency contract: the same key must map to the same payment
          // params. A retry that drifts amount/currency/provider is a client
          // bug, not a replay — reject it rather than silently resuming.
          if (
            existing.amount !== input.amount ||
            existing.currency !== currency ||
            existing.provider !== input.provider.toUpperCase()
          ) {
            throw Object.assign(
              new Error('Idempotency key mismatch: same key with different payment params'),
              { status: 400 },
            );
          }

          // Check the LIVE provider order before reopening. A prior attempt may
          // have actually paid even though we never received the webhook (e.g.
          // a localhost dev server Razorpay can't reach). Reopening such an
          // order is exactly what triggers the frozen "something went wrong".
          let live: NormalizedOrderStatus | null = null;
          try {
            live = await provider.fetchOrderStatus(existing.providerOrderRef);
          } catch (err) {
            // Provider unreachable → fall back to resume (best effort). A truly
            // paid order will still be caught by Razorpay/our amount checks.
            tracker.track({
              step: 'ORDER_STATUS_UNAVAILABLE',
              provider: existing.provider,
              intentId: existing.id,
              meta: { error: err instanceof Error ? err.message : 'unknown' },
            });
          }

          if (live?.status === 'PAID') {
            // The order was paid out-of-band — reconcile (mark captured + settle)
            // and tell the caller instead of re-presenting the sheet.
            await this.reconcilePaidOrder(existing, live);
            throw alreadyPaidError();
          }

          if (!isStale(existing)) {
            tracker.track({
              step: 'INTENT_REUSED',
              provider: existing.provider,
              intentId: existing.id,
              providerOrderRef: existing.providerOrderRef,
            });
            return {
              intentId: existing.id,
              provider: existing.provider,
              providerOrderRef: existing.providerOrderRef,
              amount: existing.amount,
              currency: existing.currency,
              clientParams: provider.buildClientParams({
                providerOrderRef: existing.providerOrderRef,
                amountMinor: toMinorUnits(existing.amount),
                currency: existing.currency,
              }),
              reused: true,
            };
          }
          // Stale and provably unpaid → retire and mint fresh below.
          await retireExisting(existing);
          tracker.track({
            step: 'INTENT_RETRIED',
            provider: existing.provider,
            intentId: existing.id,
            meta: { priorStatus: existing.status, reason: 'IDEMPOTENCY_WINDOW_EXPIRED' },
          });
        } else {
          // (c) FAILED, or open but the provider order never attached →
          // retire (frees the unique key — a FAILED row that kept its key
          // used to make the fresh insert below violate the constraint)
          // and mint a FRESH intent + provider order for a clean retry.
          await retireExisting(existing);
          tracker.track({
            step: 'INTENT_RETRIED',
            provider: existing.provider,
            intentId: existing.id,
            meta: { priorStatus: existing.status },
          });
        }
      }
    }

    const intent = await this.repo.create({
      provider: input.provider.toUpperCase(),
      amount: input.amount,
      currency,
      target: input.target,
      shopId: input.shopId,
      customerUserId: input.customerUserId,
      idempotencyKey: input.idempotencyKey,
    });
    tracker.track({
      step: 'INTENT_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      targetType: intent.target.type,
    });

    const session = await provider.createSession({
      amountMinor: toMinorUnits(intent.amount),
      currency,
      intentRef: String(intent.id),
      notes: {
        // Tag every order so a SHARED Razorpay account stays filterable in the
        // dashboard and reports (this app's rows vs. another project's).
        app: 'shopxy',
        intentId: String(intent.id),
        targetType: intent.target.type,
        targetId: String(intent.target.id),
      },
    });
    await this.repo.attachProviderRefs(intent.id, {
      providerOrderRef: session.providerOrderRef,
    });
    tracker.track({
      step: 'SESSION_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: session.providerOrderRef,
    });

    return {
      intentId: intent.id,
      provider: intent.provider,
      providerOrderRef: session.providerOrderRef,
      amount: intent.amount,
      currency,
      clientParams: session.clientParams,
      reused: false,
    };
  }

  /**
   * Create a POS UPI-QR intent + a fixed-amount Razorpay QR for one sale. The QR
   * id is stored as the intent's order ref so the `qr_code.credited` webhook (and
   * the QR-aware reconciliation sweep) resolve ownership through the existing
   * paths. Caller (pos.payments) holds the sale lock, so this mints at most one
   * QR per sale; it does no idempotency replay of its own.
   */
  async initiatePosQr(input: {
    provider: string;
    shopId: number;
    saleId: number;
    amount: number;
    currency?: string;
    idempotencyKey: string;
  }): Promise<{ intentId: number; qrId: string; imageUrl: string; amount: number; currency: string }> {
    const provider = getProvider(input.provider);
    if (!isQrCapable(provider)) {
      throw Object.assign(new Error('Provider does not support UPI-QR'), { status: 400 });
    }
    const currency = input.currency ?? 'INR';

    const intent = await this.repo.create({
      provider: input.provider.toUpperCase(),
      amount: input.amount,
      currency,
      target: { type: 'POS', id: input.saleId },
      shopId: input.shopId,
      customerUserId: null,
      idempotencyKey: input.idempotencyKey,
    });
    tracker.track({
      step: 'INTENT_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      targetType: 'POS',
    });

    const qr = await provider.createPosQr({
      amountMinor: toMinorUnits(intent.amount),
      intentRef: String(intent.id),
      notes: {
        app: 'shopxy',
        intentId: String(intent.id),
        targetType: 'POS',
        targetId: String(input.saleId),
      },
    });
    // The QR id doubles as the order ref (webhook + reconcile resolve by it).
    await this.repo.attachProviderRefs(intent.id, { providerOrderRef: qr.qrId });
    tracker.track({
      step: 'SESSION_CREATED',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: qr.qrId,
    });

    return { intentId: intent.id, qrId: qr.qrId, imageUrl: qr.imageUrl, amount: intent.amount, currency };
  }

  async getIntent(id: number): Promise<GatewayPaymentRecord | null> {
    return this.repo.findById(id);
  }

  /**
   * Abandon an open intent: run the target's teardown (POS closes the QR +
   * unlocks the cart) then mark it FAILED so the reconcile sweep stops scanning
   * it. Idempotent + best-effort; a no-op on an already-settled/terminal intent.
   * Used by the till's "cancel QR" and by the reconcile abandon path.
   */
  async abandonIntent(id: number): Promise<void> {
    const intent = await this.repo.findById(id);
    if (!intent) return;
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') return;
    await this.abandon(intent);
  }

  /**
   * Intent-level reconciliation sweep (the scheduled liveness net).
   *
   * The webhook is the primary settlement path, but it can be missed (a
   * localhost dev box Razorpay can't reach; a dropped or delayed delivery in
   * prod). This sweep re-checks every still-open intent against the provider so
   * money that actually moved gets settled even when no webhook arrived, and
   * checkouts that were abandoned stop being re-scanned forever.
   *
   * For each open (CREATED|PENDING) intent older than `recheckAfterMs`:
   *   - provider order PAID            → reconcile (mark CAPTURED + settle) via
   *                                      the SAME `reconcilePaidOrder` → `confirm`
   *                                      path the webhook uses, so settlement is
   *                                      single-sourced and idempotent.
   *   - definitively not paid, and the intent is older than `abandonAfterMs`
   *                                    → mark FAILED (terminal; stop scanning).
   *   - not paid but still within the abandon window → leave for a later tick.
   *
   * Idempotent and safe to run concurrently with the webhook and with another
   * instance: `confirm` no-ops an already-CAPTURED intent and settlement
   * handlers are keyed. Never throws — a per-intent failure (provider down,
   * amount mismatch) is logged and counted; the batch continues.
   *
   * NOTE: this reconciles the ONLINE-COLLECTION intent only. Transfer-level
   * reconciliation (null-ref HELD `GatewayTransfer`s, overdue releases, out-of-
   * band reversals, KYC retries, and — PR-M3 — CAPTURED POS sales whose
   * afterCommit Route transfer failed) lives in its own sweep:
   * `reconcileStaleTransfers` (settlement/transfer-reconcile.ts), which the
   * scheduler runs alongside this one. Both are idempotent and gated by
   * ROUTE_SPLIT_ENABLED.
   */
  async reconcileStaleIntents(opts?: {
    now?: Date;
    recheckAfterMs?: number;
    abandonAfterMs?: number;
    batchSize?: number;
  }): Promise<ReconcileSummary> {
    const now = opts?.now ?? new Date();
    const recheckAfterMs = opts?.recheckAfterMs ?? 15 * 60_000; // 15 min
    const abandonAfterMs = opts?.abandonAfterMs ?? 24 * 60 * 60_000; // 24 h
    const batchSize = opts?.batchSize ?? 50;

    const recheckBefore = new Date(now.getTime() - recheckAfterMs);
    const abandonBefore = new Date(now.getTime() - abandonAfterMs);

    const stale = await this.repo.findStaleOpenIntents({
      createdBefore: recheckBefore,
      limit: batchSize,
    });

    const summary: ReconcileSummary = {
      scanned: stale.length,
      captured: 0,
      abandoned: 0,
      stillOpen: 0,
      errors: 0,
    };

    for (const intent of stale) {
      try {
        // No provider order was ever attached (createSession failed after the
        // intent row was written): it can never be paid, so there is nothing to
        // probe. Retire it once past the hard window; otherwise let a retry with
        // the same idempotency key resume the slot.
        if (!intent.providerOrderRef) {
          if (intent.createdAt < abandonBefore) {
            await this.fail(intent);
            summary.abandoned++;
            tracker.track({
              step: 'RECONCILE_ABANDONED',
              provider: intent.provider,
              intentId: intent.id,
              meta: { reason: 'no provider order ref' },
            });
          } else {
            summary.stillOpen++;
          }
          continue;
        }

        const provider = getProvider(intent.provider);
        const live = await provider.fetchOrderStatus(intent.providerOrderRef);

        if (live.status === 'PAID') {
          // Missed-webhook heal: marks CAPTURED + runs settlement in one tx,
          // idempotent with the webhook. Reuses the authoritative path.
          await this.reconcilePaidOrder(intent, live);
          summary.captured++;
        } else if (intent.target.type === 'POS') {
          // In-store QR unpaid past the recheck window → abandon now (close the
          // QR + unlock the cart). POS QRs are short-lived; they don't wait the
          // 24h order abandon window. The till's own "cancel" is the fast path;
          // this is the backstop for a QR the cashier walked away from.
          await this.abandon(intent);
          summary.abandoned++;
          tracker.track({
            step: 'RECONCILE_ABANDONED',
            provider: intent.provider,
            intentId: intent.id,
            meta: { liveStatus: live.status, target: 'POS' },
          });
        } else if (intent.createdAt < abandonBefore) {
          // Provider gave a definitive not-paid status AND we're past the hard
          // window → terminal FAILED so we stop re-scanning it.
          await this.fail(intent);
          summary.abandoned++;
          tracker.track({
            step: 'RECONCILE_ABANDONED',
            provider: intent.provider,
            intentId: intent.id,
            meta: { liveStatus: live.status },
          });
        } else {
          // Not paid yet, still within the window — a slow-but-legit payment
          // might still land. Re-check next tick; never abandon on age alone.
          summary.stillOpen++;
        }
      } catch (err) {
        // Provider unreachable, gateway disabled, amount mismatch, etc. Surface
        // it and move on — one bad intent must not stall the sweep. The intent
        // stays open and is retried next tick (or flagged by the anomaly above).
        summary.errors++;
        tracker.track({
          step: 'ORDER_STATUS_UNAVAILABLE',
          provider: intent.provider,
          intentId: intent.id,
          meta: {
            phase: 'reconcile-sweep',
            error: err instanceof Error ? err.message : 'unknown',
          },
        });
      }
    }

    tracker.track({ step: 'RECONCILE_SWEEP', meta: { ...summary } });
    return summary;
  }

  /**
   * Client-confirm / webhook-backstop. After the checkout sheet reports success,
   * the client calls this so the payment settles even where the webhook can't
   * reach the server (localhost dev; a delayed/dropped delivery in prod). It
   * re-checks the LIVE provider order and, if paid, reconciles (marks CAPTURED +
   * settles — posting merchant receipts and flipping the order to PAID).
   *
   * The webhook remains the primary, authoritative path; this is idempotent with
   * it (a later webhook on an already-CAPTURED intent is a no-op, and vice-versa).
   * Never throws on a provider hiccup — returns the best-known status so the UI
   * can still poll/retry.
   */
  async syncIntentStatus(input: {
    customerUserId: number | null;
    idempotencyKey: string;
  }): Promise<{ found: boolean; status: GatewayPaymentStatus | null; settled: boolean }> {
    const existing = await this.repo.findByIdempotencyKey(
      input.customerUserId,
      input.idempotencyKey,
    );
    if (!existing) return { found: false, status: null, settled: false };

    // Already settled locally (webhook beat us here) → nothing to do.
    if (existing.status === 'CAPTURED' || existing.status === 'REFUNDED') {
      return { found: true, status: existing.status, settled: false };
    }
    if (!existing.providerOrderRef) {
      return { found: true, status: existing.status, settled: false };
    }

    const provider = getProvider(existing.provider);
    let live: NormalizedOrderStatus | null = null;
    try {
      live = await provider.fetchOrderStatus(existing.providerOrderRef);
    } catch (err) {
      tracker.track({
        step: 'ORDER_STATUS_UNAVAILABLE',
        provider: existing.provider,
        intentId: existing.id,
        meta: { error: err instanceof Error ? err.message : 'unknown' },
      });
      return { found: true, status: existing.status, settled: false };
    }

    if (live.status === 'PAID') {
      await this.reconcilePaidOrder(existing, live);
      return { found: true, status: 'CAPTURED', settled: true };
    }
    return { found: true, status: existing.status, settled: false };
  }

  /**
   * Process a provider webhook. The webhook is the source of truth that money
   * moved — never the client redirect. Verify signature → dedupe by event id →
   * transition the intent → settle. Throws on transient errors so the route can
   * return 500 and the provider retries.
   */
  async handleWebhook(
    providerName: string,
    rawBody: Buffer,
    headers: HeaderBag,
  ): Promise<void> {
    const provider = getProvider(providerName);

    if (!provider.verifyWebhookSignature(rawBody, headers)) {
      tracker.track({ step: 'SIGNATURE_FAILED', provider: provider.name });
      throw Object.assign(new Error('Invalid webhook signature'), { status: 400 });
    }

    const event = provider.parseWebhookEvent(rawBody, headers);
    tracker.track({
      step: 'WEBHOOK_RECEIVED',
      provider: provider.name,
      providerOrderRef: event.providerOrderRef,
      providerPaymentRef: event.providerPaymentRef,
      meta: { type: event.type, eventId: event.eventId },
    });

    // Marketplace settlement events (transfer.*/account.*/dispute.*) resolve
    // ownership against GatewayTransfer/LinkedAccount/payment, not the intent —
    // route them to the dedicated path (same ownership-first + dedupe discipline).
    if (isSettlementEvent(event.type)) {
      await this.handleSettlementWebhook(provider.name, event);
      return;
    }

    // Ownership FIRST. A Razorpay webhook fires for the whole ACCOUNT, not one
    // app — so if this account is shared, this endpoint also receives OTHER
    // apps' events. They pass signature verification (same account secret) but
    // have no intent here. Such events — and any event without an order ref —
    // are acked-and-ignored. Throwing instead would make Razorpay retry forever
    // and eventually auto-disable the webhook. A genuine "our order not yet
    // committed" race is the reconciliation sweep's job, not the webhook's.
    const intent = event.providerOrderRef
      ? await this.repo.findByProviderOrderRef(provider.name, event.providerOrderRef)
      : event.providerPaymentRef
        ? await this.repo.findByProviderPaymentRef(provider.name, event.providerPaymentRef)
        : null;
    if (!intent) {
      tracker.track({
        step: 'WEBHOOK_IGNORED',
        provider: provider.name,
        providerOrderRef: event.providerOrderRef,
        meta: { type: event.type, reason: 'no matching intent (foreign-account event or pre-commit race)' },
      });
      return; // ack 200, do nothing
    }

    // Exactly-once for OUR events only — keeps the dedupe table free of the
    // other app's noise on a shared account.
    const fresh = await this.events.claim(provider.name, event.eventId, event.raw);
    if (!fresh) {
      tracker.track({ step: 'WEBHOOK_DEDUPED', provider: provider.name, intentId: intent.id });
      return;
    }

    // Transition+settle BEFORE marking processed. If a step throws, the
    // exception propagates and `markProcessed` is skipped, so processedAt stays
    // null — the audit trail distinguishes "claimed but settlement failed" from
    // "claimed and processed". The claim's unique gate still dedupes a literal
    // redelivery; genuine retries of a transient failure are reconciliation's
    // job, not the webhook's.
    try {
      if (event.type === 'PAID') {
        await this.confirm(intent, event);
      } else if (event.type === 'FAILED') {
        await this.fail(intent);
      } else if (event.type === 'REFUNDED') {
        await this.onRefundEvent(provider.name, event);
      }
      // PENDING / UNKNOWN: recorded for audit, no state change.
    } catch (err) {
      // Don't mark processed — leave processedAt null for the audit trail.
      throw err;
    }

    await this.events.markProcessed(provider.name, event.eventId);
  }

  /**
   * Settlement webhook path (transfer / account / dispute events). Same discipline
   * as the intent path: ownership first (ack-and-ignore a foreign event on a shared
   * account), then exactly-once claim, then handle, then mark processed. A throw
   * leaves processedAt null so reconciliation/redelivery retries.
   */
  private async handleSettlementWebhook(
    providerName: string,
    event: NormalizedEvent,
  ): Promise<void> {
    if (!(await ownsSettlementEvent(event))) {
      tracker.track({
        step: 'WEBHOOK_IGNORED',
        provider: providerName,
        meta: { type: event.type, reason: 'no matching transfer/account/payment (foreign-account event)' },
      });
      return; // ack 200
    }
    const fresh = await this.events.claim(providerName, event.eventId, event.raw);
    if (!fresh) {
      tracker.track({ step: 'WEBHOOK_DEDUPED', provider: providerName, meta: { type: event.type } });
      return;
    }
    await handleSettlementEvent(event); // throws → markProcessed skipped (audit trail)
    await this.events.markProcessed(providerName, event.eventId);
  }

  // ── internal ──────────────────────────────────────────────────────────

  /**
   * Reconcile an intent whose provider order was paid out-of-band (we never got
   * the webhook). Synthesises a PAID event and runs the normal confirm path —
   * marking the intent CAPTURED and settling (which posts the merchant receipt
   * and flips the order to PAID). Idempotent: a later real webhook is a no-op.
   */
  private async reconcilePaidOrder(
    intent: GatewayPaymentRecord,
    live: NormalizedOrderStatus,
  ): Promise<void> {
    tracker.track({
      step: 'RECONCILE_PAID',
      provider: intent.provider,
      intentId: intent.id,
      providerOrderRef: intent.providerOrderRef,
      meta: { capturedPaymentRef: live.capturedPaymentRef },
    });
    await this.confirm(intent, {
      type: 'PAID',
      eventId: `reconcile:${intent.providerOrderRef}`,
      providerOrderRef: intent.providerOrderRef,
      providerPaymentRef: live.capturedPaymentRef,
      amountMinor: live.amountPaidMinor,
      currency: intent.currency,
      raw: { reconciled: true },
    });
  }

  private async confirm(intent: GatewayPaymentRecord, event: NormalizedEvent): Promise<void> {
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') {
      return; // already settled — idempotent
    }

    // Defend against tampering / wrong-intent: a capture must state the
    // amount, and it must match. A PAID event with no amount would
    // otherwise skip the comparison entirely — "payment captured, amount
    // unspecified" is not a thing a trusted capture says.
    if (event.type === 'PAID' && event.amountMinor == null) {
      tracker.track({
        step: 'AMOUNT_MISMATCH',
        provider: intent.provider,
        intentId: intent.id,
        meta: { expected: toMinorUnits(intent.amount), got: null },
      });
      throw Object.assign(new Error('PAID webhook must include the captured amount'), {
        status: 400,
      });
    }
    if (event.amountMinor != null && event.amountMinor !== toMinorUnits(intent.amount)) {
      tracker.track({
        step: 'AMOUNT_MISMATCH',
        provider: intent.provider,
        intentId: intent.id,
        meta: { expected: toMinorUnits(intent.amount), got: event.amountMinor },
      });
      throw Object.assign(new Error('Webhook amount does not match intent'), {
        status: 400,
      });
    }

    if (event.providerPaymentRef) {
      await this.repo.attachProviderRefs(intent.id, {
        providerPaymentRef: event.providerPaymentRef,
      });
    }

    // Status update + settlement commit in ONE DB tx for atomicity: if
    // settlement throws, the CAPTURED status rolls back too, so a redelivered
    // webhook re-attempts settlement instead of short-circuiting on a CAPTURED
    // intent with an unposted credit. Settlement is still idempotent (keyed
    // wallet credit), so a redelivery after a successful commit is a no-op.
    const settled: GatewayPaymentRecord = {
      ...intent,
      status: 'CAPTURED',
      providerPaymentRef: event.providerPaymentRef ?? intent.providerPaymentRef,
    };
    const handler = settlementFor(intent.target.type);
    await prisma.$transaction(async (tx) => {
      await this.repo.updateStatus(intent.id, 'CAPTURED', tx);
      await handler.onPaid(settled, tx);
    });
    tracker.track({
      step: 'PAYMENT_CONFIRMED',
      provider: intent.provider,
      intentId: intent.id,
      status: 'SUCCESS',
    });

    // Post-commit external side effects (e.g. creating Route transfers). Run
    // AFTER the tx so a provider call can't hold the DB tx open or move money
    // against an uncommitted row. Best-effort: failures are healable by
    // reconciliation (null-ref HELD rows are re-driven), so a hiccup here must
    // not fail the webhook — the money already captured and settled in-tx.
    if (handler.afterCommit) {
      try {
        await handler.afterCommit(settled);
      } catch (err) {
        tracker.track({
          step: 'SETTLEMENT_DONE',
          provider: intent.provider,
          intentId: intent.id,
          targetType: intent.target.type,
          status: 'FAILED',
          error: err instanceof Error ? err.message : 'afterCommit failed',
        });
      }
    }
    tracker.track({
      step: 'SETTLEMENT_DONE',
      provider: intent.provider,
      intentId: intent.id,
      targetType: intent.target.type,
      status: 'SUCCESS',
    });
  }

  /**
   * Tear down an abandoned/cancelled intent: best-effort target teardown
   * (handler.onAbandon — POS closes the QR + unlocks the cart) then FAILED.
   * A teardown failure is logged, not fatal — the intent still fails so the
   * sweep stops re-scanning it.
   */
  private async abandon(intent: GatewayPaymentRecord): Promise<void> {
    const handler = settlementFor(intent.target.type);
    if (handler.onAbandon) {
      try {
        await handler.onAbandon(intent);
      } catch (err) {
        tracker.track({
          step: 'PAYMENT_FAILED',
          provider: intent.provider,
          intentId: intent.id,
          meta: { phase: 'onAbandon', error: err instanceof Error ? err.message : 'unknown' },
        });
      }
    }
    await this.fail(intent);
  }

  /**
   * Settle a refund.* webhook against OUR refund row. The synchronous
   * provider.refund call usually already recorded the row (PENDING for a normal
   * refund, PROCESSED for an instant one); this confirms a PENDING → PROCESSED
   * once the money actually settled to the instrument. Idempotent: an already-
   * PROCESSED row, or a refund we didn't originate (e.g. issued from the
   * provider dashboard) with no matching row, is a no-op ack.
   */
  private async onRefundEvent(
    providerName: string,
    event: NormalizedEvent,
  ): Promise<void> {
    if (!event.providerRefundRef) return;
    const row = await this.refunds.findByProviderRef(
      providerName,
      event.providerRefundRef,
    );
    if (!row || row.status === 'PROCESSED') return;
    await this.refunds.update(row.id, { status: 'PROCESSED' });
    tracker.track({
      step: 'REFUND_PROCESSED',
      provider: row.provider,
      meta: { refundId: row.id, providerRefundRef: event.providerRefundRef },
    });
  }

  private async fail(intent: GatewayPaymentRecord): Promise<void> {
    if (intent.status === 'CAPTURED' || intent.status === 'REFUNDED') {
      return; // never fail a captured payment on a late failure event
    }
    await this.repo.updateStatus(intent.id, 'FAILED');
    tracker.track({
      step: 'PAYMENT_FAILED',
      provider: intent.provider,
      intentId: intent.id,
      status: 'FAILED',
    });
  }
}
