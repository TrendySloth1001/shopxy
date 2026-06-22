import prisma from '../../infra/db/prisma.js';
import { recomputeDay } from './aggregates.recompute.js';
import { logger } from '../../shared/logging/logger.js';

/// Roll-up maintenance: a cron changefeed recomputes each (shop, day) whose
/// source rows changed since a watermark; a nightly reconcile + one-time backfill
/// heal any miss. All idempotent (recomputeDay delete-then-inserts).

const CURSOR_NAME = 'main';
const BATCH = 8; // concurrent recomputes per wave

// day_key is YYYY-MM-DD (IST) as TEXT — we build the UTC-midnight Date in JS to
// avoid node-postgres parsing `::date` at the machine's LOCAL midnight, which
// would shift every day by the IST offset.
type DirtyRow = { shop_id: number; day_key: string };

async function recomputeAll(pairs: DirtyRow[]): Promise<number> {
  let done = 0;
  for (let i = 0; i < pairs.length; i += BATCH) {
    const wave = pairs.slice(i, i + BATCH);
    await Promise.all(
      wave.map(async (r) => {
        const day = new Date(`${r.day_key}T00:00:00.000Z`);
        try {
          await recomputeDay(r.shop_id, day);
          done += 1;
        } catch (err) {
          logger.warn({ err: (err as Error).message, shopId: r.shop_id, day: r.day_key }, 'rollup recompute failed');
        }
      }),
    );
  }
  return done;
}

/// Incremental: recompute (shop, day) for rows changed since the cursor.
export async function runChangefeed(): Promise<{ days: number }> {
  const runStart = new Date();
  const cursorRow = await prisma.aggChangefeedCursor.findUnique({ where: { name: CURSOR_NAME } });
  const cursor = cursorRow?.cursorAt ?? new Date(runStart.getTime() - 10 * 60 * 1000);

  const pairs = await prisma.$queryRaw<DirtyRow[]>`
    SELECT DISTINCT shop_id, to_char(date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM invoices WHERE updated_at > ${cursor}
    UNION
    SELECT DISTINCT shop_id, to_char(date_trunc('day', payment_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM payments WHERE updated_at > ${cursor}
    UNION
    SELECT DISTINCT shop_id, to_char(date_trunc('day', created_at AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM stock_adjustments WHERE created_at > ${cursor}
    UNION
    SELECT DISTINCT i.shop_id, to_char(date_trunc('day', i.invoice_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM return_requests rr
      JOIN purchase_requests pr ON pr.id = rr.request_id
      JOIN invoices i ON i.id = pr.invoice_id
     WHERE rr.updated_at > ${cursor}`;

  const days = await recomputeAll(pairs);

  // Overlap by 30s so a row committed mid-run isn't skipped next tick.
  const next = new Date(runStart.getTime() - 30 * 1000);
  await prisma.aggChangefeedCursor.upsert({
    where: { name: CURSOR_NAME },
    create: { name: CURSOR_NAME, cursorAt: next },
    update: { cursorAt: next },
  });
  return { days };
}

/// Recompute every (shop, day) with activity since `since` (omit = all history).
/// Used for the one-time backfill and the nightly reconcile.
export async function backfillAll(since?: Date): Promise<{ days: number }> {
  const floor = since ?? new Date(0);
  const pairs = await prisma.$queryRaw<DirtyRow[]>`
    SELECT DISTINCT shop_id, to_char(date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM invoices WHERE status = 'CONFIRMED' AND invoice_date >= ${floor}
    UNION
    SELECT DISTINCT shop_id, to_char(date_trunc('day', payment_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM payments WHERE voided_at IS NULL AND payment_date >= ${floor}
    UNION
    SELECT DISTINCT shop_id, to_char(date_trunc('day', created_at AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM stock_adjustments WHERE created_at >= ${floor}
    UNION
    SELECT DISTINCT i.shop_id, to_char(date_trunc('day', i.invoice_date AT TIME ZONE 'Asia/Kolkata'), 'YYYY-MM-DD') AS day_key
      FROM return_requests rr
      JOIN purchase_requests pr ON pr.id = rr.request_id
      JOIN invoices i ON i.id = pr.invoice_id
     WHERE rr.status = 'REFUNDED' AND i.invoice_date >= ${floor}`;
  const days = await recomputeAll(pairs);
  return { days };
}

/// Nightly safety net — recompute a trailing window to heal any missed tick.
export async function reconcileRecent(days = 35): Promise<{ days: number }> {
  return backfillAll(new Date(Date.now() - days * 24 * 60 * 60 * 1000));
}
