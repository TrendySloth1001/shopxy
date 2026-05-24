import { ProductEventType, Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

/// Event ingestion (P5).
///
/// Contract:
///   * Clients (customer app, web shell) buffer events locally and
///     POST them in batches. Each event has a `clientUuid` — if the
///     POST is retried, the unique index makes the second attempt a
///     no-op, so retries are safe.
///   * VIEW events also bump RecentlyViewed for the originating user.
///     The 20-row cap is enforced by an hourly trim cron — we tolerate
///     a brief overshoot rather than paying a DELETE on every ingest.
///   * Raw events older than 90 days are dropped by a daily prune
///     cron. Anything that needs to outlive that window is computed
///     into a separate aggregates table (trending / analytics).

export interface IncomingEvent {
  clientUuid: string;
  eventType: ProductEventType;
  productId: number;
  sessionId?: string | null;
  source?: string | null;
  meta?: unknown;
  /// Caller-supplied. Allows offline buffers to preserve original
  /// timestamps when they sync later.
  occurredAt: Date;
}

export interface IngestResult {
  /// Rows that we attempted to insert after pre-flight filtering
  /// (unknown productIds dropped).
  attempted: number;
  /// Newly persisted rows — Postgres returned a `count` from
  /// createMany. The delta against `attempted` is duplicates.
  inserted: number;
  /// `attempted - inserted` — convenience for clients showing
  /// "we already had N of these".
  deduped: number;
  /// productIds the caller submitted that we don't recognise. The
  /// service drops the event silently (HTTP doesn't 4xx the whole
  /// batch over one stale id) but reports them back so clients can
  /// prune their local buffers.
  unknownProductIds: number[];
}

const RECENT_PER_USER_CAP = 20;
const PRUNE_OLDER_THAN_DAYS = 90;

export class EventsService {
  /// Batch-insert events. `userId` is the authenticated caller (taken
  /// from the JWT, never from the body). All events in a batch land
  /// under that user; mixing users in one batch would let a client
  /// fabricate someone else's activity.
  async ingest(events: IncomingEvent[], userId: number): Promise<IngestResult> {
    if (events.length === 0) {
      return { attempted: 0, inserted: 0, deduped: 0, unknownProductIds: [] };
    }

    // Pre-flight: filter out events whose productId doesn't exist.
    // Doing this in one query keeps it O(1) round-trips no matter
    // how many distinct products the batch references.
    const productIds = [...new Set(events.map((e) => e.productId))];
    const known = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true },
    });
    const knownSet = new Set(known.map((r) => r.id));
    const unknown = productIds.filter((id) => !knownSet.has(id));
    const valid = events.filter((e) => knownSet.has(e.productId));

    if (valid.length === 0) {
      return {
        attempted: 0,
        inserted: 0,
        deduped: 0,
        unknownProductIds: unknown,
      };
    }

    const data: Prisma.ProductEventCreateManyInput[] = valid.map((e) => ({
      clientUuid: e.clientUuid,
      eventType: e.eventType,
      productId: e.productId,
      userId,
      sessionId: e.sessionId ?? null,
      source: e.source ?? null,
      meta: e.meta === undefined ? Prisma.DbNull : (e.meta as Prisma.InputJsonValue),
      occurredAt: e.occurredAt,
    }));

    // skipDuplicates makes retries safe — the unique index on
    // client_uuid swallows the conflict at insert time. The
    // returned `count` is real inserts; missing rows are duplicates.
    const { count } = await prisma.productEvent.createMany({
      data,
      skipDuplicates: true,
    });

    // Side-effect: bump RecentlyViewed for VIEW events. We do this
    // even when the row was a duplicate insert — the user did look
    // again. Dedupe inside the batch on (userId, productId) so the
    // upsert is a single round-trip per distinct product.
    const viewedProductIds = new Set<number>();
    let mostRecentByProduct = new Map<number, Date>();
    for (const e of valid) {
      if (e.eventType !== ProductEventType.VIEW) continue;
      viewedProductIds.add(e.productId);
      const prior = mostRecentByProduct.get(e.productId);
      if (!prior || e.occurredAt > prior) {
        mostRecentByProduct.set(e.productId, e.occurredAt);
      }
    }
    if (viewedProductIds.size > 0) {
      await Promise.all(
        Array.from(viewedProductIds).map((productId) =>
          prisma.recentlyViewed.upsert({
            where: { userId_productId: { userId, productId } },
            create: {
              userId,
              productId,
              lastViewedAt: mostRecentByProduct.get(productId) ?? new Date(),
            },
            update: {
              lastViewedAt: mostRecentByProduct.get(productId) ?? new Date(),
            },
          }),
        ),
      );
    }

    return {
      attempted: valid.length,
      inserted: count,
      deduped: valid.length - count,
      unknownProductIds: unknown,
    };
  }

  /// Caller-scoped recently-viewed list. Returns most-recently-viewed
  /// first, with a light product summary so the customer rail can
  /// render without a separate per-product fetch.
  async listRecentlyViewed(userId: number, limit = RECENT_PER_USER_CAP) {
    return prisma.recentlyViewed.findMany({
      where: { userId },
      orderBy: { lastViewedAt: 'desc' },
      take: limit,
      select: {
        id: true,
        lastViewedAt: true,
        product: {
          select: {
            id: true,
            name: true,
            sku: true,
            sellingPrice: true,
            mrp: true,
            ratingAvg: true,
            ratingCount: true,
            isPublished: true,
            shop: { select: { id: true, name: true, slug: true } },
            images: {
              select: { url: true, sortOrder: true },
              orderBy: { sortOrder: 'asc' },
              take: 1,
            },
          },
        },
      },
    });
  }

  // ── Cron jobs ────────────────────────────────────────────────────

  /// Daily — drop raw events older than 90 days. Aggregates that need
  /// to outlive the raw row land in trending / analytics tables.
  async pruneOldEvents(): Promise<{ deleted: number }> {
    const cutoff = new Date(Date.now() - PRUNE_OLDER_THAN_DAYS * 86_400_000);
    const result = await prisma.productEvent.deleteMany({
      where: { occurredAt: { lt: cutoff } },
    });
    logger.info(
      { deleted: result.count, cutoff: cutoff.toISOString() },
      'pruned old product events',
    );
    return { deleted: result.count };
  }

  /// Hourly — enforce the per-user RecentlyViewed cap. We do this in
  /// one SQL pass via a window-function CTE; cheaper than per-user
  /// loops once you have meaningful traffic.
  async trimRecentlyViewed(): Promise<{ deleted: number }> {
    const result = await prisma.$executeRawUnsafe(`
      DELETE FROM "recently_viewed"
      WHERE "id" IN (
        SELECT "id" FROM (
          SELECT "id",
                 ROW_NUMBER() OVER (
                   PARTITION BY "user_id"
                   ORDER BY "last_viewed_at" DESC, "id" DESC
                 ) AS rn
          FROM "recently_viewed"
        ) ranked
        WHERE ranked.rn > ${RECENT_PER_USER_CAP}
      )
    `);
    logger.info({ deleted: result }, 'trimmed recently_viewed');
    return { deleted: Number(result) };
  }
}

export const eventsService = new EventsService();
