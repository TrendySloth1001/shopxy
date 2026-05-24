import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

const partySelect = {
  id: true,
  name: true,
  email: true,
  phone: true,
  address: true,
  _count: { select: { invoices: true } },
} satisfies Prisma.PartySelect;

const vendorSelect = {
  id: true,
  name: true,
  email: true,
  phone: true,
  address: true,
  _count: { select: { invoices: true } },
} satisfies Prisma.VendorSelect;

const invoiceListSelect = {
  id: true,
  invoiceNo: true,
  type: true,
  status: true,
  total: true,
  subtotal: true,
  taxAmount: true,
  discount: true,
  invoiceDate: true,
  createdAt: true,
  _count: { select: { items: true } },
} satisfies Prisma.InvoiceSelect;

const invoiceDetailSelect = {
  id: true,
  invoiceNo: true,
  type: true,
  status: true,
  total: true,
  subtotal: true,
  taxAmount: true,
  discount: true,
  invoiceDate: true,
  customerName: true,
  customerPhone: true,
  customerGstin: true,
  vendorName: true,
  vendorPhone: true,
  vendorGstin: true,
  note: true,
  createdAt: true,
  items: {
    select: {
      id: true,
      productName: true,
      productSku: true,
      hsn: true,
      unit: true,
      quantity: true,
      unitPrice: true,
      taxPercent: true,
      discount: true,
      total: true,
    },
  },
} satisfies Prisma.InvoiceSelect;

const catalogListSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  hsnCode: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  taxPercent: true,
  stockQuantity: true,
  categoryId: true,
  category: { select: { id: true, name: true, iconName: true } },
  images: {
    select: { id: true, url: true },
    orderBy: { sortOrder: 'asc' },
    take: 1,
  },
} satisfies Prisma.ProductSelect;

