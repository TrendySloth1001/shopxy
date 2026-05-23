import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { invoicesService } from '../invoices/invoices.service.js';

const itemSelect = {
  id: true,
  productId: true,
  productName: true,
  productSku: true,
  unit: true,
  quantity: true,
  unitPrice: true,
  total: true,
} satisfies Prisma.PurchaseRequestItemSelect;

const listSelect = {
  id: true,
  status: true,
  customerName: true,
  customerPhone: true,
  customerEmail: true,
  estimatedTotal: true,
  note: true,
  invoiceId: true,
  createdAt: true,
  decidedAt: true,
  party: { select: { id: true, name: true, linkedUserId: true } },
  _count: { select: { items: true } },
} satisfies Prisma.PurchaseRequestSelect;

const detailSelect = {
  ...listSelect,
  customerAddress: true,
  customerUserId: true,
  decisionNote: true,
  decidedBy: { select: { id: true, name: true } },
  invoice: {
    select: {
      id: true,
      invoiceNo: true,
      type: true,
      status: true,
      total: true,
      invoiceDate: true,
    },
  },
  items: { select: itemSelect, orderBy: { id: 'asc' } },
} satisfies Prisma.PurchaseRequestSelect;

interface CartLine {
  productId: number;
  quantity: number;
}

