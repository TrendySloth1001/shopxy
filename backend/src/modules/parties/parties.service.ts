import prisma from '../../infra/db/prisma.js';

export class PartiesService {
  async createParty(data: {
    name: string;
    contactName?: string;
    phone?: string;
    email?: string;
    address?: string;
    gstin?: string;
  }) {
    return prisma.party.create({ data });
  }

  async listParties(options: {
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

    const [parties, total] = await Promise.all([
      prisma.party.findMany({
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
          _count: { select: { challans: true, invoices: true } },
        },
      }),
      prisma.party.count({ where }),
    ]);

    return { parties, total };
  }

  async getPartyById(id: number) {
    return prisma.party.findUnique({
      where: { id },
      include: {
        _count: { select: { challans: true, invoices: true } },
        challans: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true,
            challanNo: true,
            status: true,
            createdAt: true,
            _count: { select: { items: true } },
          },
        },
      },
    });
  }

  async updateParty(
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
    return prisma.party.update({ where: { id }, data });
  }

  async deleteParty(id: number) {
    // Unlink challans and invoices before deletion (keep denormalized partyName)
    await prisma.challan.updateMany({
      where: { partyId: id },
      data: { partyId: null },
    });
    await prisma.invoice.updateMany({
      where: { partyId: id },
      data: { partyId: null },
    });
    return prisma.party.delete({ where: { id } });
  }
}

export const partiesService = new PartiesService();
