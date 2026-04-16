import prisma from '../../infra/db/prisma.js';

export class ProductsService {
  createProduct(data: {
    name: string;
    description?: string;
    sku: string;
    barcode?: string;
    hsnCode?: string;
    imageUrl?: string;
    mrp: number;
    sellingPrice: number;
    purchasePrice: number;
    taxPercent?: number;
    stockQuantity?: number;
    lowStockThreshold?: number;
    unit?: string;
    categoryId?: number;
  }) {
    return prisma.product.create({
      data,
      include: { category: true },
    });
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
    const orderBy = { [options.sortBy]: options.sortOrder } as Record<
      string,
      'asc' | 'desc'
    >;

    if (options.lowStock) {
      where.isActive = true;
      const products = await prisma.product.findMany({
        where,
        orderBy,
        include: { category: true },
      });

      const filtered = products.filter((product) =>
        isLowStock(product.stockQuantity, product.lowStockThreshold)
      );

      return {
        products: filtered.slice(options.skip, options.skip + options.limit),
        total: filtered.length,
      };
    }

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy,
        skip: options.skip,
        take: options.limit,
        include: { category: true },
      }),
      prisma.product.count({ where }),
    ]);

    return { products, total };
  }

  lookupProduct(code: string) {
    return prisma.product.findFirst({
      where: {
        OR: [{ barcode: code }, { sku: code }],
      },
      include: { category: true },
    });
  }

  getProductById(id: number) {
    return prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        stockTransactions: { orderBy: { createdAt: 'desc' }, take: 20 },
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
      imageUrl?: string | null;
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
    }
  ) {
    return prisma.product.update({
      where: { id },
      data,
      include: { category: true },
    });
  }

  deleteProduct(id: number) {
    return prisma.product.delete({ where: { id } });
  }
}

function toNumber(value: unknown): number {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'bigint') return Number(value);
  if (typeof (value as { toNumber?: () => number }).toNumber === 'function') {
    return (value as { toNumber: () => number }).toNumber();
  }
  return Number(value);
}

function isLowStock(quantity: unknown, threshold: unknown): boolean {
  const qty = toNumber(quantity);
  const limit = toNumber(threshold);
  return qty > 0 && qty <= limit;
}

export const productsService = new ProductsService();
