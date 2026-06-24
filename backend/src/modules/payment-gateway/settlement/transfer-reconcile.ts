/**
 * Transfer-level reconciliation — the liveness net for the Route on-hold split.
 *
 * The create path writes GatewayTransfer rows INSIDE the settlement tx and makes
 * the provider call AFTER commit (so a crash can't move money without a row).
 * That leaves two states this sweep heals, plus the scheduled release:
 *
 *   P1 — Null-ref HELD heal: a HELD row whose `providerTransferRef` never landed
 *        (process died between commit and the post-commit createTransfers). We
 *        re-drive `executeHeldTransfers`, which does fetch-before-create — so a
 *        transfer that DID reach Razorpay is adopted, never duplicated.
 *   P2 — Overdue release: a HELD row past `holdUntil` whose child has no open
 *        return → `releaseTransfer` (idempotent PATCH) → mark RELEASED. We hold
 *        through an open return so an in-hold reversal stays clean.
 *
 * Heal-vs-flag discipline (from the tutorix port): per-item try/catch so one bad
 * row never stalls the sweep; idempotent provider calls; nothing here touches an
 * amount it can't prove. P3–P5 (reversal/partial/insufficient-balance verify)
 * land in the next iteration.
 */
import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import {
  isSplitCapable,
  type ExistingTransfer,
  type PaymentGatewayPort,
  type SplitCapablePort,
} from '../ports/payment-provider.port.js';
import { executeHeldTransfers, isRouteSplitEnabled } from './order-split.js';
import { settlePosTransfer } from './pos-split.js';
import { toMinorUnits, fromMinorUnits } from '../helpers.js';
import { tracker } from '../tracker.js';
import type { GatewayPaymentRecord, SettlementTargetType } from '../ports/types.js';

/** Return states that mean a return is still in flight — hold the money. */
const OPEN_RETURN_STATUSES = ['REQUESTED', 'APPROVED', 'PICKED_UP', 'RECEIVED'];

export interface TransferReconcileSummary {
  /** P1: distinct payments with stale null-ref HELD rows we re-drove. */
  healPaymentsScanned: number;
  healed: { created: number; reconciled: number; failed: number };
  /** P2: overdue holds examined. */
  releasesScanned: number;
  released: number;
  /** P2: overdue holds left HELD because a return opened in the release race. */
  deferredOpenReturn: number;
  /** P3: rows whose state we reconciled against the provider. */
  verified: number;
  /** P3: DB said RELEASED but provider still on_hold → re-drove releaseTransfer. */
  reReleased: number;
  /** P3: DB HELD but provider already settled (Razorpay auto-release) → RELEASED. */
  autoReleased: number;
  /** P3/P4: rows synced to REVERSED (full) or with reversedAmount updated (partial). */
  reversalSynced: number;
  /** P4: provider shows LESS reversed than our DB — flagged, never silently shrunk. */
  reversalMismatchFlagged: number;
  /** P7: KYC_GATED rows re-driven once their LinkedAccount activated. */
  kycRetried: number;
  /**
   * PR-M3: CAPTURED POS sales whose post-commit Route transfer is re-driven.
   * The POS split (pos-split.ts) writes NO DB transfer row — it calls Razorpay
   * directly in afterCommit — so a failed afterCommit leaves nothing for the
   * null-ref-HELD heal above to re-drive. This step re-runs the idempotent
   * settlePosTransfer for captured POS intents so a single post-commit hiccup
   * can't strand a merchant's in-store payout.
   */
  posReDriven: number;
  /** Transfers stuck FAILED right now (dead-letter signal — seller unpaid). */
  failedTransfers: number;
  errors: number;
}

type SplitProvider = PaymentGatewayPort & SplitCapablePort;

