import prisma from '../../infra/db/prisma.js';

export class DashboardService {
  async getStats() {
    const [
      totalProducts,
      activeProducts,
      totalCategories,
      lowStockProducts,
      outOfStockProducts,
      recentTransactions,
    ] = await Promise.all([
      prisma.product.count(),
      prisma.product.count({ where: { isActive: true } }),
      prisma.category.count({ where: { isActive: true } }),
      prisma.$queryRaw<[{ count: bigint }]>`
        SELECT COUNT(*) as count FROM products
        WHERE is_active = true
          AND stock_quantity <= low_stock_threshold
          AND stock_quantity > 0
      `,
      prisma.product.count({
        where: { isActive: true, stockQuantity: { lte: 0 } },
      }),
      prisma.stockTransaction.findMany({
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: { product: { select: { id: true, name: true, sku: true, unit: true } } },
      }),
    ]);

    const stockValueResult = await prisma.$queryRaw<[{ total: string | null }]>`
      SELECT COALESCE(SUM(stock_quantity * purchase_price), 0)::text as total
      FROM products WHERE is_active = true
    `;

    const totalStockValue = parseFloat(stockValueResult[0]?.total ?? '0');

    return {
      totalProducts,
      activeProducts,
      totalCategories,
      lowStockCount: Number(lowStockProducts[0]?.count ?? 0),
      outOfStockCount: outOfStockProducts,
      totalStockValue,
      recentTransactions,
    };
  }
}

export const dashboardService = new DashboardService();
