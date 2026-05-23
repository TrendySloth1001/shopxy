import prisma from '../../infra/db/prisma.js';

export class VendorsService {
  async createVendor(data: {
    name: string;
    contactName?: string;
    phone?: string;
    email?: string;
    address?: string;
    gstin?: string;
  }) {
    return prisma.vendor.create({ data });
  }

  async listVendors(options: {
    search: string;
    activeOnly: boolean;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
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

  /// One-shot detail payload for the vendor page. Pulls vendor header,
  /// recent purchase invoices, recent inbound stock ledger entries,
  /// totals grouped by invoice type and the linked-user identity in
  /// parallel. Mirrors `partiesService.getPartyOverview`.
  async getVendorOverview(id: number) {
    const vendor = await prisma.vendor.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        contactName: true,
        phone: true,
        email: true,
        address: true,
        gstin: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        linkedUserId: true,
        linkedUser: { select: { id: true, name: true, email: true } },
      },
    });
    if (!vendor) return null;

    const [counts, totalsByType, recentInvoices, recentStockIns] =
      await Promise.all([
        Promise.all([
          prisma.invoice.count({ where: { vendorId: id } }),
          prisma.stockTransaction.count({
            where: { vendorId: id, direction: 'IN' },
          }),
        ]).then(([invoices, stockIns]) => ({ invoices, stockIns })),

        prisma.invoice.groupBy({
          by: ['type'],
          where: { vendorId: id },
          _sum: { total: true },
          _count: { _all: true },
        }),

        prisma.invoice.findMany({
          where: { vendorId: id },
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
          where: { vendorId: id, direction: 'IN' },
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
      ]);

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
    };
  }

  async getVendorById(id: number) {
    return prisma.vendor.findUnique({
      where: { id },
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
    id: number,
    data: {
      name?: string;
      contactName?: string | null;
      phone?: string | null;
      email?: string | null;
      address?: string | null;
      gstin?: string | null;
      isActive?: boolean;
    },
  ) {
    return prisma.vendor.update({ where: { id }, data });
  }

  async deleteVendor(id: number) {
    // Soft-delete when the vendor is referenced anywhere — invoices and
    // ledger rows snapshot vendor identity now, but keeping the row lets
    // users restore the vendor by toggling isActive back on.
    const [invoiceRefs, stockRefs] = await Promise.all([
      prisma.invoice.count({ where: { vendorId: id } }),
      prisma.stockTransaction.count({ where: { vendorId: id } }),
    ]);
    if (invoiceRefs + stockRefs > 0) {
      return prisma.vendor.update({ where: { id }, data: { isActive: false } });
    }
    return prisma.vendor.delete({ where: { id } });
  }
}

export const vendorsService = new VendorsService();
