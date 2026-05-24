import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

/// Paid promotions (P9).
///
/// CPM billing — `cpmPaise` paise per 1000 impressions. The merchant
/// sets a total `budgetPaise` + a `dailyCapPaise`. The recorder bumps
/// counters; the same path auto-pauses when either limit is hit so the
/// next impression skips this promotion at injection time.
///
/// Sponsored injection ratio is the locked-in 1-in-5 (Phase 9 decision).
/// `injectSponsoredIntoRail` does the work: it takes a non-sponsored
/// list (e.g. the trending rail) and returns the merged sequence with
/// `isAd: true` flags at every 5th slot.

const SPONSORED_RATIO = 5; // 1 sponsored per 5 organic = the locked decision

const merchantSelect = {
  id: true,
  shopId: true,
  productId: true,
  budgetPaise: true,
  dailyCapPaise: true,
  cpmPaise: true,
  startAt: true,
  endAt: true,
  isActive: true,
  deliveredImpressions: true,
  spendPaise: true,
  spendTodayPaise: true,
  spendTodayDate: true,
  pausedReason: true,
  createdAt: true,
  updatedAt: true,
  product: { select: { id: true, name: true, sku: true, sellingPrice: true } },
} as const;

export interface CreatePromotionInput {
  shopId: number;
  productId: number;
  budgetPaise: number;
  dailyCapPaise: number;
  cpmPaise: number;
  startAt: Date;
  endAt: Date;
}

export interface UpdatePromotionInput {
  budgetPaise?: number;
  dailyCapPaise?: number;
  cpmPaise?: number;
  startAt?: Date;
  endAt?: Date;
  isActive?: boolean;
}

