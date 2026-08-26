import cron, { ScheduledTask } from 'node-cron';
import { logger } from '../shared/logging/logger.js';
import { eventsService } from '../modules/events/events.service.js';
import { trendingService } from '../modules/trending/trending.service.js';
import { embeddingService } from '../modules/search/embedding.service.js';
import { productsService } from '../modules/products/products.service.js';
import { marketplaceService } from '../modules/marketplace/marketplace.service.js';
import { paymentGatewayService } from '../modules/payment-gateway/index.js';
import { reconcileStaleTransfers } from '../modules/payment-gateway/settlement/transfer-reconcile.js';
import { isRouteSplitEnabled } from '../modules/payment-gateway/settlement/order-split.js';
import { linkedAccountsService } from '../modules/linked-accounts/linked-accounts.service.js';
import { invitationsService } from '../modules/invitations/invitations.service.js';
import { sweepStaleSales } from '../modules/pos/pos.service.js';
import { runChangefeed, reconcileRecent } from '../modules/analytics-rollup/changefeed.service.js';
import { runOutboxRelay } from './outbox/relay.js';
import { tryAcquireJobLock } from './redis.js';

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

  jobs.push(
    cron.schedule('* * * * *', () =>
      runSafely('rollup:changefeed', async () => {
        if (!(await tryAcquireJobLock('rollup:changefeed', 55_000))) return { skipped: 'locked' };
        return runChangefeed();
      }),
    ),
  );

  jobs.push(
    cron.schedule('* * * * *', () =>
      runSafely('outbox:relay', () => runOutboxRelay()),
    ),
  );

  jobs.push(
    cron.schedule('50 20 * * *', () =>
      runSafely('rollup:reconcile', async () => {
        if (!(await tryAcquireJobLock('rollup:reconcile', 10 * 60_000))) return { skipped: 'locked' };
        return reconcileRecent(35);
      }),
    ),
  );

  jobs.push(
    cron.schedule('0 * * * *', () =>
      runSafely('events:trim-recently-viewed', () =>
        eventsService.trimRecentlyViewed(),
      ),
    ),
  );

  jobs.push(
    cron.schedule('30 * * * *', () =>
      runSafely('pos:sweep-stale-sales', () =>
        sweepStaleSales(new Date(Date.now() - 6 * 60 * 60 * 1000)),
      ),
    ),
  );

  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('trending:recompute', () => trendingService.recomputeWindow()),
    ),
  );

  jobs.push(
    cron.schedule('0 4 * * *', () =>
      runSafely('recs:rebuild-all', () =>
        trendingService.rebuildAllRecommendations(),
      ),
    ),
  );

  jobs.push(
    cron.schedule('0 3 * * *', () =>
      runSafely('events:prune-old', () => eventsService.pruneOldEvents()),
    ),
  );

  jobs.push(
    cron.schedule('0 3 * * *', () =>
      runSafely('products:refresh-sold-last-30d', () =>
        productsService.refreshSoldLast30d(),
      ),
    ),
  );

  jobs.push(
    cron.schedule('30 3 * * *', () =>
      runSafely('marketplace:recompute-fbt', () =>
        marketplaceService.recomputeFbtCache(),
      ),
    ),
  );

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

  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('gateway:reconcile-intents', async () => {
        if (!(await tryAcquireJobLock('gateway:reconcile-intents', 14 * 60_000))) {
          return { skipped: 'lock held by another instance' };
        }
        return paymentGatewayService.reconcileStaleIntents();
      }),
    ),
  );

  jobs.push(
    cron.schedule('*/15 * * * *', () =>
      runSafely('gateway:reconcile-refunds', async () => {
        if (!(await tryAcquireJobLock('gateway:reconcile-refunds', 14 * 60_000))) {
          return { skipped: 'lock held by another instance' };
        }
        return paymentGatewayService.reconcileStaleRefunds();
      }),
    ),
  );

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

  jobs.push(
    cron.schedule('0 * * * *', () =>
      runSafely('invitations:expire-stale', () =>
        invitationsService.expireStalePendingInvites(),
      ),
    ),
  );

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
