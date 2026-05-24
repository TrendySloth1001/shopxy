import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

const REDIS_SOLD_KEY = (id: number) => `flash:${id}:sold`;
// Long TTL so a long-running sale's counter doesn't expire under us
// before the next 60s flush picks it up; refreshed on every increment.
const REDIS_SOLD_TTL_SECONDS = 60 * 60 * 24; // 24h

const publicSaleSelect = {
  id: true,
  productId: true,
  flashPrice: true,
  stockLimit: true,
  soldCount: true,
  startAt: true,
  endAt: true,
} as const;

const merchantSaleSelect = {
  ...publicSaleSelect,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  product: {
    select: {
      id: true,
      name: true,
      sku: true,
      mrp: true,
      sellingPrice: true,
      images: { take: 1, orderBy: { sortOrder: 'asc' as const } },
    },
  },
} as const;

export interface CreateFlashSaleInput {
  productId: number;
  flashPrice: number;
  stockLimit: number;
  startAt: Date;
  endAt: Date;
}

export interface UpdateFlashSaleInput {
  flashPrice?: number;
  stockLimit?: number;
  startAt?: Date;
  endAt?: Date;
  isActive?: boolean;
}

export type ClaimResult =
  | { ok: true; flashPrice: number; soldAfter: number }
  | { ok: false; reason: 'out_of_stock' | 'not_active' };

export class FlashSalesService {
  /// Merchant CRUD — all reads/writes scoped to the caller's shop via
  /// a where-join on Product.shopId so a competitor can't probe ids.

  async listForShop(
    shopId: number,
    opts: { status?: 'active' | 'scheduled' | 'past' | 'all' } = {},
  ) {
    const now = new Date();
    const where: Prisma.FlashSaleWhereInput = {
      product: { shopId },
    };
    if (opts.status === 'active') {
      where.isActive = true;
      where.startAt = { lte: now };
      where.endAt = { gte: now };
    } else if (opts.status === 'scheduled') {
      where.isActive = true;
      where.startAt = { gt: now };
    } else if (opts.status === 'past') {
      where.OR = [{ endAt: { lt: now } }, { isActive: false }];
    }
    const rows = await prisma.flashSale.findMany({
      where,
      orderBy: [{ startAt: 'desc' }, { id: 'desc' }],
      select: merchantSaleSelect,
    });
    // Hydrate each row's soldCount from Redis (the live counter is the
    // truth between the every-60s flush windows). Cheap pipelined MGET.
    return this._mergeRedisSold(rows);
  }

  async getById(shopId: number, id: number) {
    const row = await prisma.flashSale.findFirst({
      where: { id, product: { shopId } },
      select: merchantSaleSelect,
    });
    if (!row) return null;
    const merged = await this._mergeRedisSold([row]);
    return merged[0];
  }

