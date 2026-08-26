import prisma from '../../infra/db/prisma.js';
import { invoicesService } from '../invoices/invoices.service.js';

export class StockService {
  async createTransaction(
    shopId: number,
    data: {
      productId: number;
      type: string;
      quantity: number;
      unitPrice?: number;
      vendorId?: number;
      partyId?: number;
      note?: string;
      createdById?: number;
    },
  ) {
    const product = await prisma.product.findFirst({
      where: { id: data.productId, shopId },
      select: {
        id: true,
        isActive: true,
        purchasePrice: true,
        sellingPrice: true,
        taxPercent: true,
      },
    });
    if (!product) return { error: 'Product not found' as const };
    if (!product.isActive) return { error: 'Product is inactive' as const };

    const direction = data.type === 'STOCK_OUT' ? 'OUT' : 'IN';

    if (direction === 'IN') {
      const unitPrice = data.unitPrice ?? Number(product.purchasePrice);
      const result = await invoicesService.createInvoice({
        shopId,
        type: 'PURCHASE',
        vendorId: data.vendorId,
        note: data.note,
        items: [
          {
            productId: data.productId,
            quantity: data.quantity,
            unitPrice,
            taxPercent: Number(product.taxPercent ?? 0),
          },
        ],
      });
      if ('error' in result) return { error: result.error };
      return { draftInvoice: result.invoice };
    }

    let partyId = data.partyId;
    if (!partyId) {
      const walkin = await prisma.party.findFirst({
        where: { shopId, isSystem: true, name: 'Walk-in Customer' },
        select: { id: true },
      });
      if (!walkin) {
        return { error: 'Walk-in Customer party missing — run migrations' as const };
      }
      partyId = walkin.id;
    }

    const unitPrice = data.unitPrice ?? Number(product.sellingPrice);
    const result = await invoicesService.createInvoice({
      shopId,
      type: 'SALE',
      partyId,
      note: data.note,
      items: [
        {
          productId: data.productId,
          quantity: data.quantity,
          unitPrice,
          taxPercent: Number(product.taxPercent ?? 0),
        },
      ],
    });
    if ('error' in result) return { error: result.error };
    return { draftInvoice: result.invoice };
  }

  async listSuppliers(
    shopId: number,
    options: { query?: string; productId?: number; limit: number },
  ) {
    const query = options.query?.trim();

    const vendorTxWhere: Record<string, unknown> = { direction: 'IN', shopId };
    if (options.productId) vendorTxWhere.productId = options.productId;

    const vendorWhere: Record<string, unknown> = {
      shopId,
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

    const freeTextWhere: Record<string, unknown> = {
      shopId,
      direction: 'IN',
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

  async listTransactions(
    shopId: number,
    options: {
      productId?: number;
      type?: string;
      direction?: string;
      reasonCode?: string;
      sourceType?: string;
      sourceId?: number;
      vendorId?: number;
      page: number;
      limit: number;
      skip: number;
    },
  ) {
    const where: Record<string, unknown> = { shopId };
    if (options.productId) where.productId = options.productId;
    if (options.type) where.type = options.type;
    if (options.direction) where.direction = options.direction;
    if (options.reasonCode) where.reasonCode = options.reasonCode;
    if (options.sourceType) where.sourceType = options.sourceType;
    if (options.sourceId) where.sourceId = options.sourceId;
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
          createdBy: { select: { id: true, name: true } },
        },
      }),
      prisma.stockTransaction.count({ where }),
    ]);

    return { transactions, total };
  }
}

export const stockService = new StockService();
