import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

/// Detail-level projection for a public marketplace product page.
/// Goes wide deliberately — the customer PDP needs gallery, shop
/// attribution, rating denorms, tags and an unwrapped category for
/// breadcrumb rendering.
const detailSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  taxPercent: true,
  stockQuantity: true,
  ratingAvg: true,
  ratingCount: true,
  tags: true,
  highlights: true,
  specs: true,
  offers: true,
  totalSold: true,
  createdAt: true,
  images: {
    select: { id: true, url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
  },
  shop: {
    select: { id: true, name: true, slug: true, logoUrl: true, rating: true, ratingCount: true },
  },
  category: { select: { id: true, name: true, slug: true } },
  flashSales: {
    where: { isActive: true, startAt: { lte: new Date() }, endAt: { gte: new Date() } },
    select: { id: true, flashPrice: true, stockLimit: true, soldCount: true, endAt: true },
    take: 1,
  },
} satisfies Prisma.ProductSelect;

const listSelect = {
  id: true,
  name: true,
  sku: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  ratingAvg: true,
  ratingCount: true,
  totalSold: true,
  images: {
    select: { url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
    take: 1,
  },
  shop: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.ProductSelect;

export class MarketplaceService {
  /// Public product detail. Returns null when the product is missing,
  /// inactive, or unpublished — the three states are deliberately
  /// indistinguishable from the caller's perspective so unpublished
  /// items don't leak metadata via 200-vs-404 probing.
  ///
  /// `viewerUserId` (the customer making the request) is excluded from
  /// reading their own shop's products — the "you can't buy from your
  /// own shop" marketplace guard rail at the read boundary.
  async getPublicProduct(id: number, viewerUserId?: number) {
    return prisma.product.findFirst({
      where: {
        id,
        isActive: true,
        isPublished: true,
        ...(viewerUserId ? { shop: { ownerUserId: { not: viewerUserId } } } : {}),
      },
      select: detailSelect,
    });
  }

  async listShopProducts(opts: {
    slug: string;
    skip: number;
    limit: number;
    sort?: 'popular' | 'newest' | 'price_asc' | 'price_desc';
    viewerUserId?: number;
  }) {
    const shop = await prisma.shop.findFirst({
      where: {
        slug: opts.slug,
        isPublished: true,
        ...(opts.viewerUserId ? { ownerUserId: { not: opts.viewerUserId } } : {}),
      },
      select: {
        id: true, name: true, slug: true, tagline: true, logoUrl: true, bannerUrl: true,
        rating: true, ratingCount: true,
      },
    });
    if (!shop) return null;

    const orderBy: Prisma.ProductOrderByWithRelationInput =
      opts.sort === 'newest'    ? { createdAt: 'desc' }
      : opts.sort === 'price_asc'  ? { sellingPrice: 'asc' }
      : opts.sort === 'price_desc' ? { sellingPrice: 'desc' }
      :                              { totalSold: 'desc' };

    const where: Prisma.ProductWhereInput = {
      shopId: shop.id,
      isActive: true,
      isPublished: true,
    };
    const [data, total] = await Promise.all([
      prisma.product.findMany({
        where,
        select: listSelect,
        orderBy,
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.product.count({ where }),
    ]);
    return { shop, data, total };
  }

  /// Public products in a category, identified by slug. Includes
  /// products directly tagged with the category AND (when the slug
  /// resolves to a parent in the canonical taxonomy) products tagged
  /// with any of its children — so "Electronics" surfaces laptops,
  /// cameras, headphones, etc. without forcing the customer to drill
  /// down first. Returns null for an unknown slug.
  async listCategoryProducts(opts: {
    slug: string;
    skip: number;
    limit: number;
    sort?: 'popular' | 'newest' | 'price_asc' | 'price_desc';
    viewerUserId?: number;
  }) {
    const category = await prisma.category.findUnique({
      where: { slug: opts.slug },
      select: {
        id: true, name: true, slug: true, imageUrl: true, iconName: true,
        children: { select: { id: true, name: true, slug: true, imageUrl: true, iconName: true } },
      },
    });
    if (!category) return null;

    const ids = [category.id, ...category.children.map((c) => c.id)];

    const orderBy: Prisma.ProductOrderByWithRelationInput =
      opts.sort === 'newest'    ? { createdAt: 'desc' }
      : opts.sort === 'price_asc'  ? { sellingPrice: 'asc' }
      : opts.sort === 'price_desc' ? { sellingPrice: 'desc' }
      :                              { totalSold: 'desc' };

    const where: Prisma.ProductWhereInput = {
      categoryId: { in: ids },
      isActive: true,
      isPublished: true,
      ...(opts.viewerUserId
        ? { shop: { ownerUserId: { not: opts.viewerUserId } } }
        : {}),
    };
    const [data, total] = await Promise.all([
      prisma.product.findMany({
        where, select: listSelect, orderBy,
        skip: opts.skip, take: opts.limit,
      }),
      prisma.product.count({ where }),
    ]);
    return { category, data, total };
  }
}

export const marketplaceService = new MarketplaceService();
