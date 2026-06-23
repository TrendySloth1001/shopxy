import prisma from '../db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { handlersFor } from './handlers.js';
import type { OutboxEnvelope } from './types.js';

/// The outbox relay: drains PENDING events and fans each out to its registered
/// handlers. Concurrency-safe across instances WITHOUT a distributed lock — the
/// claim uses `FOR UPDATE SKIP LOCKED`, so every app instance can drain in
/// parallel and they simply never hand each other the same row. (That is the
/// point: the relay scales horizontally, which a job-lock would defeat.)
///
/// Delivery is at-least-once: a handler may run more than once for an event
/// (e.g. process crash after the handler ran but before the row was marked
/// PUBLISHED), so handlers must be idempotent.

const CLAIM_BATCH = 100; // rows per claim
const MAX_DRAIN_BATCHES = 50; // ≤5000 events per tick — backstop against a runaway loop
const MAX_ATTEMPTS = 12; // then the row goes terminal FAILED (alert/inspect, don't retry forever)
const BASE_BACKOFF_SECONDS = 5;
const MAX_BACKOFF_SECONDS = 3600;
const STUCK_MINUTES = 5; // a PROCESSING row older than this is presumed crashed mid-dispatch

interface ClaimRow {
  id: bigint;
  aggregate_type: string;
  aggregate_id: string;
  event_type: string;
  shop_id: number | null;
  payload: unknown;
  attempts: number;
}

/// Reset rows wedged in PROCESSING by a crash between claim and completion, so
/// they get retried rather than stranded. Runs once at the start of each tick.
async function reapStuck(): Promise<void> {
  await prisma.$executeRaw`
    UPDATE "outbox_events"
       SET "status" = 'PENDING', "claimed_at" = NULL
     WHERE "status" = 'PROCESSING'
       AND "claimed_at" < now() - interval '5 minutes'`;
}

/// Atomically claim a batch: mark up to CLAIM_BATCH due PENDING rows PROCESSING
/// and return them. The inner `SELECT ... FOR UPDATE SKIP LOCKED` is what makes
/// this safe for many concurrent relays.
async function claim(): Promise<ClaimRow[]> {
  return prisma.$queryRaw<ClaimRow[]>`
    UPDATE "outbox_events"
       SET "status" = 'PROCESSING', "claimed_at" = now()
     WHERE "id" IN (
       SELECT "id" FROM "outbox_events"
        WHERE "status" = 'PENDING' AND "available_at" <= now()
        ORDER BY "id"
        FOR UPDATE SKIP LOCKED
        LIMIT ${CLAIM_BATCH}
     )
     RETURNING "id", "aggregate_type", "aggregate_id", "event_type",
               "shop_id", "payload", "attempts"`;
}

async function markPublished(id: bigint): Promise<void> {
  await prisma.$executeRaw`
    UPDATE "outbox_events"
       SET "status" = 'PUBLISHED', "published_at" = now(), "last_error" = NULL
     WHERE "id" = ${id}`;
}

async function markFailed(row: ClaimRow, message: string): Promise<void> {
  const attempts = row.attempts + 1;
  const truncated = message.slice(0, 1000);
  if (attempts >= MAX_ATTEMPTS) {
    // Terminal — stop retrying. The nightly reconcile still heals the roll-up;
    // a FAILED row is a signal to inspect, not a silent data loss.
    await prisma.$executeRaw`
      UPDATE "outbox_events"
         SET "status" = 'FAILED', "attempts" = ${attempts}, "last_error" = ${truncated}
       WHERE "id" = ${row.id}`;
    logger.error(
      { id: Number(row.id), eventType: row.event_type, attempts },
      'outbox: event reached terminal FAILED',
    );
    return;
  }
  const backoff = Math.min(MAX_BACKOFF_SECONDS, BASE_BACKOFF_SECONDS * 2 ** (attempts - 1));
  await prisma.$executeRaw`
    UPDATE "outbox_events"
       SET "status" = 'PENDING',
           "attempts" = ${attempts},
           "last_error" = ${truncated},
           "claimed_at" = NULL,
           "available_at" = now() + make_interval(secs => ${backoff})
     WHERE "id" = ${row.id}`;
}

async function dispatch(row: ClaimRow): Promise<boolean> {
  const envelope: OutboxEnvelope = {
    id: row.id,
    aggregateType: row.aggregate_type,
    aggregateId: row.aggregate_id,
    eventType: row.event_type,
    shopId: row.shop_id,
    payload:
      row.payload && typeof row.payload === 'object'
        ? (row.payload as Record<string, unknown>)
        : {},
  };
  // No handlers registered for this type → still "delivered" (to zero
  // consumers). The row is retained as PUBLISHED so the log stays complete;
  // marking it published avoids an unhandled event spinning forever.
  try {
    for (const handler of handlersFor(envelope.eventType)) {
      await handler(envelope);
    }
    await markPublished(row.id);
    return true;
  } catch (err) {
    await markFailed(row, (err as Error).message);
    return false;
  }
}

/// Drain the outbox. Called every tick by the scheduler; loops until the log is
/// empty or the per-tick batch cap is hit (whichever comes first).
export async function runOutboxRelay(): Promise<{
  published: number;
  failed: number;
  batches: number;
}> {
  await reapStuck();

  let published = 0;
  let failed = 0;
  let batches = 0;

  for (; batches < MAX_DRAIN_BATCHES; batches += 1) {
    const rows = await claim();
    if (rows.length === 0) break;
    for (const row of rows) {
      if (await dispatch(row)) published += 1;
      else failed += 1;
    }
  }

  return { published, failed, batches };
}
