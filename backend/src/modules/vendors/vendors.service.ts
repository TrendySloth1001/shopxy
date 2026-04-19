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
    // Unlink transactions before deletion
    await prisma.stockTransaction.updateMany({
      where: { vendorId: id },
      data: { vendorId: null },
    });
    return prisma.vendor.delete({ where: { id } });
  }
}

export const vendorsService = new VendorsService();