export async function reconcileStaleTransfers(opts?: {
  now?: Date;
  healAfterMs?: number;
  batchSize?: number;
}): Promise<TransferReconcileSummary> {
  const now = opts?.now ?? new Date();
  // Heal only rows old enough that the in-flight post-commit write has surely
  // finished or died — never race it (longer than the intent sweep's window).
  const healAfterMs = opts?.healAfterMs ?? 15 * 60_000;
  const batchSize = opts?.batchSize ?? 100;
  const healBefore = new Date(now.getTime() - healAfterMs);

  const summary: TransferReconcileSummary = {
    healPaymentsScanned: 0,
    healed: { created: 0, reconciled: 0, failed: 0 },
    releasesScanned: 0,
    released: 0,
    deferredOpenReturn: 0,
    verified: 0,
    reReleased: 0,
    autoReleased: 0,
    reversalSynced: 0,
    reversalMismatchFlagged: 0,
    kycRetried: 0,
    posReDriven: 0,
    failedTransfers: 0,
    errors: 0,
  };

  // ── P1: heal null-ref HELD rows (crash between commit and provider call) ──
  const stalePayments = await prisma.gatewayTransfer.findMany({
    where: { status: 'HELD', providerTransferRef: null, createdAt: { lt: healBefore } },
    select: { gatewayPaymentId: true },
    distinct: ['gatewayPaymentId'],
    take: batchSize,
  });
  summary.healPaymentsScanned = stalePayments.length;
  for (const { gatewayPaymentId } of stalePayments) {
    try {
      const r = await executeHeldTransfers(gatewayPaymentId);
      summary.healed.created += r.created;
      summary.healed.reconciled += r.reconciled;
      summary.healed.failed += r.failed;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: gatewayPaymentId,
        meta: { phase: 'reconcile-heal', error: errMsg(err) },
      });
    }
  }

  // ── P2: release overdue holds whose child has no open return ──
  // Open-return rows are excluded at the SQL layer (`returns: { none: … }`) so
  // they can't starve the batch, and we order by holdUntil so the longest-due
  // settle first. holdUntil NULL is deliberately excluded by `lt: now`:
  // indefinite holds (returnWindowDays === 0) are released only by buyer-confirm,
  // never auto-released here.
  const dueHolds = await prisma.gatewayTransfer.findMany({
    where: {
      status: 'HELD',
      providerTransferRef: { not: null },
      holdUntil: { lt: now },
      purchaseRequest: { returns: { none: { status: { in: OPEN_RETURN_STATUSES } } } },
    },
    select: {
      id: true,
      gatewayPaymentId: true,
      purchaseRequestId: true,
      providerTransferRef: true,
    },
    orderBy: { holdUntil: 'asc' },
    take: batchSize,
  });
  summary.releasesScanned = dueHolds.length;

  const providerCache = new Map<number, SplitProvider | null>();
  for (const t of dueHolds) {
    try {
      // Race guard: a return may have opened between the SQL filter and now.
      const openReturn = await prisma.returnRequest.findFirst({
        where: { requestId: t.purchaseRequestId, status: { in: OPEN_RETURN_STATUSES } },
        select: { id: true },
      });
      if (openReturn) {
        summary.deferredOpenReturn++;
        continue;
      }

      const provider = await resolveSplitProvider(t.gatewayPaymentId, providerCache);
      if (!provider) continue;

      // Claim-once: atomically transition HELD→RELEASED. If a concurrent path
      // (another sweep instance, buyer-confirm release, or a return reversal)
      // already moved the row, count === 0 and we skip — no double-act. This
      // (not the open-return read above) is the real serialization point; the
      // reversal path claims the same HELD row, so whoever wins the row decides.
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: t.id, status: 'HELD' },
        data: { status: 'RELEASED', releasedAt: new Date() },
      });
      if (claim.count !== 1) continue;

      try {
        // Idempotent PATCH; safe to re-send if a prior tick released then died.
        await provider.releaseTransfer(t.providerTransferRef!);
        summary.released++;
      } catch (relErr) {
        // Roll the claim back so a later tick (or P3 verify) retries the release.
        await prisma.gatewayTransfer.updateMany({
          where: { id: t.id, status: 'RELEASED' },
          data: { status: 'HELD', releasedAt: null },
        });
        throw relErr;
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: t.gatewayPaymentId,
        meta: { phase: 'reconcile-release', transferId: t.id, error: errMsg(err) },
      });
    }
  }

  // ── P3 + P4: verify HELD/RELEASED/REVERSED rows against the provider ──
  await verifyAndSyncTransfers(summary, batchSize);

  // ── P7: retry KYC_GATED rows whose linked account has since activated ──
  await retryKycGatedTransfers(summary, batchSize);

  // ── PR-M3: re-drive CAPTURED POS Route transfers (no DB row to heal) ──
  await reDrivePosTransfers(summary, batchSize, healBefore);

  // Dead-letter signal: transfers stuck FAILED (KYC mismatch, Razorpay rejection)
  // mean a seller is silently unpaid. Surface the count every sweep so it's
  // visible; the full flag-for-human path lands with P5.
  summary.failedTransfers = await prisma.gatewayTransfer.count({ where: { status: 'FAILED' } });
  if (summary.failedTransfers > 0) {
    tracker.track({
      step: 'ROUTE_SPLIT_FAILED',
      meta: { phase: 'reconcile-dead-letter', failedTransfers: summary.failedTransfers, severity: 'CRITICAL' },
    });
  }

  tracker.track({ step: 'RECONCILE_SWEEP', meta: { scope: 'transfers', ...summary } });
  return summary;
}

