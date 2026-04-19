import prisma from '../../infra/db/prisma.js';

export class DashboardService {
  async getStats() {
    const [
      totalProducts,
      activeProducts,
      totalCategories,
      outOfStockProducts,
      recentTransactions,
      activeStockRows,
    ] = await Promise.all([
      prisma.product.count(),
      prisma.product.count({ where: { isActive: true } }),
      prisma.category.count({ where: { isActive: true } }),
      prisma.product.count({
        where: { isActive: true, stockQuantity: { lte: 0 } },
      }),
      prisma.stockTransaction.findMany({
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: { product: { select: { id: true, name: true, sku: true, unit: true } } },
      }),
      prisma.product.findMany({
        where: { isActive: true },
        select: {
          stockQuantity: true,
          lowStockThreshold: true,
          purchasePrice: true,
        },
      }),
    ]);

    const lowStockCount = activeStockRows.reduce((count, row) => {
      return count + (isLowStock(row.stockQuantity, row.lowStockThreshold) ? 1 : 0);
    }, 0);

    const totalStockValue = activeStockRows.reduce((total, row) => {
      return total + toNumber(row.stockQuantity) * toNumber(row.purchasePrice);
    }, 0);

    return {
      totalProducts,
      activeProducts,
      totalCategories,
      lowStockCount,
      outOfStockCount: outOfStockProducts,
      totalStockValue,
      recentTransactions,
    };
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

export const dashboardService = new DashboardService();