function todayInUtcDateOnly(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export class PromotionsService {
  // ── Merchant CRUD ─────────────────────────────────────────────────

  /// Verify the product belongs to the caller's shop before creating
  /// — prevents a malicious merchant from spending budget on someone
  /// else's product.
  async create(input: CreatePromotionInput) {
    const product = await prisma.product.findUnique({
      where: { id: input.productId },
      select: { shopId: true },
    });
    if (!product || product.shopId !== input.shopId) {
      const err = new Error('Product not found in this shop');
      (err as Error & { statusCode?: number }).statusCode = 404;
      throw err;
    }
    return prisma.promotion.create({
      data: {
        shopId: input.shopId,
        productId: input.productId,
        budgetPaise: input.budgetPaise,
        dailyCapPaise: input.dailyCapPaise,
        cpmPaise: input.cpmPaise,
        startAt: input.startAt,
        endAt: input.endAt,
      },
      select: merchantSelect,
    });
  }

  async listForShop(shopId: number) {
    return prisma.promotion.findMany({
      where: { shopId },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
      select: merchantSelect,
    });
  }

  async getById(shopId: number, id: number) {
    const row = await prisma.promotion.findUnique({
      where: { id },
      select: merchantSelect,
    });
    if (!row || row.shopId !== shopId) return null;
    return row;
  }

  async update(shopId: number, id: number, input: UpdatePromotionInput) {
    const existing = await prisma.promotion.findUnique({
      where: { id },
      select: { shopId: true },
    });
    if (!existing || existing.shopId !== shopId) return null;
    return prisma.promotion.update({
      where: { id },
      data: {
        ...(input.budgetPaise !== undefined && { budgetPaise: input.budgetPaise }),
        ...(input.dailyCapPaise !== undefined && { dailyCapPaise: input.dailyCapPaise }),
        ...(input.cpmPaise !== undefined && { cpmPaise: input.cpmPaise }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.isActive !== undefined && {
          isActive: input.isActive,
          // Manually re-activating clears the auto-pause reason.
          ...(input.isActive ? { pausedReason: null } : {}),
        }),
      },
      select: merchantSelect,
    });
  }

  async cancel(shopId: number, id: number): Promise<boolean> {
    const existing = await prisma.promotion.findUnique({
      where: { id },
      select: { shopId: true },
    });
    if (!existing || existing.shopId !== shopId) return false;
    await prisma.promotion.update({
      where: { id },
      data: { isActive: false, pausedReason: 'cancelled_by_merchant' },
    });
    return true;
  }

  // ── Impression accounting ────────────────────────────────────────

  /// Bump delivered + spend counters by `count` impressions and
  /// auto-pause if either limit is hit. Inline check + the hourly
  /// sweep give belt-and-braces guarantees.
  ///
  /// Per-day reset: when `spendTodayDate` doesn't match today's UTC
  /// date, we reset `spendTodayPaise` to 0 before adding. Day rollover
  /// is detected on first impression of a new day; no cron needed.
  async recordImpressions(promotionId: number, count: number) {
    if (count <= 0) return null;

    return prisma.$transaction(async (tx) => {
      const row = await tx.promotion.findUnique({
        where: { id: promotionId },
      });
      if (!row) return null;
      if (!row.isActive) return row;

      const today = todayInUtcDateOnly();
      const isNewDay =
        row.spendTodayDate === null ||
        row.spendTodayDate.getTime() !== today.getTime();

      const addSpend = Math.floor((count * row.cpmPaise) / 1000);
      const newSpend = row.spendPaise + addSpend;
      const newSpendToday = (isNewDay ? 0 : row.spendTodayPaise) + addSpend;
      const newDelivered = row.deliveredImpressions + count;

      let isActive = true;
      let pausedReason: string | null = null;
      if (newSpend >= row.budgetPaise) {
        isActive = false;
        pausedReason = 'budget_exhausted';
      } else if (newSpendToday >= row.dailyCapPaise) {
        isActive = false;
        pausedReason = 'daily_cap_reached';
      }

      const updated = await tx.promotion.update({
        where: { id: promotionId },
        data: {
          deliveredImpressions: newDelivered,
          spendPaise: newSpend,
          spendTodayPaise: newSpendToday,
          spendTodayDate: today,
          isActive,
          pausedReason,
        },
        select: merchantSelect,
      });
      if (!isActive) {
        logger.info(
          { promotionId, reason: pausedReason, spendPaise: newSpend },
          'promotion auto-paused',
        );
      }
      return updated;
    });
  }

  // ── Sponsored rail injection ─────────────────────────────────────

  /// Picks up to `count` active, in-window promotions whose product is
  /// still published. Weighted toward promotions with more remaining
  /// budget so newer / better-funded campaigns don't get starved by an
  /// old-but-low-budget one.
  async pickSponsored(opts: {
    count: number;
    excludeProductIds?: number[];
  }): Promise<Array<{ promotionId: number; productId: number }>> {
    const now = new Date();
    const candidates = await prisma.promotion.findMany({
      where: {
        isActive: true,
        startAt: { lte: now },
        endAt: { gte: now },
        product: { isPublished: true, isActive: true },
        ...(opts.excludeProductIds && opts.excludeProductIds.length > 0
          ? { productId: { notIn: opts.excludeProductIds } }
          : {}),
      },
      select: {
        id: true,
        productId: true,
        budgetPaise: true,
        spendPaise: true,
      },
    });
    if (candidates.length === 0) return [];

    // Weighted-without-replacement sample. Weight = remaining budget
    // (paise); guards against negative remaining via Math.max.
    const pool = candidates.map((c) => ({
      promotionId: c.id,
      productId: c.productId,
      weight: Math.max(1, c.budgetPaise - c.spendPaise),
    }));

    const picked: Array<{ promotionId: number; productId: number }> = [];
    const N = Math.min(opts.count, pool.length);
    for (let i = 0; i < N; i++) {
      const totalWeight = pool.reduce((s, p) => s + p.weight, 0);
      let pick = Math.random() * totalWeight;
      let idx = 0;
      for (; idx < pool.length; idx++) {
        pick -= pool[idx].weight;
        if (pick <= 0) break;
      }
      idx = Math.min(idx, pool.length - 1);
      const chosen = pool.splice(idx, 1)[0];
      picked.push({ promotionId: chosen.promotionId, productId: chosen.productId });
    }
    return picked;
  }

  /// Merge sponsored rows into an organic list at the locked 1-in-5
  /// ratio (slots 0, 5, 10, … become sponsored). Returns the merged
  /// sequence so the caller can render `isAd` chips inline.
  async injectSponsoredIntoRail<T extends { id: number }>(
    organic: T[],
    enrich: (item: { promotionId: number; productId: number }) =>
      | Promise<(T & { isAd: true; promotionId: number }) | null>
      | (T & { isAd: true; promotionId: number })
      | null,
  ): Promise<Array<T & { isAd?: boolean; promotionId?: number }>> {
    const sponsoredSlots = Math.ceil(organic.length / SPONSORED_RATIO);
    if (sponsoredSlots === 0) return organic;
    const organicIds = organic.map((o) => o.id);
    const picks = await this.pickSponsored({
      count: sponsoredSlots,
      excludeProductIds: organicIds,
    });
    if (picks.length === 0) return organic;

    const enriched: Array<T & { isAd: true; promotionId: number }> = [];
    for (const p of picks) {
      const item = await enrich(p);
      if (item) enriched.push(item);
    }

    const out: Array<T & { isAd?: boolean; promotionId?: number }> = [];
    const remainingOrganic = [...organic];
    const remainingSponsored = [...enriched];
    let i = 0;
    while (remainingOrganic.length > 0 || remainingSponsored.length > 0) {
      const sponsoredSlot = i % SPONSORED_RATIO === 0 && remainingSponsored.length > 0;
      if (sponsoredSlot) {
        out.push(remainingSponsored.shift()!);
      } else if (remainingOrganic.length > 0) {
        out.push(remainingOrganic.shift()!);
      } else {
        out.push(remainingSponsored.shift()!);
      }
      i++;
    }
    return out;
  }

  // ── Cron sweep ───────────────────────────────────────────────────

  /// Hourly belt-and-braces: re-check every active promotion against
  /// its day-state. Catches the "spend_today_date is stale because
  /// no impressions arrived after midnight" case so the dashboard
  /// shows the right number even on quiet promotions.
  async sweepDailyCaps(): Promise<{ updated: number }> {
    const today = todayInUtcDateOnly();
    const result = await prisma.promotion.updateMany({
      where: {
        isActive: true,
        OR: [
          { spendTodayDate: { lt: today } },
          { spendTodayDate: null, deliveredImpressions: 0 },
        ],
      },
      data: {
        spendTodayPaise: 0,
        spendTodayDate: today,
      },
    });
    // Separate sweep for windows past endAt — auto-pause them too.
    const expired = await prisma.promotion.updateMany({
      where: { isActive: true, endAt: { lt: new Date() } },
      data: { isActive: false, pausedReason: 'window_ended' },
    });
    logger.info(
      { rolledOver: result.count, expired: expired.count },
      'promotions: daily sweep done',
    );
    return { updated: result.count + expired.count };
  }
}

export const promotionsService = new PromotionsService();
// Re-export the Decimal type for downstream consumers that need it.
export type _PrismaTypes = typeof Prisma;
