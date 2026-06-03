import prisma from '../../infra/db/prisma.js';
import { contactChangeLogService } from '../contact-change-log/contact-change-log.service.js';

/// Tenant-scoped vendor (supplier) operations. Every method takes
/// `shopId` so reads and writes stay isolated to the calling merchant.
export class VendorsService {
  async createVendor(
    shopId: number,
    data: {
      name: string;
      contactName?: string;
      phone?: string;
      email?: string;
      address?: string;
      city?: string;
      state?: string;
      stateCode?: string;
      pinCode?: string;
      panNumber?: string;
      gstin?: string;
    },
  ) {
    return prisma.vendor.create({ data: { ...data, shopId } });
  }

  async listVendors(
    shopId: number,
    options: {
      search: string;
      activeOnly: boolean;
      page: number;
      limit: number;
      skip: number;
    },
  ) {
    const where: Record<string, unknown> = { shopId };
    if (options.activeOnly) where.isActive = true;
    if (options.search) {
      where.OR = [
        { name: { contains: options.search, mode: 'insensitive' } },
        { contactName: { contains: options.search, mode: 'insensitive' } },
        { phone: { contains: options.search, mode: 'insensitive' } },
        { email: { contains: options.search, mode: 'insensitive' } },
        { gstin: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    const [vendors, total] = await Promise.all([
      prisma.vendor.findMany({
        where,
        orderBy: { name: 'asc' },
        skip: options.skip,
        take: options.limit,
        select: {
          id: true,
          name: true,
          contactName: true,
          phone: true,
          email: true,
          address: true,
          city: true,
          state: true,
          stateCode: true,
          pinCode: true,
          panNumber: true,
          gstin: true,
          isActive: true,
          createdAt: true,
          updatedAt: true,
          _count: { select: { stockTransactions: true, invoices: true } },
        },
      }),
      prisma.vendor.count({ where }),
    ]);

    return { vendors, total };
  }

  async getVendorOverview(shopId: number, id: number) {
    const vendor = await prisma.vendor.findFirst({
      where: { id, shopId },
      select: {
        id: true,
        name: true,
        contactName: true,
        phone: true,
        email: true,
        address: true,
        city: true,
        state: true,
        stateCode: true,
        pinCode: true,
        panNumber: true,
        gstin: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        linkedUserId: true,
        linkedUser: { select: { id: true, name: true, email: true } },
      },
    });
    if (!vendor) return null;

    const [counts, totalsByType, recentInvoices, recentStockIns, balanceParts] =
      await Promise.all([
        Promise.all([
          prisma.invoice.count({ where: { vendorId: id, shopId } }),
          prisma.stockTransaction.count({
            where: { vendorId: id, shopId, direction: 'IN' },
          }),
        ]).then(([invoices, stockIns]) => ({ invoices, stockIns })),

        prisma.invoice.groupBy({
          by: ['type'],
          where: { vendorId: id, shopId },
          _sum: { total: true },
          _count: { _all: true },
        }),

        prisma.invoice.findMany({
          where: { vendorId: id, shopId },
          orderBy: { invoiceDate: 'desc' },
          take: 15,
          select: {
            id: true,
            invoiceNo: true,
            type: true,
            status: true,
            invoiceDate: true,
            total: true,
            _count: { select: { items: true } },
          },
        }),

        prisma.stockTransaction.findMany({
          where: { vendorId: id, shopId, direction: 'IN' },
          orderBy: { createdAt: 'desc' },
          take: 15,
          select: {
            id: true,
            quantity: true,
            unitCost: true,
            totalValue: true,
            createdAt: true,
            reasonCode: true,
            sourceType: true,
            product: { select: { id: true, name: true, sku: true, unit: true } },
          },
        }),

        Promise.all([
          prisma.invoice.aggregate({
            where: { vendorId: id, shopId, type: 'PURCHASE', status: 'CONFIRMED' },
            _sum: { total: true },
          }),
          prisma.payment.aggregate({
            where: { vendorId: id, shopId, type: 'PAYMENT', voidedAt: null },
            _sum: { amount: true },
          }),
        ]),
      ]);

    const billed = Number(balanceParts[0]._sum.total?.toString() ?? '0');
    const paid = Number(balanceParts[1]._sum.amount?.toString() ?? '0');
    const balance = billed - paid;

    const lastInvoice = recentInvoices[0]?.invoiceDate ?? null;
    const lastStockIn = recentStockIns[0]?.createdAt ?? null;
    const lastActivityAt =
      lastInvoice && lastStockIn
        ? lastInvoice > lastStockIn
          ? lastInvoice
          : lastStockIn
        : lastInvoice ?? lastStockIn;

    return {
      vendor,
      counts,
      totals: totalsByType.map((t) => ({
        type: t.type,
        count: t._count._all,
        total: t._sum.total ?? 0,
      })),
      recentInvoices,
      recentStockIns,
      lastActivityAt,
      balance,
    };
  }

  async getVendorById(shopId: number, id: number) {
    return prisma.vendor.findFirst({
      where: { id, shopId },
      include: {
        _count: { select: { stockTransactions: true, invoices: true } },
        stockTransactions: {
          where: { type: 'STOCK_IN' },
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true,
            quantity: true,
            unitPrice: true,
            createdAt: true,
            product: { select: { id: true, name: true, sku: true, unit: true } },
          },
        },
      },
    });
  }

  async updateVendor(
    shopId: number,
    id: number,
    data: {
      name?: string;
      contactName?: string | null;
      phone?: string | null;
      email?: string | null;
      address?: string | null;
      city?: string | null;
      state?: string | null;
      stateCode?: string | null;
      pinCode?: string | null;
      panNumber?: string | null;
      gstin?: string | null;
      isActive?: boolean;
    },
    changedById: number | null = null,
  ) {
    return prisma.$transaction(async (tx) => {
      const before = await tx.vendor.findFirst({
        where: { id, shopId },
        select: {
          name: true,
          contactName: true,
          phone: true,
          email: true,
          address: true,
          city: true,
          state: true,
          stateCode: true,
          pinCode: true,
          panNumber: true,
          gstin: true,
          isActive: true,
        },
      });
      if (!before) return null;
      const updated = await tx.vendor.update({ where: { id }, data });
      await contactChangeLogService.recordChanges({
        entityType: 'VENDOR',
        entityId: id,
        before,
        after: data,
        changedById,
        tx,
      });
      return updated;
    });
  }

  async deleteVendor(shopId: number, id: number) {
    const owned = await prisma.vendor.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;
    const [invoiceRefs, stockRefs] = await Promise.all([
      prisma.invoice.count({ where: { vendorId: id, shopId } }),
      prisma.stockTransaction.count({ where: { vendorId: id, shopId } }),
    ]);
    if (invoiceRefs + stockRefs > 0) {
      return prisma.vendor.update({ where: { id }, data: { isActive: false } });
    }
    return prisma.vendor.delete({ where: { id } });
  }
}

export const vendorsService = new VendorsService();
