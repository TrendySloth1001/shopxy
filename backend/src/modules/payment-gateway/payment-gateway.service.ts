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
  WebhookEventRepository,
} from './ports/repository.port.js';
import type { HeaderBag } from './ports/payment-provider.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  NormalizedEvent,
  NormalizedOrderStatus,
  SettlementTarget,
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

export class PaymentGatewayService {
  constructor(
    private readonly repo: GatewayPaymentRepository,
    private readonly events: WebhookEventRepository,
  ) {}

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

  async getIntent(id: number): Promise<GatewayPaymentRecord | null> {
    return this.repo.findById(id);
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
   * reconciliation (null-ref HELD `GatewayTransfer`s, KYC-not-activated retries,
   * reversal-balance failures) hooks in here once Route split lands — see
   * ROUTE_SPLIT_DESIGN.md §2/§7. Those tables do not exist yet, so there is
   * nothing to sweep for them today.
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
      }
      // REFUNDED / PENDING / UNKNOWN: recorded for audit, no state change yet.
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
