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

  /// One-shot detail payload for the party page. Pulls party header,
  /// recent invoices + challans, totals grouped by invoice type, and the
  /// linked-user identity in parallel. Used by the merchant-side party
  /// detail screen.
  async getPartyOverview(id: number) {
    const party = await prisma.party.findUnique({
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
        isSystem: true,
        createdAt: true,
        updatedAt: true,
        linkedUserId: true,
        linkedUser: { select: { id: true, name: true, email: true } },
      },
    });
    if (!party) return null;

    const [counts, totalsByType, recentInvoices, recentChallans] =
      await Promise.all([
        // Aggregate counts — cheap and avoids two extra queries below.
        Promise.all([
          prisma.invoice.count({ where: { partyId: id } }),
          prisma.challan.count({ where: { partyId: id } }),
        ]).then(([invoices, challans]) => ({ invoices, challans })),

        // Sum totals per invoice type so the detail page can show
        // sales / returns / net side by side in a single round trip.
        prisma.invoice.groupBy({
          by: ['type'],
          where: { partyId: id },
          _sum: { total: true },
          _count: { _all: true },
        }),

        prisma.invoice.findMany({
          where: { partyId: id },
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

        prisma.challan.findMany({
          where: { partyId: id },
          orderBy: { createdAt: 'desc' },
          take: 15,
          select: {
            id: true,
            challanNo: true,
            status: true,
            createdAt: true,
            invoiceId: true,
            _count: { select: { items: true } },
          },
        }),
      ]);

    // Most recent activity across both invoices and challans.
    const lastInvoice = recentInvoices[0]?.invoiceDate ?? null;
    const lastChallan = recentChallans[0]?.createdAt ?? null;
    const lastActivityAt =
      lastInvoice && lastChallan
        ? lastInvoice > lastChallan
          ? lastInvoice
          : lastChallan
        : lastInvoice ?? lastChallan;

    return {
      party,
      counts,
      totals: totalsByType.map((t) => ({
        type: t.type,
        count: t._count._all,
        total: t._sum.total ?? 0,
      })),
      recentInvoices,
      recentChallans,
      lastActivityAt,
    };
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
    // Soft-delete when the party is referenced anywhere — invoices and
    // challans snapshot customer identity, but keeping the party row lets
    // users restore it later by re-activating.
    const [invoiceRefs, challanRefs] = await Promise.all([
      prisma.invoice.count({ where: { partyId: id } }),
      prisma.challan.count({ where: { partyId: id } }),
    ]);
    if (invoiceRefs + challanRefs > 0) {
      return prisma.party.update({ where: { id }, data: { isActive: false } });
    }
    return prisma.party.delete({ where: { id } });
  }
}

export const partiesService = new PartiesService();
