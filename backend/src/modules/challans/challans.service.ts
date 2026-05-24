import prisma from '../../infra/db/prisma.js';
import { ledgerService } from '../ledger/ledger.service.js';
import { nextChallanNo, nextInvoiceNo } from '../../shared/numbering/sequences.js';

function round2(v: number): number {
  return Math.round((v + Number.EPSILON) * 100) / 100;
}

export class ChallansService {
  async createChallan(
    shopId: number,
    data: {
      partyId?: number;
      partyName?: string;
      partyPhone?: string;
      note?: string;
      items: { productId: number; quantity: number }[];
      createdById?: number;
    },
  ) {
    if (data.items.length === 0) {
      return { error: 'Challan must have at least one item' as const };
    }

    let partyId: number | null = null;
    let partyName = data.partyName?.trim() ?? '';
    let partyPhone = data.partyPhone ?? null;

    if (data.partyId) {
      const party = await prisma.party.findFirst({
        where: { id: data.partyId, shopId },
        select: { id: true, name: true, phone: true, isActive: true },
      });
      if (!party) return { error: 'Party not found' as const };
      if (!party.isActive) return { error: 'Party is inactive' as const };
      partyId = party.id;
      partyName = party.name;
      partyPhone = party.phone ?? partyPhone;
    }

    if (!partyName) return { error: 'Party name is required' as const };

    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds }, shopId },
      select: { id: true, name: true, sku: true, unit: true },
    });

    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    const challanNo = await nextChallanNo(shopId);

    const challan = await prisma.challan.create({
      data: {
        shopId,
        challanNo,
        partyId,
        partyName,
        partyPhone,
        note: data.note ?? null,
        items: {
          create: data.items.map((item) => {
            const product = productMap.get(item.productId)!;
            return {
              productId: item.productId,
              productName: product.name,
              productSku: product.sku,
              unit: product.unit,
              quantity: item.quantity,
            };
          }),
        },
      },
      include: { items: true, party: true },
    });

    // Post stock movement to the ledger — goods have physically left
    // the building. If posting fails (e.g. insufficient stock), unwind
    // the challan so the database stays consistent.
    const result = await ledgerService.post({
      shopId: shopId,
      direction: 'OUT',
      reasonCode: 'SALE',
      sourceType: 'CHALLAN',
      sourceId: challan.id,
      createdById: data.createdById,
      counterpartyName: challan.partyName,
      counterpartyGstin: challan.party?.gstin ?? undefined,
      note: `Challan ${challan.challanNo}`,
      lines: challan.items.map((it) => ({
        productId: it.productId,
        quantity: Number(it.quantity),
        sourceLineId: it.id,
      })),
    });

    if ('error' in result) {
      await prisma.challan.delete({ where: { id: challan.id } });
      if (result.error === 'Insufficient stock') {
        return {
          error: 'Insufficient stock for one or more items' as const,
          productId: result.productId,
          available: result.available,
          requested: result.requested,
        };
      }
      return { error: result.error as string };
    }

    return { challan };
  }

  async listChallans(
    shopId: number,
    options: {
      status?: string;
      search: string;
      page: number;
      limit: number;
      skip: number;
    },
  ) {
    const where: Record<string, unknown> = { shopId };
    if (options.status) where.status = options.status;
    if (options.search) {
      where.OR = [
        { challanNo: { contains: options.search, mode: 'insensitive' } },
        { partyName: { contains: options.search, mode: 'insensitive' } },
        { partyPhone: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    const [challans, total] = await Promise.all([
      prisma.challan.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        select: {
          id: true,
          challanNo: true,
          status: true,
          partyId: true,
          partyName: true,
          partyPhone: true,
          party: { select: { id: true, name: true, phone: true } },
          invoiceId: true,
          createdAt: true,
          _count: { select: { items: true } },
        },
      }),
      prisma.challan.count({ where }),
    ]);

    return { challans, total };
  }

  getChallanById(shopId: number, id: number) {
    return prisma.challan.findFirst({
      where: { id, shopId },
      include: {
        items: { orderBy: { id: 'asc' } },
        party: true,
        invoice: { select: { id: true, invoiceNo: true, status: true } },
      },
    });
  }

  async cancelChallan(shopId: number, id: number, createdById?: number) {
    const challan = await prisma.challan.findFirst({
      where: { id, shopId },
      select: { status: true },
    });
    if (!challan) return { error: 'Challan not found' as const };
    if (challan.status !== 'PENDING') {
      return { error: 'Only pending challans can be cancelled' as const };
    }

    // Reverse all ledger entries posted by this challan.
    const entries = await prisma.stockTransaction.findMany({
      where: { sourceType: 'CHALLAN', sourceId: id, reversesId: null, shopId },
      select: { id: true },
    });
    for (const entry of entries) {
      const result = await ledgerService.reverse(entry.id, {
        reasonCode: 'RETURN_IN',
        sourceType: 'CHALLAN',
        sourceId: id,
        createdById,
        note: 'Challan cancelled',
      });
      if ('error' in result) {
        return { error: `Reversal failed: ${result.error}` as const };
      }
    }

    await prisma.challan.update({ where: { id }, data: { status: 'CANCELLED' } });
    return { ok: true };
  }

  async convertToInvoice(
    shopId: number,
    id: number,
    data?: { customerName?: string; customerGstin?: string; discount?: number; note?: string },
  ) {
    const challan = await prisma.challan.findFirst({
      where: { id, shopId },
      include: { items: true, party: true },
    });

    if (!challan) return { error: 'Challan not found' as const };
    if (challan.status !== 'PENDING') {
      return { error: 'Only pending challans can be converted' as const };
    }
    if (challan.items.length === 0) {
      return { error: 'Challan has no items' as const };
    }

    const productIds = challan.items.map((i) => i.productId);
    const products = await prisma.product.findMany({
      where: { id: { in: productIds }, shopId },
      select: { id: true, sellingPrice: true, taxPercent: true },
    });
    const priceMap = new Map(products.map((p) => [p.id, p]));

    let subtotal = 0;
    let taxAmount = 0;
    const headerDiscount = data?.discount ?? 0;

    const itemsData = challan.items.map((item) => {
      const product = priceMap.get(item.productId);
      const unitPrice = product ? Number(product.sellingPrice) : 0;
      const taxPct = product ? Number(product.taxPercent) : 0;
      const qty = Number(item.quantity);
      const base = qty * unitPrice;
      const tax = (base * taxPct) / 100;
      const total = round2(base + tax);
      subtotal += base;
      taxAmount += tax;
      return {
        productId: item.productId,
        productName: item.productName,
        productSku: item.productSku,
        unit: item.unit,
        quantity: qty,
        unitPrice,
        taxPercent: taxPct,
        discount: 0,
        total,
      };
    });

    const total = round2(subtotal + taxAmount - headerDiscount);
    const invoiceDate = new Date();
    const { invoiceNo, financialYear } = await nextInvoiceNo(
      shopId,
      'SALE',
      'TAX_INVOICE',
      invoiceDate,
    );

    const invoice = await prisma.$transaction(async (tx) => {
      const newInvoice = await tx.invoice.create({
        data: {
          shopId,
          invoiceNo,
          financialYear,
          type: 'SALE',
          status: 'DRAFT',
          partyId: challan.partyId,
          customerName: data?.customerName ?? challan.partyName,
          customerPhone: challan.partyPhone ?? challan.party?.phone ?? null,
          customerGstin: data?.customerGstin ?? challan.party?.gstin ?? null,
          subtotal: round2(subtotal),
          taxAmount: round2(taxAmount),
          discount: headerDiscount,
          total,
          note: data?.note ?? challan.note ?? null,
          items: { create: itemsData },
        },
        include: { items: true, party: true },
      });

      await tx.challan.update({
        where: { id },
        data: { status: 'CONVERTED', invoiceId: newInvoice.id },
      });

      return newInvoice;
    });

    return { invoice };
  }
}

export const challansService = new ChallansService();
