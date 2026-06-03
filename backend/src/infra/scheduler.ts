import cron, { ScheduledTask } from 'node-cron';
import { logger } from '../shared/logging/logger.js';
import { flashSalesService } from '../modules/flash-sales/flash-sales.service.js';
import { eventsService } from '../modules/events/events.service.js';
import { trendingService } from '../modules/trending/trending.service.js';
import { promotionsService } from '../modules/promotions/promotions.service.js';
import { embeddingService } from '../modules/search/embedding.service.js';
import { productsService } from '../modules/products/products.service.js';
import { marketplaceService } from '../modules/marketplace/marketplace.service.js';
import { paymentGatewayService } from '../modules/payment-gateway/index.js';
import { reconcileStaleTransfers } from '../modules/payment-gateway/settlement/transfer-reconcile.js';
import { isRouteSplitEnabled } from '../modules/payment-gateway/settlement/order-split.js';
import { linkedAccountsService } from '../modules/linked-accounts/linked-accounts.service.js';
import { tryAcquireJobLock } from './redis.js';

/// Lightweight in-process cron registry. We deliberately stay on
/// node-cron (rather than BullMQ) until durability matters — every
/// job here is idempotent and OK to skip if the process crashes
/// mid-tick. Promote when:
///   - jobs need retries across worker boots, or
///   - we add work that *can't* be safely re-run.
///
/// Each job wraps its body in try/catch and structured logging so a
/// failure in one tick never tears down the scheduler.

const jobs: ScheduledTask[] = [];

async function runSafely(name: string, body: () => Promise<unknown>): Promise<void> {
  try {
    const t0 = Date.now();
    const result = await body();
    logger.debug({ job: name, ms: Date.now() - t0, result }, 'cron tick ok');
  } catch (err) {
    logger.error({ job: name, err: (err as Error).message }, 'cron tick failed');
  }
}