/** Resolve (and cache) the split-capable provider for a payment. Null when the
 *  payment is gone or its provider can't split (shouldn't happen for HELD rows). */
async function resolveSplitProvider(
  gatewayPaymentId: number,
  cache: Map<number, SplitProvider | null>,
): Promise<SplitProvider | null> {
  const cached = cache.get(gatewayPaymentId);
  if (cached !== undefined) return cached;
  const pay = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true },
  });
  let resolved: SplitProvider | null = null;
  if (pay) {
    const p = getProvider(pay.provider);
    if (isSplitCapable(p)) resolved = p;
  }
  cache.set(gatewayPaymentId, resolved);
  return resolved;
}

/** Provider + captured-payment ref for a gateway payment (cached per sweep). */
async function resolvePaymentContext(
  gatewayPaymentId: number,
  cache: Map<number, { provider: SplitProvider; paymentRef: string } | null>,
): Promise<{ provider: SplitProvider; paymentRef: string } | null> {
  const cached = cache.get(gatewayPaymentId);
  if (cached !== undefined) return cached;
  const pay = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true, providerPaymentRef: true },
  });
  let ctx: { provider: SplitProvider; paymentRef: string } | null = null;
  if (pay?.providerPaymentRef) {
    const p = getProvider(pay.provider);
    if (isSplitCapable(p)) ctx = { provider: p, paymentRef: pay.providerPaymentRef };
  }
  cache.set(gatewayPaymentId, ctx);
  return ctx;
}

/**
 * P3 + P4 — reconcile each transfer's DB state against what Razorpay actually
 * reports (now that listTransfers surfaces status + amount_reversed):
 *   • provider fully reversed  → mark REVERSED (sync an out-of-band reversal).
 *   • provider partially reversed → bump reversedAmount to match (P4); if the
 *     provider shows LESS reversed than our DB, that's a real discrepancy we
 *     FLAG and never silently shrink.
 *   • DB RELEASED but provider still on_hold → re-drive releaseTransfer (closes
 *     the crash-after-claim gap from P2).
 *   • DB HELD but provider already settled → Razorpay auto-released at
 *     on_hold_until before our sweep; mark RELEASED (claim-once).
 */
async function verifyAndSyncTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
): Promise<void> {
  const rows = await prisma.gatewayTransfer.findMany({
    // REVERSED is terminal — no point re-listing it at the provider every sweep.
    // PARTIALLY_REVERSED stays in scope so a later full reversal is caught.
    where: {
      providerTransferRef: { not: null },
      status: { in: ['HELD', 'RELEASED', 'PARTIALLY_REVERSED'] },
    },
    select: {
      id: true,
      gatewayPaymentId: true,
      providerTransferRef: true,
      status: true,
      amount: true,
      reversedAmount: true,
    },
    orderBy: { id: 'asc' },
    take: batchSize,
  });
  if (rows.length === 0) return;

  const byPayment = new Map<number, typeof rows>();
  for (const r of rows) {
    const list = byPayment.get(r.gatewayPaymentId);
    if (list) list.push(r);
    else byPayment.set(r.gatewayPaymentId, [r]);
  }

  const ctxCache = new Map<number, { provider: SplitProvider; paymentRef: string } | null>();
  for (const [paymentId, group] of byPayment) {
    let byRef: Map<string, ExistingTransfer>;
    try {
      const ctx = await resolvePaymentContext(paymentId, ctxCache);
      if (!ctx) {
        // A transfer with a provider ref implies a captured payment with a ref;
        // a missing context is an anomaly worth surfacing, not silently skipping.
        tracker.track({
          step: 'ROUTE_SPLIT_FAILED',
          intentId: paymentId,
          meta: { phase: 'reconcile-verify-no-context', rows: group.length },
        });
        continue;
      }
      const existing = await ctx.provider.listTransfers(ctx.paymentRef);
      byRef = new Map(existing.map((e) => [e.transferRef, e]));
      for (const row of group) {
        try {
          const prov = byRef.get(row.providerTransferRef!);
          if (!prov) continue; // provider doesn't know it — leave for human review
          summary.verified++;
          await reconcileRowAgainstProvider(row, prov, ctx.provider, summary);
        } catch (err) {
          summary.errors++;
          tracker.track({
            step: 'ROUTE_SPLIT_FAILED',
            intentId: paymentId,
            meta: { phase: 'reconcile-verify', transferId: row.id, error: errMsg(err) },
          });
        }
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: paymentId,
        meta: { phase: 'reconcile-verify-list', error: errMsg(err) },
      });
    }
  }
}