  async create(shopId: number, input: CreateFlashSaleInput) {
    // Ownership check: the product must belong to the caller's shop.
    // Without this, any merchant could create a flash sale on another
    // shop's product (which would then surface under that shop on the
    // marketplace, breaking attribution + pricing).
    const owned = await prisma.product.findFirst({
      where: { id: input.productId, shopId },
      select: { id: true },
    });
    if (!owned) return { error: 'product_not_in_shop' as const };

    if (input.endAt <= input.startAt) return { error: 'invalid_window' as const };
    if (input.stockLimit <= 0) return { error: 'invalid_stock_limit' as const };
    if (input.flashPrice < 0) return { error: 'invalid_price' as const };

    try {
      const row = await prisma.flashSale.create({
        data: {
          shopId,
          productId: input.productId,
          flashPrice: input.flashPrice,
          stockLimit: input.stockLimit,
          startAt: input.startAt,
          endAt: input.endAt,
          isActive: true,
        },
        select: merchantSaleSelect,
      });
      return { sale: row };
    } catch (err) {
      // The partial unique index trips with code P2002 when an active
      // sale already exists for this product. Translate to a friendlier
      // error so the UI can suggest "cancel the existing sale first".
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        return { error: 'active_sale_exists' as const };
      }
      throw err;
    }
  }

  async update(shopId: number, id: number, input: UpdateFlashSaleInput) {
    const existing = await prisma.flashSale.findFirst({
      where: { id, product: { shopId } },
      select: { id: true, startAt: true, endAt: true },
    });
    if (!existing) return null;

    const startAt = input.startAt ?? existing.startAt;
    const endAt = input.endAt ?? existing.endAt;
    if (endAt <= startAt) return { error: 'invalid_window' as const };

    const updated = await prisma.flashSale.update({
      where: { id },
      data: {
        ...(input.flashPrice !== undefined && { flashPrice: input.flashPrice }),
        ...(input.stockLimit !== undefined && { stockLimit: input.stockLimit }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
      },
      select: merchantSaleSelect,
    });
    const merged = await this._mergeRedisSold([updated]);
    return { sale: merged[0] };
  }

  /// Cancel = set isActive=false. The partial unique index then lets a
  /// new active sale be created for the same product immediately.
  async cancel(shopId: number, id: number) {
    return this.update(shopId, id, { isActive: false });
  }

  // ── Public read ─────────────────────────────────────────────────

  async listActivePublic(opts: { limit?: number } = {}) {
    const now = new Date();
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const rows = await prisma.flashSale.findMany({
      where: {
        isActive: true,
        startAt: { lte: now },
        endAt: { gte: now },
      },
      orderBy: [{ endAt: 'asc' }, { id: 'asc' }],
      take: limit,
      select: {
        ...publicSaleSelect,
        product: {
          select: {
            id: true,
            name: true,
            mrp: true,
            sellingPrice: true,
            ratingAvg: true,
            ratingCount: true,
            images: { take: 1, orderBy: { sortOrder: 'asc' as const } },
          },
        },
      },
    });
    return this._mergeRedisSold(rows);
  }

  // ── Checkout helpers (race-safe) ────────────────────────────────

  /// Resolves the active sale for a product right now. Used both by
  /// the public read (to show flash price on PDP) and by checkout (to
  /// decide whether to claim before billing).
  async resolveActiveSale(productId: number) {
    const now = new Date();
    return prisma.flashSale.findFirst({
      where: {
        productId,
        isActive: true,
        startAt: { lte: now },
        endAt: { gte: now },
      },
      select: { id: true, flashPrice: true, stockLimit: true, soldCount: true },
    });
  }

  /// Atomic claim of N units against the running sale. Two layers of
  /// protection:
  ///   1. Redis INCRBY — single round-trip arithmetic over the
  ///      authoritative live counter. Decremented again on overflow so
  ///      retries don't bleed phantom inventory.
  ///   2. Postgres SELECT … FOR UPDATE — only consulted in the rare
  ///      "Redis offline" case; otherwise we trust Redis between flushes.
  ///
  /// Returns `{ ok: true, flashPrice, soldAfter }` on success, or
  /// `{ ok: false, reason }` so the caller can map to a 409/410 without
  /// throwing.
  async claim(productId: number, qty: number): Promise<ClaimResult> {
    if (qty <= 0) return { ok: false, reason: 'not_active' };

    const sale = await this.resolveActiveSale(productId);
    if (!sale) return { ok: false, reason: 'not_active' };
    const flashPrice = Number(sale.flashPrice);

    if (redisAvailable()) {
      const key = REDIS_SOLD_KEY(sale.id);
      const client = getRedis();
      // INCRBY returns the new total atomically. If we overshoot the
      // cap we DECR back the same amount so other in-flight callers
      // see the true headroom on their own attempt.
      let newTotal: number;
      try {
        newTotal = await client.incrby(key, qty);
        await client.expire(key, REDIS_SOLD_TTL_SECONDS);
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'flash claim redis failed; falling back to DB lock');
        return this._claimViaDbLock(sale.id, qty, flashPrice);
      }
      if (newTotal > sale.stockLimit) {
        await client.decrby(key, qty).catch(() => undefined);
        return { ok: false, reason: 'out_of_stock' };
      }
      return { ok: true, flashPrice, soldAfter: newTotal };
    }

    return this._claimViaDbLock(sale.id, qty, flashPrice);
  }

  /// Releases N units back to the counter — used when a checkout that
  /// already claimed rolls back (payment failure, validation error).
  /// Mirrors `claim`: Redis fast path when available, Postgres
  /// SELECT … FOR UPDATE otherwise. Without the DB fallback a release
  /// done while Redis is offline would leak inventory permanently.
  async release(productId: number, qty: number): Promise<void> {
    if (qty <= 0) return;
    const sale = await this.resolveActiveSale(productId);
    if (!sale) return;
    if (redisAvailable()) {
      // DECRBY can drive the counter negative if a release exceeds
      // outstanding claims — clamp at zero so the next claim doesn't
      // see negative headroom.
      const client = getRedis();
      const after = await client.decrby(REDIS_SOLD_KEY(sale.id), qty).catch(() => null);
      if (typeof after === 'number' && after < 0) {
        await client.set(REDIS_SOLD_KEY(sale.id), '0').catch(() => undefined);
      }
      return;
    }
    await prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<{ sold_count: number }[]>`
        SELECT sold_count FROM flash_sales WHERE id = ${sale.id} FOR UPDATE
      `;
      if (locked.length === 0) return;
      const next = Math.max(0, locked[0].sold_count - qty);
      await tx.flashSale.update({
        where: { id: sale.id },
        data: { soldCount: next },
      });
    });
  }

  /// Persist the live Redis counters back to Postgres. Called by cron
  /// every 60s. Iterates active sales only — completed sales already
  /// have their final count saved at deactivation.
  async flushSoldCountersToDb(): Promise<{ flushed: number }> {
    if (!redisAvailable()) return { flushed: 0 };
    const active = await prisma.flashSale.findMany({
      where: { isActive: true },
      select: { id: true, soldCount: true },
    });
    let flushed = 0;
    const client = getRedis();
    for (const s of active) {
      try {
        const live = await client.get(REDIS_SOLD_KEY(s.id));
        if (live == null) continue;
        const liveN = Number(live);
        if (!Number.isFinite(liveN) || liveN === s.soldCount) continue;
        await prisma.flashSale.update({
          where: { id: s.id },
          data: { soldCount: liveN },
        });
        flushed++;
      } catch (err) {
        logger.warn({ saleId: s.id, err: (err as Error).message }, 'flash flush failed');
      }
    }
    return { flushed };
  }

  /// Deactivates flash sales whose end window has passed. Final
  /// soldCount has already been kept fresh by the flush job, so this
  /// is just a flag flip. Returns the count touched.
  async sweepExpired(): Promise<{ deactivated: number }> {
    const result = await prisma.flashSale.updateMany({
      where: { isActive: true, endAt: { lt: new Date() } },
      data: { isActive: false },
    });
    return { deactivated: result.count };
  }

  // ── Private helpers ─────────────────────────────────────────────

  private async _claimViaDbLock(
    saleId: number,
    qty: number,
    flashPrice: number,
  ): Promise<ClaimResult> {
    // Pessimistic path: SELECT … FOR UPDATE inside a tx serialises
    // concurrent claims against the same sale. Slower than the Redis
    // path but guarantees correctness when Redis is offline.
    return prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<
        { id: number; stock_limit: number; sold_count: number }[]
      >`SELECT id, stock_limit, sold_count FROM flash_sales WHERE id = ${saleId} FOR UPDATE`;
      if (locked.length === 0) {
        return { ok: false, reason: 'not_active' } satisfies ClaimResult;
      }
      const next = locked[0].sold_count + qty;
      if (next > locked[0].stock_limit) {
        return { ok: false, reason: 'out_of_stock' } satisfies ClaimResult;
      }
      await tx.flashSale.update({
        where: { id: saleId },
        data: { soldCount: next },
      });
      return { ok: true, flashPrice, soldAfter: next } satisfies ClaimResult;
    });
  }

  /// MGET the live counters for a page of sales and overwrite the
  /// (potentially stale) DB soldCount in the returned objects. Keeps
  /// the admin UI showing the true live "% claimed" between flushes.
  private async _mergeRedisSold<T extends { id: number; soldCount: number }>(
    rows: T[],
  ): Promise<T[]> {
    if (!redisAvailable() || rows.length === 0) return rows;
    try {
      const keys = rows.map((r) => REDIS_SOLD_KEY(r.id));
      const live = await getRedis().mget(...keys);
      return rows.map((r, i) => {
        const v = live[i];
        if (v == null) return r;
        const n = Number(v);
        if (!Number.isFinite(n)) return r;
        return { ...r, soldCount: n };
      });
    } catch {
      return rows;
    }
  }
}

export const flashSalesService = new FlashSalesService();
