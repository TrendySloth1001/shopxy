import prisma from '../../infra/db/prisma.js';
import { contactChangeLogService } from '../contact-change-log/contact-change-log.service.js';
import { cautionService } from '../caution/caution.service.js';

/// Tenant-scoped party (customer) operations. Every method takes
/// `shopId` so reads and writes stay isolated to the calling
/// merchant's address book; `assertOwns` is used before mutate ops to
/// reject cross-tenant attempts with a clean 404.
export class PartiesService {
  async createParty(
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
    return prisma.party.create({ data: { ...data, shopId } });
  }

  async listParties(
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
          city: true,
          state: true,
          stateCode: true,
          pinCode: true,
          panNumber: true,
          gstin: true,
          isActive: true,
          createdAt: true,
          updatedAt: true,
          _count: { select: { challans: true, invoices: true } },
        },
      }),
      prisma.party.count({ where }),
    ]);

    // Attach the held caution balance per party in one grouped query
    // (no N+1). Parties with no deposits get an implicit 0.
    const balances = await cautionService.balancesFor(
      shopId,
      parties.map((p) => p.id),
    );
    const withCaution = parties.map((p) => ({
      ...p,
      cautionBalance: balances.get(p.id) ?? 0,
    }));

    return { parties: withCaution, total };
  }

  async getPartyById(shopId: number, id: number) {
    return prisma.party.findFirst({
      where: { id, shopId },
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
  async getPartyOverview(shopId: number, id: number) {
    const party = await prisma.party.findFirst({
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
        isSystem: true,
        createdAt: true,
        updatedAt: true,
        linkedUserId: true,
        linkedUser: { select: { id: true, name: true, email: true } },
      },
    });
    if (!party) return null;

    const [counts, totalsByType, recentInvoices, recentChallans, balanceParts] =
      await Promise.all([
        Promise.all([
          prisma.invoice.count({ where: { partyId: id, shopId } }),
          prisma.challan.count({ where: { partyId: id, shopId } }),
        ]).then(([invoices, challans]) => ({ invoices, challans })),

        prisma.invoice.groupBy({
          by: ['type'],
          where: { partyId: id, shopId },
          _sum: { total: true },
          _count: { _all: true },
        }),

        prisma.invoice.findMany({
          where: { partyId: id, shopId },
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
          where: { partyId: id, shopId },
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

        Promise.all([
          prisma.invoice.aggregate({
            where: { partyId: id, shopId, type: 'SALE', status: 'CONFIRMED' },
            _sum: { total: true },
          }),
          prisma.payment.aggregate({
            where: { partyId: id, shopId, type: 'RECEIPT', voidedAt: null },
            _sum: { amount: true },
          }),
        ]),
      ]);

    const billed = Number(balanceParts[0]._sum.total?.toString() ?? '0');
    const received = Number(balanceParts[1]._sum.amount?.toString() ?? '0');
    const balance = billed - received;
    const cautionBalance = await cautionService.balance(shopId, id);

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
      balance,
      cautionBalance,
    };
  }

  async updateParty(
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
      const before = await tx.party.findFirst({
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
      const updated = await tx.party.update({ where: { id }, data });
      await contactChangeLogService.recordChanges({
        entityType: 'PARTY',
        entityId: id,
        before,
        after: data,
        changedById,
        tx,
      });
      return updated;
    });
  }

  async deleteParty(shopId: number, id: number) {
    // First confirm ownership so a 404 (not silent success) is returned
    // when a merchant tries to delete another shop's party.
    const owned = await prisma.party.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;
    const [invoiceRefs, challanRefs] = await Promise.all([
      prisma.invoice.count({ where: { partyId: id, shopId } }),
      prisma.challan.count({ where: { partyId: id, shopId } }),
    ]);
    if (invoiceRefs + challanRefs > 0) {
      return prisma.party.update({ where: { id }, data: { isActive: false } });
    }
    return prisma.party.delete({ where: { id } });
  }
}

export const partiesService = new PartiesService();
