import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { productsService } from '../products/products.service.js';
import { invoicesService, PosInvoiceError } from '../invoices/invoices.service.js';
import { paymentsService } from '../payments/payments.service.js';

/// POS (point-of-sale) service — the server-authoritative shopping cart that the
/// till(s) mutate via intents, plus the single-transaction checkout that turns a
/// cart into a confirmed GST invoice + receipt. See POS_DESIGN.md.
///
/// The cart (`Sale`/`SaleLine`) lives in Postgres so phone + web share one cart
/// and a disconnect/crash never loses it. Every mutation bumps `sale.version`.
/// Totals are computed with the exact invoice math (`invoicesService`) so the
/// till preview always matches the bill.

export type SaleSnapshot = {
  sale: {
    id: number;
    status: string;
    version: number;
    partyId: number | null;
    customerName: string | null;
    customerPhone: string | null;
    headerDiscount: number;
    note: string | null;
    invoiceId: number | null;
  };
  lines: Array<{
    productId: number;
    name: string;
    sku: string;
    imageUrl: string | null;
    quantity: number;
    unitPrice: number;
    lineDiscount: number;
    taxPercent: number;
    taxableValue: number;
    total: number;
  }>;
  totals: {
    itemCount: number;
    subtotal: number;
    discount: number;
    taxableValue: number;
    taxAmount: number;
    cgst: number;
    sgst: number;
    igst: number;
    cess: number;
    roundOff: number;
    total: number;
  };
};

type SaleWithLines = Prisma.SaleGetPayload<{
  include: { lines: { include: { product: { select: { id: true; name: true; sku: true; images: true } } } } };
}>;

const num = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : Number(d);

class PosService {
  private loadSale(shopId: number, saleId: number): Promise<SaleWithLines | null> {
    return prisma.sale.findFirst({
      where: { id: saleId, shopId },
      include: {
        lines: {
          orderBy: { createdAt: 'asc' },
          include: { product: { select: { id: true, name: true, sku: true, images: { orderBy: { sortOrder: 'asc' }, take: 1 } } } },
        },
      },
    });
  }

  /// Re-read the sale and compute its totals with the real invoice math.
  async snapshot(shopId: number, saleId: number): Promise<SaleSnapshot | { error: string }> {
    const sale = await this.loadSale(shopId, saleId);
    if (!sale) return { error: 'Sale not found' };

    const base = {
      sale: {
        id: sale.id,
        status: sale.status,
        version: sale.version,
        partyId: sale.partyId,
        customerName: sale.customerName,
        customerPhone: sale.customerPhone,
        headerDiscount: num(sale.headerDiscount),
        note: sale.note,
        invoiceId: sale.invoiceId,
      },
    };

    if (sale.lines.length === 0) {
      return {
        ...base,
        lines: [],
        totals: { itemCount: 0, subtotal: 0, discount: 0, taxableValue: 0, taxAmount: 0, cgst: 0, sgst: 0, igst: 0, cess: 0, roundOff: 0, total: 0 },
      };
    }

    const preview = await invoicesService.previewSaleTotals({
      shopId,
      type: 'SALE',
      partyId: sale.partyId ?? undefined,
      customerName: sale.customerName ?? undefined,
      customerPhone: sale.customerPhone ?? undefined,
      discount: num(sale.headerDiscount),
      items: sale.lines.map((l) => ({
        productId: l.productId,
        quantity: num(l.quantity),
        unitPrice: num(l.unitPrice),
        discount: num(l.lineDiscount),
      })),
    });
    if ('error' in preview) return { error: preview.error };

    const computedByProduct = new Map(preview.itemsData.map((it) => [it.productId, it]));
    const lines = sale.lines.map((l) => {
      const c = computedByProduct.get(l.productId);
      return {
        productId: l.productId,
        name: l.product.name,
        sku: l.product.sku,
        imageUrl: l.product.images[0]?.url ?? null,
        quantity: num(l.quantity),
        unitPrice: num(l.unitPrice),
        lineDiscount: num(l.lineDiscount),
        taxPercent: c ? num(c.taxPercent) : 0,
        taxableValue: c ? num(c.taxableValue) : 0,
        total: c ? num(c.total) : 0,
      };
    });

    return {
      ...base,
      lines,
      totals: {
        itemCount: sale.lines.reduce((n, l) => n + num(l.quantity), 0),
        subtotal: num(preview.header.subtotal),
        discount: sale.lines.reduce((s, l) => s + num(l.lineDiscount), 0) + num(sale.headerDiscount),
        taxableValue: num(preview.header.taxableValue),
        taxAmount: num(preview.header.taxAmount),
        cgst: num(preview.header.cgstAmount),
        sgst: num(preview.header.sgstAmount),
        igst: num(preview.header.igstAmount),
        cess: num(preview.header.cessAmount),
        roundOff: num(preview.header.roundOff),
        total: num(preview.header.total),
      },
    };
  }