async function reconcileRowAgainstProvider(
  row: { id: number; status: string; amount: Prisma.Decimal; reversedAmount: Prisma.Decimal; providerTransferRef: string | null },
  prov: ExistingTransfer,
  provider: SplitProvider,
  summary: TransferReconcileSummary,
): Promise<void> {
  const amountMinor = toMinorUnits(Number(row.amount));
  const reversedMinor = prov.amountReversedMinor;

  // Fully reversed (status or amount) → REVERSED.
  if (prov.status === 'reversed' || reversedMinor >= amountMinor) {
    // Over-reversal anomaly: provider reversed MORE than the transfer amount.
    // Surface it (don't just silently clamp) — symmetric to the under-report flag.
    if (reversedMinor > amountMinor + 1) {
      summary.reversalMismatchFlagged++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        meta: {
          phase: 'reconcile-over-reversal',
          transferId: row.id,
          amountMinor,
          providerReversedMinor: reversedMinor,
          severity: 'CRITICAL',
        },
      });
    }
    if (row.status !== 'REVERSED') {
      // Claim-once (not a blind update): a concurrent reversal writer can't be
      // clobbered by this stale-snapshot transition.
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: row.id, status: { not: 'REVERSED' } },
        data: {
          status: 'REVERSED',
          reversedAt: new Date(),
          reversedAmount: new Prisma.Decimal(fromMinorUnits(Math.min(reversedMinor, amountMinor))),
        },
      });
      if (claim.count === 1) summary.reversalSynced++;
    }
    return;
  }

  // Partially reversed → sync reversedAmount AND move out of plain HELD so P2
  // can't auto-release a partially-reversed transfer (P4 + the C1 fix).
  if (reversedMinor > 0) {
    const dbReversedMinor = toMinorUnits(Number(row.reversedAmount));
    if (reversedMinor < dbReversedMinor - 1) {
      // Provider reversed LESS than we recorded — a real discrepancy. Flag,
      // never silently shrink (could double-credit a buyer).
      summary.reversalMismatchFlagged++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        meta: {
          phase: 'reconcile-reversal-mismatch',
          transferId: row.id,
          dbReversedMinor,
          providerReversedMinor: reversedMinor,
          severity: 'CRITICAL',
        },
      });
      return;
    }
    const needsAmountSync = Math.abs(reversedMinor - dbReversedMinor) > 1;
    const needsStatus = row.status === 'HELD'; // not yet flagged partial
    if (needsAmountSync || needsStatus) {
      const claim = await prisma.gatewayTransfer.updateMany({
        // Only HELD/PARTIALLY_REVERSED — never reopen a RELEASED/REVERSED row.
        where: { id: row.id, status: { in: ['HELD', 'PARTIALLY_REVERSED'] } },
        data: {
          ...(needsAmountSync
            ? { reversedAmount: new Prisma.Decimal(fromMinorUnits(reversedMinor)) }
            : {}),
          ...(needsStatus ? { status: 'PARTIALLY_REVERSED' } : {}),
        },
      });
      if (claim.count === 1) summary.reversalSynced++;
    }
    return;
  }

  // Not reversed. Reconcile hold/release.
  if (prov.onHold) {
    // Provider still holds. DB RELEASED ⇒ our release never landed (crash after
    // the claim-flip). Re-drive the idempotent release.
    if (row.status === 'RELEASED') {
      await provider.releaseTransfer(row.providerTransferRef!);
      summary.reReleased++;
    }
    return;
  }
  // Provider settled it (auto-released at on_hold_until). Catch the DB up.
  if (row.status === 'HELD') {
    const claim = await prisma.gatewayTransfer.updateMany({
      where: { id: row.id, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: new Date() },
    });
    if (claim.count === 1) summary.autoReleased++;
  }
}