export function startScheduler(): void {
  if (jobs.length > 0) {
    logger.warn('scheduler already running, skipping start');
    return;
  }
  if (process.env.DISABLE_CRON === 'true' || process.env.NODE_ENV === 'test') {
    logger.info('scheduler disabled by env');
    return;
  }

  // Every 60s — persist Redis flash-sale soldCounts back to Postgres.
  // No-op when Redis isn't reachable.
  jobs.push(
    cron.schedule('*/60 * * * * *', () =>
      runSafely('flash:flush-sold', () => flashSalesService.flushSoldCountersToDb()),
    ),
  );

  // Every 5min — flip is_active=false on flash sales past their endAt.
  // Cheap UPDATE … WHERE; runs even without Redis.
  jobs.push(
    cron.schedule('*/5 * * * *', () =>
      runSafely('flash:sweep-expired', () => flashSalesService.sweepExpired()),
    ),
  );

  // Hourly — cap each user's recently_viewed list at 20 rows.
  // Cheap window-function DELETE; safe to skip a tick.
  jobs.push(
    cron.schedule('0 * * * *', () =>
      runSafely('events:trim-recently-viewed', () =>
        eventsService.trimRecentlyViewed(),
      ),
    ),
  );

  // Every 15min — recompute the trending snapshot from the last 24h
  // of product_events. Single big SQL + upserts; runs fine even when
  // there are no events (no-ops cheaply).
  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('trending:recompute', () => trendingService.recomputeWindow()),
    ),
  );

  // Nightly at 04:00 server-local — rebuild for-you cache for any
  // user with activity in the last 30 days.
  jobs.push(
    cron.schedule('0 4 * * *', () =>
      runSafely('recs:rebuild-all', () =>
        trendingService.rebuildAllRecommendations(),
      ),
    ),
  );

  // Daily at 03:00 server-local — drop product_events older than 90d.
  // Bigtable-style retention; aggregates live elsewhere.
  jobs.push(
    cron.schedule('0 3 * * *', () =>
      runSafely('events:prune-old', () => eventsService.pruneOldEvents()),
    ),
  );

  // Daily at 03:00 server-local — refresh the soldLast30d denorm from
  // the trailing-30-day confirmed-invoice window. Shares the 03:00 slot
  // with events:prune-old; both are SQL-heavy, idempotent, and tolerate
  // running in parallel.
  jobs.push(
    cron.schedule('0 3 * * *', () =>
      runSafely('products:refresh-sold-last-30d', () =>
        productsService.refreshSoldLast30d(),
      ),
    ),
  );

  // Daily at 03:30 server-local — recompute the frequently-bought-
  // together cache from 90 days of confirmed-invoice co-occurrence.
  // Offset from the 03:00 batch so the two big SQL passes don't fight
  // for the same connection slot.
  jobs.push(
    cron.schedule('30 3 * * *', () =>
      runSafely('marketplace:recompute-fbt', () =>
        marketplaceService.recomputeFbtCache(),
      ),
    ),
  );

  // Hourly — verify promotion day-state + auto-expire windows past
  // endAt. Belt-and-braces over the inline recordImpressions check.
  jobs.push(
    cron.schedule('30 * * * *', () =>
      runSafely('promotions:sweep', () =>
        promotionsService.sweepDailyCaps(),
      ),
    ),
  );

  // Every 2 minutes — embed up to 50 unembedded products. No-op when
  // OLLAMA_KEY isn't set (embeddingService.isEnabled === false), so
  // dev environments without an Ollama key still boot cleanly and the
  // search service falls back to FTS-only.
  if (embeddingService.isEnabled) {
    jobs.push(
      cron.schedule('*/2 * * * *', () =>
        runSafely('search:embed-pending', () =>
          embeddingService.embedPendingProducts(50),
        ),
      ),
    );
  } else {
    logger.warn(
      'search: embedding service disabled (no OLLAMA_KEY) — semantic search will fall back to FTS',
    );
  }

  // Every 15 min — intent-level payment reconciliation. Re-checks open gateway
  // intents whose webhook may have been missed (localhost dev; a dropped or
  // delayed delivery in prod): PAID → mark CAPTURED + settle (idempotent with
  // the webhook); definitively-unpaid past the abandon window → FAILED. The
  // liveness net for online collection. Unlike the DB-only jobs above, this hits
  // a rate-limited external API, so we best-effort lock to ONE instance per tick
  // (degrades open when Redis is down — correctness is settlement-idempotent
  // regardless). See PAYMENT_GATEWAY_ARCHITECTURE.md §8.
  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('gateway:reconcile-intents', async () => {
        // Lock TTL just under the interval so a held lock auto-releases before
        // the next tick rather than wedging the sweep.
        if (!(await tryAcquireJobLock('gateway:reconcile-intents', 14 * 60_000))) {
          return { skipped: 'lock held by another instance' };
        }
        return paymentGatewayService.reconcileStaleIntents();
      }),
    ),
  );

  // Every 15 min — transfer-level reconciliation for the Route on-hold split:
  // heal HELD rows whose provider transfer never landed (P1) and release holds
  // past their window whose child has no open return (P2). Only runs when the
  // split feature is on (no transfers exist otherwise). Same best-effort lock as
  // the intent sweep so only one instance polls Razorpay per tick.
  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('gateway:reconcile-transfers', async () => {
        if (!isRouteSplitEnabled()) return { skipped: 'route split disabled' };
        if (!(await tryAcquireJobLock('gateway:reconcile-transfers', 14 * 60_000))) {
          return { skipped: 'lock held by another instance' };
        }
        return reconcileStaleTransfers();
      }),
    ),
  );

  // Every 30 min — re-poll linked-account KYC for accounts not yet payout-
  // enabled, so a dropped/early account.activated webhook self-heals (the seller
  // would otherwise be stranded KYC_GATED). Flag-gated + lock-guarded.
  jobs.push(
    cron.schedule('*/30 * * * *', () =>
      runSafely('gateway:reconcile-kyc', async () => {
        if (!isRouteSplitEnabled()) return { skipped: 'route split disabled' };
        if (!(await tryAcquireJobLock('gateway:reconcile-kyc', 28 * 60_000))) {
          return { skipped: 'lock held by another instance' };
        }
        return linkedAccountsService.reconcilePendingKyc();
      }),
    ),
  );

  logger.info({ jobs: jobs.length }, 'scheduler started');
}

export function stopScheduler(): void {
  for (const j of jobs) {
    j.stop();
  }
  jobs.length = 0;
}
