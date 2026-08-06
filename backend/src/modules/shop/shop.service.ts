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
  // Operational return/cancel rules — merchant settings screens edit
  // these; the public select intentionally omits them (customers see
  // them reflected as canCancel/canReturn flags on their orders, plus
  // the marketing policy texts above).
  returnsEnabled: true,
  returnWindowDays: true,
  refundMode: true,
  returnPolicyNote: true,
  cancellationPolicy: true,
  pdfTemplateId: true,
} as const;

/// Lower-cases, collapses non-alphanumerics to single dashes, trims
/// leading/trailing dashes. Used both at first-save and at every rename
/// so the public URL stays stable to the merchant's choice.
function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/// Returns `base`, `base-2`, `base-3`, … until a slug is free. Cheap
/// even at scale because the unique index makes the lookup O(log n)
/// and contention here is naturally bounded by how many merchants ever
/// pick the same brand name.
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
  /// Returns the caller-merchant's shop. Every OWNER has one (created
  /// at signup once the Shop module wires that path; the P0 backfill
  /// guarantees it for existing accounts). Null only if the caller is
  /// CUSTOMER, which the route guard already prevents.
  async getMyShop(userId: number) {
    return prisma.shop.findUnique({
      where: { ownerUserId: userId },
      select: merchantShopSelect,
    });
  }

  /// First-shop onboarding for a freshly-registered OWNER who signed up
  /// without a shop name (the new two-step flow: account → onboarding).
  /// Creates the Shop + the owner's ShopMember + seeds the starter roles,
  /// and mirrors the name + a few details onto the User so invoice headers
  /// have a value. Refuses if the caller already owns a shop or is already
  /// on a team (ShopMember.userId is unique — one team per user).
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
      // Seed the owner's membership + starter roles, same as one-step signup.
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

    // The membership was cached as "none" during the shopless window
    // (60s TTL) — bust it so the very next request resolves the new shopId.
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
      /// Operational return/cancel rules (distinct from the marketing
      /// policy TEXTS above): these drive actual backend gating.
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

    // If the merchant renames the shop, regenerate the slug from the
    // new name — keeps `/shops/:slug` matching whatever the customer
    // typed. We don't re-slug for tagline/image changes.
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

  /// Platform-admin verified toggle. Independent of any merchant
  /// surface — the merchant cannot self-verify. Returns the updated
  /// shop or null if the id doesn't resolve.
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

  /// Platform-admin listing — every shop regardless of publish state
  /// so the verification UI can show drafts too. Ordered isVerified
  /// desc → newest, so the admin sees freshly-flipped shops first
  /// and the unverified backlog stays visible.
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

  /// Marketplace publish toggle. Separate from updateMyShop so the
  /// merchant's "publish" action is a deliberate, audit-able event
  /// rather than a side-effect of an unrelated field save.
  async setPublished(userId: number, isPublished: boolean) {
    return prisma.shop.update({
      where: { ownerUserId: userId },
      data: { isPublished },
      select: merchantShopSelect,
    });
  }

  /// Public shop view by slug. Returns null when the slug doesn't
  /// resolve OR when the shop hasn't published yet — the unpublished
  /// state must look identical to a missing shop so unfinished shops
  /// don't leak metadata via 200-vs-404 probing.
  async getPublicShopBySlug(slug: string) {
    return prisma.shop.findFirst({
      where: { slug, isPublished: true },
      select: publicShopSelect,
    });
  }
}

export const shopService = new ShopService();