/**
 * P7 — a KYC_GATED row's shop has since activated its linked account. Promote it
 * HELD (claim-once) with the now-active account, then drive the actual transfer
 * via the same idempotent executeHeldTransfers path.
 */
async function retryKycGatedTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
): Promise<void> {
  const gated = await prisma.gatewayTransfer.findMany({
    where: { status: 'KYC_GATED' },
    select: {
      id: true,
      gatewayPaymentId: true,
      purchaseRequest: {
        select: {
          shop: {
            select: {
              linkedAccount: {
                select: { id: true, providerAccountId: true, payoutsEnabled: true },
              },
            },
          },
        },
      },
    },
    take: batchSize,
  });
  if (gated.length === 0) return;

  const touchedPayments = new Set<number>();
  for (const g of gated) {
    try {
      const la = g.purchaseRequest.shop.linkedAccount;
      if (!la || !la.payoutsEnabled || !la.providerAccountId) continue; // still gated
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: g.id, status: 'KYC_GATED' },
        data: {
          status: 'HELD',
          linkedAccountId: la.id,
          providerAccountId: la.providerAccountId,
          failureReason: null,
        },
      });
      if (claim.count === 1) {
        summary.kycRetried++;
        touchedPayments.add(g.gatewayPaymentId);
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: g.gatewayPaymentId,
        meta: { phase: 'reconcile-kyc-retry', transferId: g.id, error: errMsg(err) },
      });
    }
  }

  // Drive the newly-promoted HELD rows to real transfers (fetch-before-create).
  for (const paymentId of touchedPayments) {
    try {
      const r = await executeHeldTransfers(paymentId);
      summary.healed.created += r.created;
      summary.healed.reconciled += r.reconciled;
      summary.healed.failed += r.failed;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: paymentId,
        meta: { phase: 'reconcile-kyc-execute', error: errMsg(err) },
      });
    }
  }
}

/**
 * PR-M3 — re-drive the Route transfer for CAPTURED POS sales.
 *
 * Unlike the ORDER split, the POS path writes no GatewayTransfer DB row: it
 * calls Razorpay directly in `afterCommit`. So a post-commit failure (process
 * died, provider blip) leaves a captured-but-unrouted sale with NOTHING for the
 * null-ref-HELD heal (P1) to pick up — the merchant's in-store payout would
 * stall indefinitely. We re-run `settlePosTransfer`, which is fetch-before-
 * create idempotent (matches the deterministic `pos:<saleId>` note), so a sale
 * that DID reach Razorpay is adopted, never paid twice. No-op while the flag is
 * off. We only look at intents older than `healBefore` so an in-flight
 * afterCommit from the live webhook is never raced.
 */
async function reDrivePosTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
  healBefore: Date,
): Promise<void> {
  if (!isRouteSplitEnabled()) return; // captured POS funds stay platform-side

  const rows = await prisma.gatewayPayment.findMany({
    where: {
      status: 'CAPTURED',
      targetType: 'POS',
      providerPaymentRef: { not: null },
      shopId: { not: null },
      updatedAt: { lt: healBefore },
    },
    select: {
      id: true,
      provider: true,
      status: true,
      amount: true,
      currency: true,
      targetType: true,
      targetId: true,
      shopId: true,
      customerUserId: true,
      providerOrderRef: true,
      providerPaymentRef: true,
      amountRefunded: true,
      idempotencyKey: true,
      createdAt: true,
      updatedAt: true,
    },
    orderBy: { updatedAt: 'asc' },
    take: batchSize,
  });

  for (const row of rows) {
    const intent: GatewayPaymentRecord = {
      id: row.id,
      provider: row.provider,
      status: row.status as GatewayPaymentRecord['status'],
      amount: Number(row.amount),
      currency: row.currency,
      target: { type: row.targetType as SettlementTargetType, id: row.targetId },
      shopId: row.shopId,
      customerUserId: row.customerUserId,
      providerOrderRef: row.providerOrderRef,
      providerPaymentRef: row.providerPaymentRef,
      amountRefunded: Number(row.amountRefunded),
      idempotencyKey: row.idempotencyKey,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
    try {
      // Idempotent: a transfer that already exists is detected and skipped.
      await settlePosTransfer(intent);
      summary.posReDriven++;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: row.id,
        meta: { phase: 'reconcile-pos-redrive', error: errMsg(err) },
      });
    }
  }
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : 'unknown';
}
