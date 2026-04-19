import prisma from '../../infra/db/prisma.js';

function round2(v: number): number {
  return Math.round((v + Number.EPSILON) * 100) / 100;
}

async function nextChallanNo(): Promise<string> {
  const count = await prisma.challan.count();
  const seq = String(count + 1).padStart(5, '0');
  const ym = new Date().toISOString().slice(0, 7).replace('-', '');
  return `CH-${ym}-${seq}`;
}

async function nextInvoiceNo(type: 'SALE' | 'PURCHASE'): Promise<string> {
  const prefix = type === 'SALE' ? 'INV' : 'PUR';
  const count = await prisma.invoice.count({ where: { type } });
  const seq = String(count + 1).padStart(5, '0');
  const ym = new Date().toISOString().slice(0, 7).replace('-', '');
  return `${prefix}-${ym}-${seq}`;
}

export class ChallansService {
  async createChallan(data: {
    partyName: string;
    partyPhone?: string;
    note?: string;
    items: { productId: number; quantity: number }[];
  }) {
    if (data.items.length === 0) {
      return { error: 'Challan must have at least one item' as const };
    }

    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, name: true, sku: true, unit: true },
    });

    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    const challanNo = await nextChallanNo();

    const challan = await prisma.challan.create({
      data: {
        challanNo,
        partyName: data.partyName,
        partyPhone: data.partyPhone ?? null,
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
      include: { items: true },
    });

    return { challan };
  }

  async listChallans(options: {
    status?: string;
    search: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
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
          partyName: true,
          partyPhone: true,
          invoiceId: true,
          createdAt: true,
          _count: { select: { items: true } },
        },
      }),
      prisma.challan.count({ where }),
    ]);

    return { challans, total };
  }

  getChallanById(id: number) {
    return prisma.challan.findUnique({
      where: { id },
      include: {
        items: { orderBy: { id: 'asc' } },
        invoice: { select: { id: true, invoiceNo: true, status: true } },
      },
    });
  }

  async cancelChallan(id: number) {
    const challan = await prisma.challan.findUnique({ where: { id }, select: { status: true } });
    if (!challan) return { error: 'Challan not found' as const };
    if (challan.status !== 'PENDING') {
      return { error: 'Only pending challans can be cancelled' as const };
    }
    await prisma.challan.update({ where: { id }, data: { status: 'CANCELLED' } });
    return { ok: true };
  }

  async convertToInvoice(
    id: number,
    data?: { customerName?: string; customerGstin?: string; discount?: number; note?: string },
  ) {
    const challan = await prisma.challan.findUnique({
      where: { id },
      include: { items: true },
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
      where: { id: { in: productIds } },
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
    const invoiceNo = await nextInvoiceNo('SALE');

    const invoice = await prisma.$transaction(async (tx) => {
      const newInvoice = await tx.invoice.create({
        data: {
          invoiceNo,
          type: 'SALE',
          status: 'DRAFT',
          customerName: data?.customerName ?? challan.partyName,
          customerPhone: challan.partyPhone ?? null,
          customerGstin: data?.customerGstin ?? null,
          subtotal: round2(subtotal),
          taxAmount: round2(taxAmount),
          discount: headerDiscount,
          total,
          note: data?.note ?? challan.note ?? null,
          items: { create: itemsData },
        },
        include: { items: true },
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
