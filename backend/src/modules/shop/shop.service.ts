import prisma from '../../infra/db/prisma.js';
import { seedDefaultRoles } from '../team/team.service.js';
import { invalidateMembershipCache } from '../../shared/http/requireAuth.js';

const publicShopSelect = {
  id: true,
  name: true,
  slug: true,
  tagline: true,
  logoUrl: true,
  bannerUrl: true,
  rating: true,
  ratingCount: true,
  isVerified: true,
  locationCity: true,
  locationState: true,
  returnPolicy: true,
  shippingPolicy: true,
  refundPolicy: true,
  vacationMode: true,
  vacationMessage: true,
  operatingHours: true,
  createdAt: true,
} as const;

const merchantShopSelect = {
  ...publicShopSelect,
  isPublished: true,
  updatedAt: true,
  returnsEnabled: true,
  returnWindowDays: true,
  refundMode: true,
  returnPolicyNote: true,
  cancellationPolicy: true,
  pdfTemplateId: true,
} as const;

function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

async function uniqueSlug(base: string, excludeShopId?: number): Promise<string> {
  let candidate = base || 'shop';
  let suffix = 1;
  for (;;) {
    const existing = await prisma.shop.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing || existing.id === excludeShopId) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

export class ShopService {
  async getMyShop(userId: number) {
    return prisma.shop.findUnique({
      where: { ownerUserId: userId },
      select: merchantShopSelect,
    });
  }

  async createMyShop(
    userId: number,
    data: {
      name: string;
      phoneNumber?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
    },
  ): Promise<{ shop: Awaited<ReturnType<ShopService['getMyShop']>> } | { error: string }> {
    const membership = await prisma.shopMember.findUnique({
      where: { userId },
      select: { role: true },
    });
    if (membership) {
      return {
        error:
          membership.role === 'OWNER'
            ? 'You already have a shop.'
            : "You're already on a shop team, so you can't create your own shop.",
      };
    }

    const name = data.name.trim();
    const slug = await uniqueSlug(slugify(name));
    const shopCity = data.shopCity?.trim() || null;
    const shopState = data.shopState?.trim() || null;
    const phoneNumber = data.phoneNumber?.trim() || null;

    const shop = await prisma.$transaction(async (tx) => {
      const created = await tx.shop.create({
        data: {
          ownerUserId: userId,
          name,
          slug,
          locationCity: shopCity,
          locationState: shopState,
        },
        select: merchantShopSelect,
      });
      await tx.shopMember.create({
        data: { shopId: created.id, userId, role: 'OWNER' },
      });
      await seedDefaultRoles(tx, created.id);
      await tx.user.update({
        where: { id: userId },
        data: {
          shopName: name,
          shopCity: shopCity ?? undefined,
          shopState: shopState ?? undefined,
          phoneNumber: phoneNumber ?? undefined,
        },
      });
      return created;
    });

    invalidateMembershipCache(userId);
    return { shop };
  }

  async updateMyShop(
    userId: number,
    data: {
      name?: string;
      tagline?: string | null;
      logoUrl?: string | null;
      bannerUrl?: string | null;
      locationCity?: string | null;
      locationState?: string | null;
      returnPolicy?: string | null;
      shippingPolicy?: string | null;
      refundPolicy?: string | null;
      vacationMode?: boolean;
      vacationMessage?: string | null;
      operatingHours?: Record<string, [string, string]> | null;
      returnsEnabled?: boolean;
      returnWindowDays?: number;
      refundMode?: string;
      returnPolicyNote?: string | null;
      cancellationPolicy?: string;
      pdfTemplateId?: string;
    },
  ) {
    const existing = await prisma.shop.findUnique({
      where: { ownerUserId: userId },
      select: { id: true, slug: true, name: true },
    });
    if (!existing) {
      throw new Error('Shop not found for this merchant');
    }

    let slug = existing.slug;
    if (data.name && data.name !== existing.name) {
      slug = await uniqueSlug(slugify(data.name), existing.id);
    }

    return prisma.shop.update({
      where: { id: existing.id },
      data: {
        name: data.name ?? undefined,
        slug,
        tagline: data.tagline === undefined ? undefined : data.tagline,
        logoUrl: data.logoUrl === undefined ? undefined : data.logoUrl,
        bannerUrl: data.bannerUrl === undefined ? undefined : data.bannerUrl,
        locationCity: data.locationCity === undefined
            ? undefined
            : data.locationCity,
        locationState: data.locationState === undefined
            ? undefined
            : data.locationState,
        returnPolicy: data.returnPolicy === undefined
            ? undefined
            : data.returnPolicy,
        shippingPolicy: data.shippingPolicy === undefined
            ? undefined
            : data.shippingPolicy,
        refundPolicy: data.refundPolicy === undefined
            ? undefined
            : data.refundPolicy,
        vacationMode: data.vacationMode === undefined
            ? undefined
            : data.vacationMode,
        vacationMessage: data.vacationMessage === undefined
            ? undefined
            : data.vacationMessage,
        operatingHours: data.operatingHours === undefined
            ? undefined
            : (data.operatingHours as object | null) ?? undefined,
        returnsEnabled: data.returnsEnabled === undefined
            ? undefined
            : data.returnsEnabled,
        returnWindowDays: data.returnWindowDays === undefined
            ? undefined
            : data.returnWindowDays,
        refundMode: data.refundMode === undefined ? undefined : data.refundMode,
        returnPolicyNote: data.returnPolicyNote === undefined
            ? undefined
            : data.returnPolicyNote,
        cancellationPolicy: data.cancellationPolicy === undefined
            ? undefined
            : data.cancellationPolicy,
        pdfTemplateId: data.pdfTemplateId === undefined ? undefined : data.pdfTemplateId,
      },
      select: merchantShopSelect,
    });
  }

  async setVerified(shopId: number, isVerified: boolean) {
    const existing = await prisma.shop.findUnique({
      where: { id: shopId },
      select: { id: true },
    });
    if (!existing) return null;
    return prisma.shop.update({
      where: { id: shopId },
      data: { isVerified },
      select: merchantShopSelect,
    });
  }

  async listForAdmin(opts: { search?: string; limit?: number }) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const search = (opts.search ?? '').trim();
    return prisma.shop.findMany({
      where: search.length > 0
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { slug: { contains: search, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: [{ isVerified: 'desc' }, { id: 'desc' }],
      take: limit,
      select: merchantShopSelect,
    });
  }

  async setPublished(userId: number, isPublished: boolean) {
    return prisma.shop.update({
      where: { ownerUserId: userId },
      data: { isPublished },
      select: merchantShopSelect,
    });
  }

  async getPublicShopBySlug(slug: string) {
    return prisma.shop.findFirst({
      where: { slug, isPublished: true },
      select: publicShopSelect,
    });
  }
}

export const shopService = new ShopService();
