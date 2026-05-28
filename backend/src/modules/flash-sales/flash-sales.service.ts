import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { CLAIM_FLASH_SALE_LUA } from '../../infra/redis/scripts/claim-flash-sale.js';

const REDIS_SOLD_KEY = (id: number) => `flash:${id}:sold`;
// Long TTL so a long-running sale's counter doesn't expire under us
// before the next 60s flush picks it up; refreshed on every increment.
const REDIS_SOLD_TTL_SECONDS = 60 * 60 * 24; // 24h

// Atomic claim — single round-trip, single-script-execution lock.
// Source lives in infra/redis/scripts/claim-flash-sale.ts so the same
// script can be shared with other modules that need it.
const CLAIM_LUA = CLAIM_FLASH_SALE_LUA;

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

    const writeResult = await prisma.flashSale.updateMany({
      where: { id, product: { shopId } },
      data: {
        ...(input.flashPrice !== undefined && { flashPrice: input.flashPrice }),
        ...(input.stockLimit !== undefined && { stockLimit: input.stockLimit }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
      },
    });
    if (writeResult.count === 0) return null;
    const updated = await prisma.flashSale.findFirst({
      where: { id, product: { shopId } },
      select: merchantSaleSelect,
    });
    if (!updated) return null;
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
  ///   1. Redis EVAL of CLAIM_LUA — GET + compare + INCRBY in a single
  ///      atomic script. No overshoot window: two concurrent claimers
  ///      can't both observe headroom and both succeed past the cap,
  ///      so we never have to "decrement back" phantom inventory.
  ///   2. Postgres conditional UPDATE … RETURNING — used when Redis is
  ///      offline. The `sold_count < stock_limit` predicate makes the
  ///      check-and-increment atomic at the row level.
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
      let result: number;
      try {
        result = (await client.eval(
          CLAIM_LUA,
          1,
          key,
          String(qty),
          String(sale.stockLimit),
          String(REDIS_SOLD_TTL_SECONDS),
        )) as number;
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'flash claim redis failed; falling back to DB conditional update');
        return this._claimViaDbConditional(sale.id, qty, flashPrice);
      }
      if (result === -1) {
        return { ok: false, reason: 'out_of_stock' };
      }
      return { ok: true, flashPrice, soldAfter: result };
    }

    return this._claimViaDbConditional(sale.id, qty, flashPrice);
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

  private async _claimViaDbConditional(
    saleId: number,
    qty: number,
    flashPrice: number,
  ): Promise<ClaimResult> {
    // Single-statement check-and-increment: the WHERE clause makes the
    // "is there room?" check race-safe at the row level, so we don't
    // need a SELECT … FOR UPDATE round-trip. Returns the new sold_count
    // when the increment took effect, or zero rows when no headroom.
    const rows = await prisma.$queryRaw<{ sold_count: number }[]>`
      UPDATE flash_sales
         SET sold_count = sold_count + ${qty}
       WHERE id = ${saleId}
         AND sold_count + ${qty} <= stock_limit
      RETURNING sold_count
    `;
    if (rows.length === 0) {
      // Either the row vanished (deactivated mid-claim) or stock ran
      // out. Disambiguate with one extra read so the caller can show
      // the right error — cheap relative to the failed write.
      const sale = await prisma.flashSale.findUnique({
        where: { id: saleId },
        select: { id: true },
      });
      return sale
        ? ({ ok: false, reason: 'out_of_stock' } satisfies ClaimResult)
        : ({ ok: false, reason: 'not_active' } satisfies ClaimResult);
    }
    return {
      ok: true,
      flashPrice,
      soldAfter: rows[0].sold_count,
    } satisfies ClaimResult;
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
