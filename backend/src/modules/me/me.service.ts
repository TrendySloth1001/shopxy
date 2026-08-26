import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { isValidGstin } from '../../shared/validation/indian.js';

const linkShopSelect = {
  id: true,
  name: true,
  slug: true,
  logoUrl: true,
  bannerUrl: true,
} satisfies Prisma.ShopSelect;

const lastInvoiceSelect = {
  invoiceDate: true,
  total: true,
} satisfies Prisma.InvoiceSelect;

const partySelect = {
  id: true,
  name: true,
  email: true,
  phone: true,
  address: true,
  _count: { select: { invoices: true } },
  shop: { select: linkShopSelect },
  invoices: {
    select: lastInvoiceSelect,
    orderBy: { invoiceDate: 'desc' as const },
    take: 1,
  },
} satisfies Prisma.PartySelect;

const vendorSelect = {
  id: true,
  name: true,
  email: true,
  phone: true,
  address: true,
  _count: { select: { invoices: true } },
  shop: { select: linkShopSelect },
  invoices: {
    select: lastInvoiceSelect,
    orderBy: { invoiceDate: 'desc' as const },
    take: 1,
  },
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
  async listCatalog(opts: {
    search: string;
    categoryId?: number;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.ProductWhereInput = {
      isActive: true,
      isPublished: true,
    };
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
      where: { id, isActive: true, isPublished: true },
      select: catalogDetailSelect,
    });
  }

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

  async linkedShops(userId: number) {
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

  async gstProfile(userId: number) {
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { buyerGstin: true, buyerLegalName: true },
    });
    return {
      gstin: user.buyerGstin,
      legalName: user.buyerLegalName,
    };
  }

  async updateGstProfile(
    userId: number,
    input: { gstin: string | null; legalName?: string | null },
  ): Promise<
    | { error: 'INVALID_GSTIN' | 'LEGAL_NAME_REQUIRED' }
    | { gstin: string | null; legalName: string | null }
  > {
    if (input.gstin == null || input.gstin.trim().length === 0) {
      const cleared = await prisma.user.update({
        where: { id: userId },
        data: { buyerGstin: null, buyerLegalName: null },
        select: { buyerGstin: true, buyerLegalName: true },
      });
      return { gstin: cleared.buyerGstin, legalName: cleared.buyerLegalName };
    }

    const gstin = input.gstin.trim().toUpperCase();
    if (!isValidGstin(gstin)) return { error: 'INVALID_GSTIN' };

    const legalName = input.legalName?.trim() ?? '';
    if (legalName.length === 0) return { error: 'LEGAL_NAME_REQUIRED' };

    const saved = await prisma.user.update({
      where: { id: userId },
      data: { buyerGstin: gstin, buyerLegalName: legalName },
      select: { buyerGstin: true, buyerLegalName: true },
    });
    return { gstin: saved.buyerGstin, legalName: saved.buyerLegalName };
  }
}

export const meService = new MeService();
