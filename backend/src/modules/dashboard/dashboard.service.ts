import prisma from '../../infra/db/prisma.js';

export class DashboardService {
  /// All metrics scope to `shopId`. Pre-Phase-0 this method aggregated
  /// across every shop — fine when there was implicitly one, broken now.
  /// Categories are intentionally NOT scoped (they're marketplace-global
  /// taxonomy curated by platform admins, shared across all shops).
  async getStats(shopId: number) {
    const [
      totalProducts,
      activeProducts,
      totalCategories,
      outOfStockProducts,
      lowStockRow,
      recentTransactions,
      draftInvoiceCount,
      recentDrafts,
    ] = await Promise.all([
      prisma.product.count({ where: { shopId } }),
      prisma.product.count({ where: { shopId, isActive: true } }),
      prisma.category.count({ where: { isActive: true } }),
      prisma.product.count({
        where: { shopId, isActive: true, stockQuantity: { lte: 0 } },
      }),
      // Indexed SQL COUNT — replaces the previous "fetch every active
      // product into Node, count in JS" pattern that was O(catalog size)
      // on memory and bandwidth per dashboard hit.
      prisma.$queryRaw<{ count: bigint }[]>`
        SELECT COUNT(*)::bigint AS count FROM products
         WHERE shop_id = ${shopId}
           AND is_active = true
           AND stock_quantity > 0
           AND stock_quantity <= low_stock_threshold
      `,
      prisma.stockTransaction.findMany({
        where: { product: { shopId } },
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: { product: { select: { id: true, name: true, sku: true, unit: true } } },
      }),
      prisma.invoice.count({ where: { status: 'DRAFT' } }),
      prisma.invoice.findMany({
        where: { status: 'DRAFT' },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          invoiceNo: true,
          type: true,
          total: true,
          customerName: true,
          vendorName: true,
          createdAt: true,
          _count: { select: { items: true } },
        },
      }),
    ]);
    const lowStockCount = Number(lowStockRow[0]?.count ?? 0);

    // Inventory value comes from the FIFO cost layers — the real cost
    // basis for what's still on the shelf. Falls back to qty × purchase
    // price for any product without layers (legacy / pre-ledger stock).
    const layerSum = await prisma.$queryRaw<
      { layer_value: string | null }[]
    >`SELECT COALESCE(SUM(cl.qty_remaining * cl.unit_cost), 0)::text AS layer_value
        FROM cost_layers cl
        JOIN products p ON p.id = cl.product_id
       WHERE p.shop_id = ${shopId} AND p.is_active = true AND cl.qty_remaining > 0`;
    const layerValue = toNumber(layerSum[0]?.layer_value ?? 0);

    // Fallback: products that have stock but no layers (orphans from
    // before the ledger was wired up).
    const orphans = await prisma.$queryRaw<
      { fallback_value: string | null }[]
    >`SELECT COALESCE(SUM(p.stock_quantity * p.purchase_price), 0)::text AS fallback_value
        FROM products p
        LEFT JOIN cost_layers cl ON cl.product_id = p.id AND cl.qty_remaining > 0
       WHERE p.shop_id = ${shopId} AND p.is_active = true AND p.stock_quantity > 0 AND cl.id IS NULL`;
    const fallbackValue = toNumber(orphans[0]?.fallback_value ?? 0);

    const totalStockValue = layerValue + fallbackValue;

    return {
      totalProducts,
      activeProducts,
      totalCategories,
      lowStockCount,
      outOfStockCount: outOfStockProducts,
      totalStockValue,
      recentTransactions,
      draftInvoices: {
        count: draftInvoiceCount,
        recent: recentDrafts,
      },
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

export const dashboardService = new DashboardService();