export class PurchaseRequestsService {
  /// Customer submits a new order. Snapshots product identity + current
  /// price per line so the customer's order remains stable even if the
  /// merchant edits the product later.
  async createForCustomer(opts: {
    customerUserId: number;
    items: CartLine[];
    note?: string;
  }): Promise<
    | { error: 'EMPTY_CART' | 'PRODUCT_MISSING' | 'PRODUCT_INACTIVE' | 'BAD_QTY' }
    | { request: { id: number } }
  > {
    if (opts.items.length === 0) return { error: 'EMPTY_CART' };

    const productIds = [...new Set(opts.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: {
        id: true,
        name: true,
        sku: true,
        unit: true,
        sellingPrice: true,
        isActive: true,
      },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));

    for (const line of opts.items) {
      const product = productMap.get(line.productId);
      if (!product) return { error: 'PRODUCT_MISSING' };
      if (!product.isActive) return { error: 'PRODUCT_INACTIVE' };
      if (!(line.quantity > 0)) return { error: 'BAD_QTY' };
    }

    // Snapshot customer identity from User + any linked Party (so the
    // merchant sees a recognisable name even before confirm).
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: opts.customerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        linkedParties: {
          where: { isActive: true },
          select: { id: true, name: true, phone: true, address: true },
          take: 1,
        },
      },
    });
    const linkedParty = user.linkedParties[0];

    let estimatedTotal = 0;
    const itemsData = opts.items.map((line) => {
      const p = productMap.get(line.productId)!;
      const price = Number(p.sellingPrice);
      const lineTotal = round2(line.quantity * price);
      estimatedTotal += lineTotal;
      return {
        productId: p.id,
        productName: p.name,
        productSku: p.sku,
        unit: p.unit,
        quantity: line.quantity,
        unitPrice: price,
        total: lineTotal,
      };
    });

    const request = await prisma.purchaseRequest.create({
      data: {
        customerUserId: opts.customerUserId,
        partyId: linkedParty?.id ?? null,
        customerName: linkedParty?.name ?? user.name,
        customerPhone: linkedParty?.phone ?? null,
        customerEmail: user.email,
        customerAddress: linkedParty?.address ?? null,
        note: opts.note ?? null,
        estimatedTotal: round2(estimatedTotal),
        items: { create: itemsData },
      },
      select: { id: true },
    });

    return { request };
  }

  async listForCustomer(opts: { userId: number; skip: number; limit: number }) {
    const where: Prisma.PurchaseRequestWhereInput = { customerUserId: opts.userId };
    const [data, total] = await Promise.all([
      prisma.purchaseRequest.findMany({
        where,
        select: listSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.purchaseRequest.count({ where }),
    ]);
    return { data, total };
  }

  async getForCustomer(opts: { userId: number; id: number }) {
    return prisma.purchaseRequest.findFirst({
      where: { id: opts.id, customerUserId: opts.userId },
      select: detailSelect,
    });
  }

  async cancelForCustomer(opts: { userId: number; id: number }) {
    return prisma.purchaseRequest.updateMany({
      where: {
        id: opts.id,
        customerUserId: opts.userId,
        status: 'PENDING',
      },
      data: { status: 'CANCELLED', decidedAt: new Date() },
    });
  }

  /// Merchant-side: list the inbox with the same listSelect projection.
  async listForMerchant(opts: { status?: string; skip: number; limit: number }) {
    const where: Prisma.PurchaseRequestWhereInput = {};
    if (opts.status) where.status = opts.status;
    const [data, total] = await Promise.all([
      prisma.purchaseRequest.findMany({
        where,
        select: listSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.purchaseRequest.count({ where }),
    ]);
    return { data, total };
  }

  async getForMerchant(id: number) {
    return prisma.purchaseRequest.findUnique({
      where: { id },
      select: detailSelect,
    });
  }

  /// Confirm a request → materialise a SALE invoice. If the customer
  /// wasn't linked to a Party row yet, lazy-create one (and link the
  /// customer's user so they show up under "Linked customers" going
  /// forward). Item-level pricing is the snapshot from submit time —
  /// invoice numbers are minted fresh by the invoices service.
  async confirmRequest(opts: {
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' | 'NO_ITEMS' | string }
    | { invoice: { id: number; invoiceNo: string } }
  > {
    const request = await prisma.purchaseRequest.findUnique({
      where: { id: opts.requestId },
      include: { items: true },
    });
    if (!request) return { error: 'NOT_FOUND' };
    if (request.status !== 'PENDING') return { error: 'NOT_PENDING' };
    if (request.items.length === 0) return { error: 'NO_ITEMS' };

    // Lazy-create a Party for the customer if they aren't linked yet.
    // Keeps the merchant's party list as the source of truth for
    // customer identity, and means subsequent orders auto-correlate.
    let partyId = request.partyId;
    if (!partyId) {
      const created = await prisma.party.create({
        data: {
          name: request.customerName,
          phone: request.customerPhone,
          email: request.customerEmail,
          address: request.customerAddress,
          linkedUserId: request.customerUserId,
        },
        select: { id: true },
      });
      partyId = created.id;
    }

    const result = await invoicesService.createInvoice({
      type: 'SALE',
      partyId,
      customerName: request.customerName,
      customerPhone: request.customerPhone ?? undefined,
      note: opts.note ?? request.note ?? undefined,
      items: request.items.map((i) => ({
        productId: i.productId,
        quantity: Number(i.quantity),
        unitPrice: Number(i.unitPrice),
      })),
    });

    if ('error' in result) return { error: result.error ?? 'INVOICE_FAILED' };

    await prisma.purchaseRequest.update({
      where: { id: request.id },
      data: {
        status: 'CONFIRMED',
        invoiceId: result.invoice.id,
        partyId,
        decidedById: opts.decidedById,
        decidedAt: new Date(),
        decisionNote: opts.note ?? null,
      },
    });

    return {
      invoice: { id: result.invoice.id, invoiceNo: result.invoice.invoiceNo },
    };
  }

  async rejectRequest(opts: {
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' }
    | { ok: true }
  > {
    const request = await prisma.purchaseRequest.findUnique({
      where: { id: opts.requestId },
      select: { id: true, status: true },
    });
    if (!request) return { error: 'NOT_FOUND' };
    if (request.status !== 'PENDING') return { error: 'NOT_PENDING' };

    await prisma.purchaseRequest.update({
      where: { id: request.id },
      data: {
        status: 'REJECTED',
        decidedById: opts.decidedById,
        decidedAt: new Date(),
        decisionNote: opts.note ?? null,
      },
    });
    return { ok: true };
  }

  /// Merchant-side counters for the orders badge.
  async pendingCount() {
    return prisma.purchaseRequest.count({ where: { status: 'PENDING' } });
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export const purchaseRequestsService = new PurchaseRequestsService();
