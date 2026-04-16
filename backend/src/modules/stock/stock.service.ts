import prisma from '../../infra/db/prisma.js';

export class StockService {
  async createTransaction(data: {
    productId: number;
    type: string;
    quantity: number;
    unitPrice?: number;
    note?: string;
  }) {
    const product = await prisma.product.findUnique({
      where: { id: data.productId },
    });

    if (!product) {
      return { error: 'Product not found' as const };
    }

    const quantityDelta = data.type === 'STOCK_OUT' ? -data.quantity : data.quantity;

    if (data.type === 'STOCK_OUT') {
      const currentStock = Number(product.stockQuantity);
      if (currentStock < data.quantity) {
        return {
          error: 'Insufficient stock' as const,
          available: currentStock,
          requested: data.quantity,
        };
      }
    }

    const [transaction] = await prisma.$transaction([
      prisma.stockTransaction.create({
        data: {
          productId: data.productId,
          type: data.type,
          quantity: data.quantity,
          unitPrice: data.unitPrice,
          note: data.note,
        },
        include: { product: { select: { id: true, name: true, sku: true } } },
      }),
      prisma.product.update({
        where: { id: data.productId },
        data: { stockQuantity: { increment: quantityDelta } },
      }),
    ]);

    return { transaction };
  }

  async listTransactions(options: {
    productId?: number;
    type?: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
    if (options.productId) where.productId = options.productId;
    if (options.type) where.type = options.type;

    const [transactions, total] = await Promise.all([
      prisma.stockTransaction.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        include: { product: { select: { id: true, name: true, sku: true, unit: true } } },
      }),
      prisma.stockTransaction.count({ where }),
    ]);

    return { transactions, total };
  }
}

export const stockService = new StockService();
