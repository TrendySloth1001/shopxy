import { ProductEventType, Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

export interface IncomingEvent {
  clientUuid: string;
  eventType: ProductEventType;
  productId: number;
  sessionId?: string | null;
  source?: string | null;
  meta?: unknown;
  occurredAt: Date;
}

export interface IngestResult {
  attempted: number;
  inserted: number;
  deduped: number;
  unknownProductIds: number[];
}

const RECENT_PER_USER_CAP = 20;
const PRUNE_OLDER_THAN_DAYS = 90;

export class EventsService {
  async ingest(events: IncomingEvent[], userId: number): Promise<IngestResult> {
    if (events.length === 0) {
      return { attempted: 0, inserted: 0, deduped: 0, unknownProductIds: [] };
    }

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

    const { count } = await prisma.productEvent.createMany({
      data,
      skipDuplicates: true,
    });

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