  /// Run a line mutation against an OPEN sale, bump its version, then return the
  /// fresh snapshot. The version bump + sale-row touch serialises concurrent
  /// edits to the same cart.
  private async mutate(
    shopId: number,
    saleId: number,
    fn: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<SaleSnapshot | { error: string }> {
    const res = await prisma.$transaction(async (tx) => {
      const sale = await tx.sale.findFirst({ where: { id: saleId, shopId }, select: { id: true, status: true } });
      if (!sale) return { ok: false as const, error: 'Sale not found' };
      if (sale.status !== 'OPEN') return { ok: false as const, error: 'Sale is not open' };
      await fn(tx);
      await tx.sale.update({ where: { id: saleId }, data: { version: { increment: 1 } } });
      return { ok: true as const };
    });
    if (!res.ok) return { error: res.error };
    return this.snapshot(shopId, saleId);
  }

  async openSale(
    shopId: number,
    openedById: number,
    opts?: { partyId?: number; customerName?: string; customerPhone?: string },
  ): Promise<SaleSnapshot | { error: string }> {
    const sale = await prisma.sale.create({
      data: {
        shopId,
        openedById,
        partyId: opts?.partyId ?? null,
        customerName: opts?.customerName ?? null,
        customerPhone: opts?.customerPhone ?? null,
      },
    });
    return this.snapshot(shopId, sale.id);
  }

  /// Held/parked carts: every OPEN sale for the shop, with a light summary.
  async listOpenSales(shopId: number) {
    const sales = await prisma.sale.findMany({
      where: { shopId, status: 'OPEN' },
      orderBy: { updatedAt: 'desc' },
      include: { _count: { select: { lines: true } } },
    });
    return sales.map((s) => ({
      id: s.id,
      customerName: s.customerName,
      lineCount: s._count.lines,
      updatedAt: s.updatedAt,
    }));
  }

  /// Add a scanned code: resolve to a product and bump its line qty (POS-style).
  /// Returns `{ unknown }` when no product matches — the till then offers Quick
  /// add (P2).
  async addScan(
    shopId: number,
    saleId: number,
    code: string,
    addedById: number,
  ): Promise<SaleSnapshot | { unknown: true; code: string } | { error: string }> {
    const product = await productsService.lookupProduct(shopId, code);
    if (!product) return { unknown: true as const, code };
    return this.addProduct(shopId, saleId, product.id, 1, addedById);
  }

  async addProduct(
    shopId: number,
    saleId: number,
    productId: number,
    quantity: number,
    addedById: number,
  ): Promise<SaleSnapshot | { error: string }> {
    if (quantity <= 0) return { error: 'Quantity must be positive' };
    const product = await prisma.product.findFirst({
      where: { id: productId, shopId, isActive: true },
      select: { id: true, sellingPrice: true },
    });
    if (!product) return { error: 'Product not found in this shop' };
    return this.mutate(shopId, saleId, async (tx) => {
      await tx.saleLine.upsert({
        where: { saleId_productId: { saleId, productId } },
        create: {
          saleId,
          productId,
          quantity: new Prisma.Decimal(quantity),
          unitPrice: product.sellingPrice,
          addedById,
        },
        update: { quantity: { increment: new Prisma.Decimal(quantity) } },
      });
    });
  }

  async setQty(shopId: number, saleId: number, productId: number, quantity: number) {
    if (quantity < 0) return { error: 'Quantity cannot be negative' };
    return this.mutate(shopId, saleId, async (tx) => {
      if (quantity === 0) {
        await tx.saleLine.deleteMany({ where: { saleId, productId } });
        return;
      }
      await tx.saleLine.updateMany({
        where: { saleId, productId },
        data: { quantity: new Prisma.Decimal(quantity) },
      });
    });
  }

  async setLineDiscount(shopId: number, saleId: number, productId: number, discount: number) {
    if (discount < 0) return { error: 'Discount cannot be negative' };
    return this.mutate(shopId, saleId, async (tx) => {
      await tx.saleLine.updateMany({
        where: { saleId, productId },
        data: { lineDiscount: new Prisma.Decimal(discount) },
      });
    });
  }

  /// Unit-price override. The controller gates this behind `invoices:manage`
  /// (cashiers can discount but not silently reprice — see POS_DESIGN.md §13).
  async setUnitPrice(shopId: number, saleId: number, productId: number, unitPrice: number) {
    if (unitPrice < 0) return { error: 'Price cannot be negative' };
    return this.mutate(shopId, saleId, async (tx) => {
      await tx.saleLine.updateMany({
        where: { saleId, productId },
        data: { unitPrice: new Prisma.Decimal(unitPrice) },
      });
    });
  }

  async removeLine(shopId: number, saleId: number, productId: number) {
    return this.mutate(shopId, saleId, async (tx) => {
      await tx.saleLine.deleteMany({ where: { saleId, productId } });
    });
  }

  async setHeaderDiscount(shopId: number, saleId: number, discount: number) {
    if (discount < 0) return { error: 'Discount cannot be negative' };
    return this.mutate(shopId, saleId, async (tx) => {
      await tx.sale.update({ where: { id: saleId }, data: { headerDiscount: new Prisma.Decimal(discount) } });
    });
  }

  /// Get-or-create this shop's system "Walk-in Customer" party — the counterparty
  /// for true walk-in sales (the migration seeds it; this self-heals if missing).
  private async ensureWalkInParty(shopId: number): Promise<number> {
    const existing = await prisma.party.findFirst({
      where: { shopId, isSystem: true, name: 'Walk-in Customer' },
      select: { id: true },
    });
    if (existing) return existing.id;
    const created = await prisma.party.create({
      data: { shopId, name: 'Walk-in Customer', isSystem: true },
    });
    return created.id;
  }

  async voidSale(shopId: number, saleId: number): Promise<{ ok: true } | { error: string }> {
    const sale = await prisma.sale.findFirst({ where: { id: saleId, shopId }, select: { status: true } });
    if (!sale) return { error: 'Sale not found' };
    if (sale.status === 'CHECKED_OUT') return { error: 'A checked-out sale cannot be voided' };
    await prisma.sale.update({ where: { id: saleId }, data: { status: 'VOIDED', version: { increment: 1 } } });
    return { ok: true };
  }

  /// Single-transaction checkout: confirm invoice (+ stock) and record the
  /// tender all-or-nothing. Idempotent on `sale.invoiceId` — a retried checkout
  /// (e.g. through a network drop) returns the same invoice, never double-bills.
  async checkout(
    shopId: number,
    saleId: number,
    input: { tender: { mode: string; modeReference?: string | null }; customer?: { name?: string; phone?: string } },
    userId: number,
  ): Promise<
    | { invoice: unknown; payment: unknown; replayed?: boolean }
    | { error: string; detail?: { productId: number; available: number; requested: number } }
  > {
    const sale = await prisma.sale.findFirst({ where: { id: saleId, shopId }, include: { lines: true } });
    if (!sale) return { error: 'Sale not found' };

    // Idempotent replay: a sale yields exactly one invoice.
    if (sale.invoiceId) {
      const invoice = await prisma.invoice.findUnique({ where: { id: sale.invoiceId }, include: { items: true } });
      const payment = await prisma.payment.findFirst({ where: { invoiceId: sale.invoiceId, type: 'RECEIPT' } });
      return { invoice, payment, replayed: true };
    }
    if (sale.status !== 'OPEN') return { error: 'Sale is not open' };
    if (sale.lines.length === 0) return { error: 'Cannot check out an empty sale' };

    // SALE invoices require a party (DB XOR constraint); a true walk-in maps to
    // the shop's system "Walk-in Customer". Resolve/commit it BEFORE the tx so
    // the invoice resolver (which reads parties on the main connection) sees it.
    const partyId = sale.partyId ?? (await this.ensureWalkInParty(shopId));

    const items = sale.lines.map((l) => ({
      productId: l.productId,
      quantity: num(l.quantity),
      unitPrice: num(l.unitPrice),
      discount: num(l.lineDiscount),
    }));

    try {
      return await prisma.$transaction(
        async (tx) => {
          const invoice = await invoicesService.createConfirmedSaleInTx(
            tx,
            {
              shopId,
              type: 'SALE',
              partyId,
              customerName: input.customer?.name ?? sale.customerName ?? undefined,
              customerPhone: input.customer?.phone ?? sale.customerPhone ?? undefined,
              discount: num(sale.headerDiscount),
              items,
            },
            userId,
          );
          const payment = await paymentsService.recordReceiptInTx(tx, {
            shopId,
            amount: num(invoice.total),
            mode: input.tender.mode,
            modeReference: input.tender.modeReference ?? null,
            invoiceId: invoice.id,
            partyId: sale.partyId ?? null,
            createdById: userId,
            idempotencyKey: `POS:${saleId}:PAY`,
          });
          await tx.sale.update({
            where: { id: saleId },
            data: { status: 'CHECKED_OUT', invoiceId: invoice.id, version: { increment: 1 } },
          });
          return { invoice, payment };
        },
        { isolationLevel: 'Serializable' },
      );
    } catch (e) {
      if (e instanceof PosInvoiceError) return { error: e.message, detail: e.detail };
      throw e;
    }
  }
}

export const posService = new PosService();
