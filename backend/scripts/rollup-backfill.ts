import { backfillAll } from '../src/modules/analytics-rollup/changefeed.service.js';
import { logger } from '../src/shared/logging/logger.js';

(async () => {
  const t0 = Date.now();
  logger.info('rollup backfill: starting full history');
  const { days } = await backfillAll();
  logger.info({ days, ms: Date.now() - t0 }, 'rollup backfill: done');
  process.exit(0);
})().catch((err) => {
  logger.error({ err: (err as Error).message }, 'rollup backfill: failed');
  process.exit(1);
});