const catalogDetailSelect = {
  ...catalogListSelect,
  images: {
    select: { id: true, url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' },
  },
} satisfies Prisma.ProductSelect;

export class MeService {
  /// Customer-side product catalog. Mirrors the merchant `/products`
  /// list but only ever returns active products and projects the
  /// minimal fields the customer app actually renders. The same
  /// (isActive, name) index that powers the merchant page is enough.
  async listCatalog(opts: {
    search: string;
    categoryId?: number;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.ProductWhereInput = { isActive: true };
    if (opts.categoryId) where.categoryId = opts.categoryId;
    if (opts.search) {
      where.OR = [
        { name: { contains: opts.search, mode: 'insensitive' } },
        { sku: { contains: opts.search, mode: 'insensitive' } },
        { barcode: { contains: opts.search, mode: 'insensitive' } },
      ];
    }
    const [data, total] = await Promise.all([
      prisma.product.findMany({
        where,
        select: catalogListSelect,
        orderBy: { name: 'asc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.product.count({ where }),
    ]);
    return { data, total };
  }

  async getCatalogProduct(id: number) {
    return prisma.product.findFirst({
      where: { id, isActive: true },
      select: catalogDetailSelect,
    });
  }

  /// Customer wishlist. Returns the saved products with the same shape
  /// as the catalog list so the same product card can render either
  /// surface. Most-recent-first matches how shopping carts/lists
  /// behave everywhere (newest at the top).
  async listWishlist(userId: number) {
    const rows = await prisma.wishlistItem.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        createdAt: true,
        product: { select: catalogListSelect },
      },
    });
    return rows
      .filter((r) => r.product !== null && r.product.id != null)
      .map((r) => ({
        id: r.id,
        savedAt: r.createdAt,
        product: r.product,
      }));
  }

  async listWishlistProductIds(userId: number): Promise<number[]> {
    const rows = await prisma.wishlistItem.findMany({
      where: { userId },
      select: { productId: true },
    });
    return rows.map((r) => r.productId);
  }

  /// Idempotent add — if the row exists, return it. The unique
  /// constraint on (userId, productId) means concurrent calls can't
  /// duplicate.
  async addToWishlist(userId: number, productId: number) {
    const product = await prisma.product.findFirst({
      where: { id: productId, isActive: true },
      select: { id: true },
    });
    if (!product) return { error: 'Product not found' as const };
    await prisma.wishlistItem.upsert({
      where: { userId_productId: { userId, productId } },
      create: { userId, productId },
      update: {},
    });
    return { ok: true as const };
  }

  /// Idempotent remove — no error if the row is already gone, so the
  /// frontend can hammer the toggle without checking state first.
  async removeFromWishlist(userId: number, productId: number) {
    await prisma.wishlistItem.deleteMany({
      where: { userId, productId },
    });
    return { ok: true as const };
  }

  async listCategoriesWithCounts() {
    return prisma.category.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: {
        id: true,
        name: true,
        imageUrl: true,
        iconName: true,
        _count: { select: { products: { where: { isActive: true } } } },
      },
    });
  }

  /// Top-level "what am I linked to" list — one query each, parallel.
  async links(userId: number) {
    const [parties, vendors] = await Promise.all([
      prisma.party.findMany({
        where: { linkedUserId: userId, isActive: true },
        select: partySelect,
        orderBy: { name: 'asc' },
      }),
      prisma.vendor.findMany({
        where: { linkedUserId: userId, isActive: true },
        select: vendorSelect,
        orderBy: { name: 'asc' },
      }),
    ]);
    return { parties, vendors };
  }

  /// Distinct shops the user has at least one active Party or Vendor
  /// link to. Powers the customer-side "Your linked merchants" rail:
  /// each result is a clickable shop tile that opens the marketplace
  /// shop page filtered to that merchant's catalog. Returns shops
  /// regardless of their `isPublished` flag — the merchant chose to
  /// invite this user, so they get to browse even if the shop hasn't
  /// gone fully public yet.
  async linkedShops(userId: number) {
    // Collect distinct shopIds from active party + vendor rows the
    // user is the linked user on. One round-trip per side; UNION'd
    // client-side because Prisma can't `distinct` across two tables.
    const [partyShopIds, vendorShopIds] = await Promise.all([
      prisma.party.findMany({
        where: { linkedUserId: userId, isActive: true },
        select: { shopId: true },
        distinct: ['shopId'],
      }),
      prisma.vendor.findMany({
        where: { linkedUserId: userId, isActive: true },
        select: { shopId: true },
        distinct: ['shopId'],
      }),
    ]);
    const partySet = new Set(partyShopIds.map((r) => r.shopId));
    const vendorSet = new Set(vendorShopIds.map((r) => r.shopId));
    const allIds = [...new Set([...partySet, ...vendorSet])];
    if (allIds.length === 0) return [];

    const shops = await prisma.shop.findMany({
      where: { id: { in: allIds } },
      select: {
        id: true,
        ownerUserId: true,
        name: true,
        slug: true,
        tagline: true,
        logoUrl: true,
        bannerUrl: true,
        isPublished: true,
        rating: true,
        ratingCount: true,
      },
      orderBy: { name: 'asc' },
    });

    return shops.map((s) => ({
      ...s,
      roles: {
        party: partySet.has(s.id),
        vendor: vendorSet.has(s.id),
      },
    }));
  }

  /// Authorisation gate — does this user own the party/vendor row?
  /// Returns the row itself so callers can use its name etc. without a
  /// second round-trip.
  async assertOwnsParty(userId: number, partyId: number) {
    return prisma.party.findFirst({
      where: { id: partyId, linkedUserId: userId },
      select: partySelect,
    });
  }
  async assertOwnsVendor(userId: number, vendorId: number) {
    return prisma.vendor.findFirst({
      where: { id: vendorId, linkedUserId: userId },
      select: vendorSelect,
    });
  }

  /// List confirmed invoices that the linking shop has issued *to this
  /// party*. Cancelled and draft rows are deliberately hidden — the
  /// customer should only see what's been finalised against them.
  async listInvoicesForParty(opts: {
    partyId: number;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.InvoiceWhereInput = {
      partyId: opts.partyId,
      status: 'CONFIRMED',
    };
    const [data, total] = await Promise.all([
      prisma.invoice.findMany({
        where,
        select: invoiceListSelect,
        orderBy: { invoiceDate: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.invoice.count({ where }),
    ]);
    return { data, total };
  }

  async listInvoicesForVendor(opts: {
    vendorId: number;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.InvoiceWhereInput = {
      vendorId: opts.vendorId,
      status: 'CONFIRMED',
    };
    const [data, total] = await Promise.all([
      prisma.invoice.findMany({
        where,
        select: invoiceListSelect,
        orderBy: { invoiceDate: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.invoice.count({ where }),
    ]);
    return { data, total };
  }

  /// Single-invoice detail, gated to the party/vendor that the row
  /// belongs to so a malicious client can't probe ids they don't own.
  async getInvoiceForParty(opts: { partyId: number; invoiceId: number }) {
    return prisma.invoice.findFirst({
      where: { id: opts.invoiceId, partyId: opts.partyId, status: 'CONFIRMED' },
      select: invoiceDetailSelect,
    });
  }
  async getInvoiceForVendor(opts: { vendorId: number; invoiceId: number }) {
    return prisma.invoice.findFirst({
      where: { id: opts.invoiceId, vendorId: opts.vendorId, status: 'CONFIRMED' },
      select: invoiceDetailSelect,
    });
  }
}

export const meService = new MeService();
