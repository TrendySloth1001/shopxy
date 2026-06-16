import { BannerPlacement, Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

const ACTIVE_CACHE_TTL_SECONDS = 60;

function activeCacheKey(placement: BannerPlacement): string {
  return `banners:active:${placement}`;
}

const publicBannerSelect = {
  id: true,
  placement: true,
  imageUrl: true,
  linkUrl: true,
  sortOrder: true,
} as const;

const ownerBannerSelect = {
  ...publicBannerSelect,
  shopId: true,
  startAt: true,
  endAt: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} as const;

export interface CreateBannerInput {
  placement: BannerPlacement;
  imageUrl: string;
  linkUrl?: string | null;
  sortOrder?: number;
  startAt?: Date | null;
  endAt?: Date | null;
  isActive?: boolean;
  /// Owning shop. null = a platform-wide banner authored by an admin.
  shopId?: number | null;
}

export type UpdateBannerInput = Partial<CreateBannerInput>;

export class BannersService {
  /// Public read — only banners that are active AND inside their
  /// scheduling window. Cached in Redis for 60s so home-feed reads
  /// don't hit Postgres on every request. Cache key is per placement,
  /// invalidated by any banner write.
  async getActiveByPlacement(placement: BannerPlacement) {
    if (redisAvailable()) {
      try {
        const cached = await getRedis().get(activeCacheKey(placement));
        if (cached) return JSON.parse(cached) as Array<Record<string, unknown>>;
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'banner cache read failed');
      }
    }

    const now = new Date();
    const rows = await prisma.banner.findMany({
      where: {
        placement,
        isActive: true,
        AND: [
          { OR: [{ startAt: null }, { startAt: { lte: now } }] },
          { OR: [{ endAt: null }, { endAt: { gte: now } }] },
        ],
      },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      select: publicBannerSelect,
    });

    if (redisAvailable()) {
      try {
        await getRedis().set(
          activeCacheKey(placement),
          JSON.stringify(rows),
          'EX',
          ACTIVE_CACHE_TTL_SECONDS,
        );
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'banner cache write failed');
      }
    }

    return rows;
  }

  /// Admin listing — ALL banners regardless of schedule + active state
  /// so the manager UI can show "Scheduled" / "Expired" / "Off".
  async listForAdmin(opts: {
    placement?: BannerPlacement;
    cursor?: number;
    limit?: number;
  }) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const where: Prisma.BannerWhereInput = {};
    if (opts.placement) where.placement = opts.placement;
    const rows = await prisma.banner.findMany({
      where,
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: ownerBannerSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return { data, nextCursor: hasMore ? data[data.length - 1].id : null };
  }

  async getById(id: number) {
    return prisma.banner.findUnique({ where: { id }, select: ownerBannerSelect });
  }

  async create(input: CreateBannerInput) {
    const row = await prisma.banner.create({
      data: this._writeData(input, true),
      select: ownerBannerSelect,
    });
    await this._invalidate(input.placement);
    return row;
  }

  async update(id: number, input: UpdateBannerInput) {
    const existing = await prisma.banner.findUnique({
      where: { id },
      select: { placement: true },
    });
    if (!existing) return null;
    const row = await prisma.banner.update({
      where: { id },
      data: this._writeData(input, false),
      select: ownerBannerSelect,
    });
    await this._invalidate(existing.placement);
    if (input.placement && input.placement !== existing.placement) {
      await this._invalidate(input.placement);
    }
    return row;
  }

  async delete(id: number) {
    const existing = await prisma.banner.findUnique({
      where: { id },
      select: { placement: true },
    });
    if (!existing) return false;
    await prisma.banner.delete({ where: { id } });
    await this._invalidate(existing.placement);
    return true;
  }

  // ── Merchant-scoped CRUD ─────────────────────────────────────────
  // Each merchant manages their own banners (shopId = their shop). All
  // queries scope through shopId so id-probing across shops returns 404.

  async listForShop(shopId: number) {
    return prisma.banner.findMany({
      where: { shopId },
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      select: ownerBannerSelect,
    });
  }

  async getByIdForShop(shopId: number, id: number) {
    return prisma.banner.findFirst({
      where: { id, shopId },
      select: ownerBannerSelect,
    });
  }

  async createForShop(shopId: number, input: CreateBannerInput) {
    return this.create({ ...input, shopId });
  }

  async updateForShop(shopId: number, id: number, input: UpdateBannerInput) {
    const owned = await prisma.banner.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;
    // shopId can never be reassigned through the merchant path.
    const { shopId: _ignore, ...rest } = input;
    void _ignore;
    return this.update(id, rest);
  }

  async deleteForShop(shopId: number, id: number) {
    const owned = await prisma.banner.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return false;
    return this.delete(id);
  }

  private _writeData(input: UpdateBannerInput, isCreate: boolean) {
    const data: Prisma.BannerUncheckedCreateInput | Prisma.BannerUncheckedUpdateInput = {};
    if (input.placement !== undefined) data.placement = input.placement;
    if (input.imageUrl !== undefined) data.imageUrl = input.imageUrl;
    if (input.linkUrl !== undefined) data.linkUrl = input.linkUrl;
    if (input.sortOrder !== undefined) data.sortOrder = input.sortOrder;
    if (input.startAt !== undefined) data.startAt = input.startAt;
    if (input.endAt !== undefined) data.endAt = input.endAt;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.shopId !== undefined) data.shopId = input.shopId;
    if (isCreate) {
      data.sortOrder ??= 0;
      data.isActive ??= true;
      data.shopId ??= null;
    }
    return data as Prisma.BannerUncheckedCreateInput;
  }

  /// Blow the per-placement cache. No-op when Redis is offline.
  private async _invalidate(placement: BannerPlacement): Promise<void> {
    if (!redisAvailable()) return;
    try {
      await getRedis().del(activeCacheKey(placement));
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'banner cache invalidate failed');
    }
  }
}

export const bannersService = new BannersService();
