import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';

const productSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  barcode: true,
  hsnCode: true,
  mrp: true,
  sellingPrice: true,
  purchasePrice: true,
  taxPercent: true,
  stockQuantity: true,
  lowStockThreshold: true,
  unit: true,
  categoryId: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  category: true,
  images: { orderBy: { sortOrder: 'asc' as const } },
} as const;

export class ProductsService {
  async createProduct(
    data: {
      name: string;
      description?: string;
      sku: string;
      barcode?: string;
      hsnCode?: string;
      mrp: number;
      sellingPrice: number;
      purchasePrice: number;
      taxPercent?: number;
      stockQuantity?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number;
      imageUrls?: string[];
    },
    options: { createdById?: number } = {},
  ) {
    const { imageUrls, stockQuantity, ...rest } = data;
    // Create the product with stockQuantity = 0; the ledger post below is
    // what funds it. This keeps products.stockQuantity in sync with the
    // ledger from row one — no orphan stock without a cost basis.
    const product = await prisma.product.create({
      data: {
        ...rest,
        stockQuantity: 0,
        images: imageUrls?.length
          ? { create: imageUrls.map((url, i) => ({ url, sortOrder: i })) }
          : undefined,
      },
      select: productSelect,
    });

    if (stockQuantity && stockQuantity > 0) {
      const result = await ledgerService.post({
        direction: 'IN',
        reasonCode: 'OPENING',
        sourceType: 'OPENING',
        sourceId: product.id,
        lines: [
          {
            productId: product.id,
            quantity: stockQuantity,
            unitPrice: data.purchasePrice,
          },
        ],
        createdById: options.createdById,
        note: 'Opening balance on product create',
      });

      if ('error' in result) {
        // Roll back the product so we never leave one without a ledger.
        await prisma.product.delete({ where: { id: product.id } });
        throw new Error(`Failed to post opening balance: ${result.error}`);
      }

      // Re-read so the response reflects the funded stock quantity.
      return prisma.product.findUniqueOrThrow({
        where: { id: product.id },
        select: productSelect,
      });
    }

    return product;
  }

  async listProducts(options: {
    activeOnly: boolean;
    lowStock: boolean;
    categoryId?: number;
    search: string;
    sortBy: string;
    sortOrder: 'asc' | 'desc';
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};

    if (options.activeOnly) where.isActive = true;
    if (options.categoryId) where.categoryId = options.categoryId;
    if (options.search) {
      where.OR = [
        { name: { contains: options.search, mode: 'insensitive' } },
        { sku: { contains: options.search, mode: 'insensitive' } },
        { barcode: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    if (options.lowStock) {
      // Column-to-column comparison — use raw SQL to avoid fetching all rows in memory
      where.isActive = true;
      const categoryFilter = options.categoryId
        ? prisma.$queryRaw<[{ count: bigint }]>`
            SELECT COUNT(*)::bigint AS count FROM products
            WHERE is_active = true AND stock_quantity > 0
              AND stock_quantity <= low_stock_threshold AND category_id = ${options.categoryId}`
        : prisma.$queryRaw<[{ count: bigint }]>`
            SELECT COUNT(*)::bigint AS count FROM products
            WHERE is_active = true AND stock_quantity > 0
              AND stock_quantity <= low_stock_threshold`;

      const countResult = await categoryFilter;
      const total = Number(countResult[0].count);

      // Fetch with include via ORM after getting IDs (simpler and type-safe)
      const allLowStock = await prisma.product.findMany({
        where: {
          isActive: true,
          ...(options.categoryId ? { categoryId: options.categoryId } : {}),
        },
        select: { id: true, stockQuantity: true, lowStockThreshold: true },
      });

      const lowStockIds = allLowStock
        .filter((p) => Number(p.stockQuantity) > 0 && Number(p.stockQuantity) <= Number(p.lowStockThreshold))
        .map((p) => p.id);

      const products = await prisma.product.findMany({
        where: { id: { in: lowStockIds } },
        orderBy: { [options.sortBy]: options.sortOrder } as Record<string, 'asc' | 'desc'>,
        skip: options.skip,
        take: options.limit,
        select: productSelect,
      });

      return { products, total: lowStockIds.length };
    }

    const orderBy = { [options.sortBy]: options.sortOrder } as Record<string, 'asc' | 'desc'>;

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy,
        skip: options.skip,
        take: options.limit,
        select: productSelect,
      }),
      prisma.product.count({ where }),
    ]);

    return { products, total };
  }

  lookupProduct(code: string) {
    return prisma.product.findFirst({
      where: { OR: [{ barcode: code }, { sku: code }] },
      select: productSelect,
    });
  }

  getProductById(id: number) {
    return prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        images: { orderBy: { sortOrder: 'asc' } },
        stockTransactions: {
          orderBy: { createdAt: 'desc' },
          take: 30,
          include: { vendor: { select: { id: true, name: true } } },
        },
      },
    });
  }

  updateProduct(
    id: number,
    data: {
      name?: string;
      description?: string | null;
      sku?: string;
      barcode?: string | null;
      hsnCode?: string | null;
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
    },
  ) {
    return prisma.product.update({
      where: { id },
      data,
      select: productSelect,
    });
  }

  async deleteProduct(id: number) {
    // Soft-delete if the product is referenced anywhere — invoices, challans,
    // stock ledger, or adjustment lines all need the row to stay around so
    // historical documents render correctly. Otherwise hard-delete.
    const [stockRefs, invoiceRefs, challanRefs, adjustmentRefs] = await Promise.all([
      prisma.stockTransaction.count({ where: { productId: id } }),
      prisma.invoiceItem.count({ where: { productId: id } }),
      prisma.challanItem.count({ where: { productId: id } }),
      prisma.stockAdjustmentItem.count({ where: { productId: id } }),
    ]);
    const referenced = stockRefs + invoiceRefs + challanRefs + adjustmentRefs > 0;
    if (referenced) {
      return prisma.product.update({
        where: { id },
        data: { isActive: false },
        select: productSelect,
      });
    }
    return prisma.product.delete({ where: { id } });
  }

  // ── Image management ──────────────────────────────────────────────

  async addImage(productId: number, url: string, sortOrder?: number) {
    const maxOrder = await prisma.productImage.aggregate({
      where: { productId },
      _max: { sortOrder: true },
    });
    const order = sortOrder ?? (maxOrder._max.sortOrder ?? -1) + 1;
    return prisma.productImage.create({ data: { productId, url, sortOrder: order } });
  }

  async deleteImage(productId: number, imageId: number) {
    const image = await prisma.productImage.findFirst({ where: { id: imageId, productId } });
    if (!image) return { error: 'Image not found' as const };
    await prisma.productImage.delete({ where: { id: imageId } });
    return { ok: true };
  }

  async reorderImages(productId: number, orderedIds: number[]) {
    await prisma.$transaction(
      orderedIds.map((id, i) =>
        prisma.productImage.updateMany({ where: { id, productId }, data: { sortOrder: i } }),
      ),
    );
    return prisma.productImage.findMany({ where: { productId }, orderBy: { sortOrder: 'asc' } });
  }
}

export const productsService = new ProductsService();
