import prisma from '../../infra/db/prisma.js';
import { type PurchasePriceMode } from '../../shared/constants/index.js';

const DEFAULT_PURCHASE_PRICE_MODE: PurchasePriceMode = 'WEIGHTED_AVERAGE';

export class StockService {
  async createTransaction(data: {
    productId: number;
    type: string;
    quantity: number;
    unitPrice?: number;
    supplierName?: string;
    vendorId?: number;
    purchasePriceMode?: PurchasePriceMode;
    note?: string;
  }) {
    const product = await prisma.product.findUnique({ where: { id: data.productId } });
    if (!product) return { error: 'Product not found' as const };

    // Resolve vendor name as supplierName when vendorId provided
    let resolvedSupplierName = data.supplierName?.trim() || undefined;
    if (data.vendorId) {
      const vendor = await prisma.vendor.findUnique({
        where: { id: data.vendorId },
        select: { name: true },
      });
      if (!vendor) return { error: 'Vendor not found' as const };
      resolvedSupplierName = vendor.name;
    }

    const quantityDelta = data.type === 'STOCK_OUT' ? -data.quantity : data.quantity;
    const currentStock = Number(product.stockQuantity);
    const currentPurchasePrice = Number(product.purchasePrice);
    const unitPrice = data.unitPrice;

    if (data.purchasePriceMode && data.type !== 'STOCK_IN') {
      return { error: 'Purchase price mode can only be used for stock-in transactions' as const };
    }
    if (data.purchasePriceMode && unitPrice === undefined) {
      return { error: 'Unit price is required when purchase price mode is set' as const };
    }
    if (data.type === 'STOCK_OUT' && currentStock < data.quantity) {
      return { error: 'Insufficient stock' as const, available: currentStock, requested: data.quantity };
    }

    let purchasePriceMode: PurchasePriceMode | undefined;
    let purchasePriceBefore: number | undefined;
    let purchasePriceAfter: number | undefined;

    if (data.type === 'STOCK_IN' && unitPrice !== undefined) {
      purchasePriceMode = data.purchasePriceMode ?? DEFAULT_PURCHASE_PRICE_MODE;
      purchasePriceBefore = this.roundCurrency(currentPurchasePrice);
      purchasePriceAfter = this.computeNextPurchasePrice({
        mode: purchasePriceMode,
        currentPurchasePrice,
        currentStock,
        incomingQuantity: data.quantity,
        incomingUnitPrice: unitPrice,
      });
    }

    const productUpdateData: { stockQuantity: { increment: number }; purchasePrice?: number } = {
      stockQuantity: { increment: quantityDelta },
    };
    if (purchasePriceAfter !== undefined) productUpdateData.purchasePrice = purchasePriceAfter;

    const [transaction] = await prisma.$transaction([
      prisma.stockTransaction.create({
        data: {
          productId: data.productId,
          type: data.type,
          quantity: data.quantity,
          unitPrice: data.unitPrice,
          supplierName: resolvedSupplierName,
          vendorId: data.vendorId ?? null,
          purchasePriceMode,
          purchasePriceBefore,
          purchasePriceAfter,
          note: data.note,
        },
        include: {
          product: { select: { id: true, name: true, sku: true, purchasePrice: true } },
          vendor: { select: { id: true, name: true } },
        },
      }),
      prisma.product.update({ where: { id: data.productId }, data: productUpdateData }),
    ]);

    return { transaction };
  }

  private computeNextPurchasePrice(args: {
    mode: PurchasePriceMode;
    currentPurchasePrice: number;
    currentStock: number;
    incomingQuantity: number;
    incomingUnitPrice: number;
  }): number {
    const { mode, currentPurchasePrice, currentStock, incomingQuantity, incomingUnitPrice } = args;
    if (mode === 'KEEP_CURRENT') return this.roundCurrency(currentPurchasePrice);
    if (mode === 'USE_LATEST') return this.roundCurrency(incomingUnitPrice);
    const nextStock = currentStock + incomingQuantity;
    if (nextStock <= 0) return this.roundCurrency(incomingUnitPrice);
    return this.roundCurrency(
      (currentStock * currentPurchasePrice + incomingQuantity * incomingUnitPrice) / nextStock,
    );
  }

  private roundCurrency(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }

  async listSuppliers(options: { query?: string; productId?: number; limit: number }) {
    const query = options.query?.trim();

    // 1. Structured vendors that have stock-in transactions for this product
    const vendorTxWhere: Record<string, unknown> = { type: 'STOCK_IN' };
    if (options.productId) vendorTxWhere.productId = options.productId;

    const vendorWhere: Record<string, unknown> = {
      stockTransactions: { some: vendorTxWhere },
      isActive: true,
    };
    if (query) vendorWhere.name = { contains: query, mode: 'insensitive' };

    const vendors = await prisma.vendor.findMany({
      where: vendorWhere,
      select: { id: true, name: true, phone: true },
      orderBy: { name: 'asc' },
      take: options.limit,
    });

    // 2. Legacy free-text supplier names (vendorId is null)
    const freeTextWhere: Record<string, unknown> = {
      type: 'STOCK_IN',
      supplierName: { not: null },
      vendorId: null,
    };
    if (options.productId) freeTextWhere.productId = options.productId;
    if (query) freeTextWhere.supplierName = { contains: query, mode: 'insensitive' };

    const rows = await prisma.stockTransaction.findMany({
      where: freeTextWhere,
      select: { supplierName: true },
      orderBy: { createdAt: 'desc' },
      take: options.limit * 10,
    });

    const seen = new Set<string>();
    const freeTextSuppliers: string[] = [];
    for (const row of rows) {
      const name = row.supplierName?.trim();
      if (!name) continue;
      const key = name.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      freeTextSuppliers.push(name);
      if (freeTextSuppliers.length >= options.limit) break;
    }

    return { vendors, freeTextSuppliers };
  }

  async listTransactions(options: {
    productId?: number;
    type?: string;
    vendorId?: number;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
    if (options.productId) where.productId = options.productId;
    if (options.type) where.type = options.type;
    if (options.vendorId) where.vendorId = options.vendorId;

    const [transactions, total] = await Promise.all([
      prisma.stockTransaction.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        include: {
          product: { select: { id: true, name: true, sku: true, unit: true } },
          vendor: { select: { id: true, name: true } },
        },
      }),
      prisma.stockTransaction.count({ where }),
    ]);

    return { transactions, total };
  }
}

export const stockService = new StockService();
