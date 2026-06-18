import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { productsService } from '../products/products.service.js';
import { invoicesService, PosInvoiceError } from '../invoices/invoices.service.js';
import { paymentsService } from '../payments/payments.service.js';
import { saleBus } from './pos.bus.js';

/// POS (point-of-sale) — the server-authoritative shopping cart the till(s)
/// mutate via intents, plus the single-transaction checkout that turns a cart
/// into a confirmed GST invoice + receipt. See POS_DESIGN.md.
///
/// The cart (`Sale`/`SaleLine`) lives in Postgres so phone + web share one cart
/// and a disconnect/crash never loses it. Every mutation bumps `sale.version`.
/// Totals use the exact invoice math (`invoicesService`) so the till preview
/// always matches the bill. Module of plain functions — no classes.

// ── DTOs ──────────────────────────────────────────────────────────────────────

export type TenderMode = 'CASH' | 'UPI' | 'CARD' | 'NEFT' | 'RTGS' | 'CHEQUE' | 'OTHER';

export interface SaleLineDto {
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
}

export interface SaleTotalsDto {
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
}

export interface SaleDto {
  id: number;
  status: string;
  version: number;
  partyId: number | null;
  customerName: string | null;
  customerPhone: string | null;
  headerDiscount: number;
  note: string | null;
  invoiceId: number | null;
}

export interface SaleSnapshot {
  sale: SaleDto;
  lines: SaleLineDto[];
  totals: SaleTotalsDto;
}

export interface CheckoutResultDto {
  invoiceId: number;
  invoiceNo: string;
  total: string;
  paymentRef: string | null;
  mode: string | null;
  replayed: boolean;
}

export interface OpenSaleSummaryDto {
  id: number;
  customerName: string | null;
  lineCount: number;
  updatedAt: Date;
}

export interface PosError {
  error: string;
  detail?: { productId: number; available: number; requested: number };
}

export type UnknownScan = { unknown: true; code: string };

// ── helpers ─────────────────────────────────────────────────────────────────

type SaleWithLines = Prisma.SaleGetPayload<{
  include: { lines: { include: { product: { select: { id: true; name: true; sku: true; images: true } } } } };
}>;

const num = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : Number(d);

const isError = (r: { error?: string } | object): r is PosError =>
  'error' in r && typeof (r as { error?: unknown }).error === 'string';

function loadSale(shopId: number, saleId: number): Promise<SaleWithLines | null> {
  return prisma.sale.findFirst({
    where: { id: saleId, shopId },
    include: {
      lines: {
        orderBy: { createdAt: 'asc' },
        include: {
          product: { select: { id: true, name: true, sku: true, images: { orderBy: { sortOrder: 'asc' }, take: 1 } } },
        },
      },
    },
  });
}

/// Re-read the sale and compute its totals with the real invoice math.
export async function snapshot(shopId: number, saleId: number): Promise<SaleSnapshot | PosError> {
  const sale = await loadSale(shopId, saleId);
  if (!sale) return { error: 'Sale not found' };

  const saleDto: SaleDto = {
    id: sale.id,
    status: sale.status,
    version: sale.version,
    partyId: sale.partyId,
    customerName: sale.customerName,
    customerPhone: sale.customerPhone,
    headerDiscount: num(sale.headerDiscount),
    note: sale.note,
    invoiceId: sale.invoiceId,
  };

  if (sale.lines.length === 0) {
    return {
      sale: saleDto,
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
  const lines: SaleLineDto[] = sale.lines.map((l) => {
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
    sale: saleDto,
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
/// fresh snapshot + notify the room (version nudge only — no PII on the wire).
async function mutate(
  shopId: number,
  saleId: number,
  fn: (tx: Prisma.TransactionClient) => Promise<void>,
): Promise<SaleSnapshot | PosError> {
  const res = await prisma.$transaction(async (tx) => {
    const sale = await tx.sale.findFirst({ where: { id: saleId, shopId }, select: { id: true, status: true } });
    if (!sale) return { ok: false as const, error: 'Sale not found' };
    if (sale.status !== 'OPEN') return { ok: false as const, error: 'Sale is not open' };
    await fn(tx);
    await tx.sale.update({ where: { id: saleId }, data: { version: { increment: 1 } } });
    return { ok: true as const };
  });
  if (!res.ok) return { error: res.error };
  const snap = await snapshot(shopId, saleId);
  if (!isError(snap)) {
    saleBus.publish(shopId, { type: 'pos.sale', saleId, version: snap.sale.version });
  }
  return snap;
}

/// Open a till: reuse the caller's most recent empty OPEN sale if one exists,
/// else create one. Reuse stops a fresh empty Sale leaking on every page open /
/// refresh / StrictMode double-mount (review H4).
export async function openSale(
  shopId: number,
  openedById: number,
  opts?: { partyId?: number; customerName?: string; customerPhone?: string },
): Promise<SaleSnapshot | PosError> {
  if (!opts?.partyId && !opts?.customerName && !opts?.customerPhone) {
    const existing = await prisma.sale.findFirst({
      where: { shopId, openedById, status: 'OPEN', lines: { none: {} } },
      orderBy: { updatedAt: 'desc' },
      select: { id: true },
    });
    if (existing) return snapshot(shopId, existing.id);
  }
  const sale = await prisma.sale.create({
    data: {
      shopId,
      openedById,
      partyId: opts?.partyId ?? null,
      customerName: opts?.customerName ?? null,
      customerPhone: opts?.customerPhone ?? null,
    },
  });
  return snapshot(shopId, sale.id);
}

/// Held/parked carts: OPEN sales with items (empty = abandoned), newest first, capped.
export async function listOpenSales(shopId: number): Promise<OpenSaleSummaryDto[]> {
  const sales = await prisma.sale.findMany({
    where: { shopId, status: 'OPEN', lines: { some: {} } },
    orderBy: { updatedAt: 'desc' },
    take: 50,
    include: { _count: { select: { lines: true } } },
  });
  return sales.map((s) => ({
    id: s.id,
    customerName: s.customerName,
    lineCount: s._count.lines,
    updatedAt: s.updatedAt,
  }));
}

/// Void OPEN carts with no lines older than the cutoff (scheduler sweep, H4).
export async function sweepStaleSales(olderThan: Date): Promise<number> {
  const res = await prisma.sale.updateMany({
    where: { status: 'OPEN', lines: { none: {} }, updatedAt: { lt: olderThan } },
    data: { status: 'VOIDED' },
  });
  return res.count;
}

/// Add a scanned code: resolve to a product and bump its line qty. Returns
/// `{ unknown }` when no product matches — the till then offers Quick add.
export async function addScan(
  shopId: number,
  saleId: number,
  code: string,
  addedById: number,
  opId?: string,
): Promise<SaleSnapshot | UnknownScan | PosError> {
  const product = await productsService.lookupProduct(shopId, code);
  if (!product) return { unknown: true, code };
  return addProduct(shopId, saleId, product.id, 1, addedById, opId);
}

export async function addProduct(
  shopId: number,
  saleId: number,
  productId: number,
  quantity: number,
  addedById: number,
  opId?: string,
): Promise<SaleSnapshot | PosError> {
  if (quantity <= 0) return { error: 'Quantity must be positive' };
  const product = await prisma.product.findFirst({
    where: { id: productId, shopId, isActive: true },
    select: { id: true, sellingPrice: true },
  });
  if (!product) return { error: 'Product not found in this shop' };

  // Op-id dedupe (P3): scan/add bump quantity, so a retried-after-timeout request
  // must not apply twice. Pre-check the opId (a constraint hit INSIDE the tx would
  // abort it). The in-tx insert is the race backstop. Scope to the user so one
  // till on a shared cart can't shadow another's op by colliding ids (review L).
  const scopedOpId = opId ? `${addedById}:${opId}` : undefined;
  if (scopedOpId) {
    const seen = await prisma.saleOp.findUnique({ where: { saleId_opId: { saleId, opId: scopedOpId } } });
    if (seen) return snapshot(shopId, saleId);
  }

  return mutate(shopId, saleId, async (tx) => {
    if (scopedOpId) await tx.saleOp.create({ data: { saleId, opId: scopedOpId } });
    await tx.saleLine.upsert({
      where: { saleId_productId: { saleId, productId } },
      create: { saleId, productId, quantity: new Prisma.Decimal(quantity), unitPrice: product.sellingPrice, addedById },
      update: { quantity: { increment: new Prisma.Decimal(quantity) } },
    });
  });
}

export async function setQty(shopId: number, saleId: number, productId: number, quantity: number): Promise<SaleSnapshot | PosError> {
  if (quantity < 0) return { error: 'Quantity cannot be negative' };
  return mutate(shopId, saleId, async (tx) => {
    if (quantity === 0) {
      await tx.saleLine.deleteMany({ where: { saleId, productId } });
      return;
    }
    await tx.saleLine.updateMany({ where: { saleId, productId }, data: { quantity: new Prisma.Decimal(quantity) } });
  });
}

export async function setLineDiscount(shopId: number, saleId: number, productId: number, discount: number): Promise<SaleSnapshot | PosError> {
  if (discount < 0) return { error: 'Discount cannot be negative' };
  return mutate(shopId, saleId, async (tx) => {
    await tx.saleLine.updateMany({ where: { saleId, productId }, data: { lineDiscount: new Prisma.Decimal(discount) } });
  });
}

/// Unit-price override — gated behind `invoices:manage` at the edge (cashiers can
/// discount but not silently reprice; POS_DESIGN.md §13).
export async function setUnitPrice(shopId: number, saleId: number, productId: number, unitPrice: number): Promise<SaleSnapshot | PosError> {
  if (unitPrice < 0) return { error: 'Price cannot be negative' };
  return mutate(shopId, saleId, async (tx) => {
    await tx.saleLine.updateMany({ where: { saleId, productId }, data: { unitPrice: new Prisma.Decimal(unitPrice) } });
  });
}

export async function removeLine(shopId: number, saleId: number, productId: number): Promise<SaleSnapshot | PosError> {
  return mutate(shopId, saleId, async (tx) => {
    await tx.saleLine.deleteMany({ where: { saleId, productId } });
  });
}

export async function setHeaderDiscount(shopId: number, saleId: number, discount: number): Promise<SaleSnapshot | PosError> {
  if (discount < 0) return { error: 'Discount cannot be negative' };
  return mutate(shopId, saleId, async (tx) => {
    await tx.sale.update({ where: { id: saleId }, data: { headerDiscount: new Prisma.Decimal(discount) } });
  });
}

/// Get-or-create this shop's system "Walk-in Customer" party (migration seeds it;
/// this self-heals if missing).
async function ensureWalkInParty(shopId: number): Promise<number> {
  const existing = await prisma.party.findFirst({
    where: { shopId, isSystem: true, name: 'Walk-in Customer' },
    select: { id: true },
  });
  if (existing) return existing.id;
  const created = await prisma.party.create({ data: { shopId, name: 'Walk-in Customer', isSystem: true } });
  return created.id;
}

/// Quick-add (P2): unknown scan → create a minimal catalog product (opening stock
/// posted via the ledger so it's sellable at checkout) and add it. Gated on
/// `products:manage` at the edge.
export async function quickAddProduct(
  shopId: number,
  saleId: number,
  input: { code: string; name: string; sellingPrice: number; costPrice?: number; taxPercent?: number; openingStock?: number },
  userId: number,
): Promise<SaleSnapshot | PosError> {
  const sale = await prisma.sale.findFirst({ where: { id: saleId, shopId }, select: { status: true } });
  if (!sale) return { error: 'Sale not found' };
  if (sale.status !== 'OPEN') return { error: 'Sale is not open' };

  let product: { id: number };
  try {
    product = await productsService.createProduct(
      {
        name: input.name,
        sku: input.code,
        barcode: input.code,
        mrp: input.sellingPrice,
        sellingPrice: input.sellingPrice,
        // Opening stock funds a FIFO cost layer at this price; default the cost
        // basis to the selling price (zero margin) not 0 — a ₹0 cost would book
        // 100% phantom margin and ₹0 inventory value (review M1).
        purchasePrice: input.costPrice ?? input.sellingPrice,
        taxPercent: input.taxPercent ?? 0,
        stockQuantity: input.openingStock ?? 1,
        unit: 'PCS',
      },
      { shopId, createdById: userId },
    );
  } catch (e) {
    // Most likely a duplicate sku/barcode (the code already exists in some shop).
    return { error: e instanceof Error ? e.message : 'Could not create the product' };
  }
  return addProduct(shopId, saleId, product.id, 1, userId);
}

export async function voidSale(shopId: number, saleId: number): Promise<{ ok: true } | PosError> {
  // Atomic status-guarded void — no TOCTOU vs a concurrent checkout.
  const res = await prisma.sale.updateMany({
    where: { id: saleId, shopId, status: 'OPEN' },
    data: { status: 'VOIDED', version: { increment: 1 } },
  });
  if (res.count === 0) {
    const sale = await prisma.sale.findFirst({ where: { id: saleId, shopId }, select: { id: true } });
    return { error: sale ? 'Only an open sale can be voided' : 'Sale not found' };
  }
  saleBus.publish(shopId, { type: 'pos.void', saleId });
  return { ok: true };
}

function buildCheckoutResult(
  invoice: { id: number; invoiceNo: string; total: Prisma.Decimal },
  payment: { referenceNo: string; mode: string } | null,
  replayed: boolean,
): CheckoutResultDto {
  return {
    invoiceId: invoice.id,
    invoiceNo: invoice.invoiceNo,
    total: invoice.total.toString(),
    paymentRef: payment?.referenceNo ?? null,
    mode: payment?.mode ?? null,
    replayed,
  };
}

/// Idempotent checkout replay: the sale's existing invoice + (live) receipt.
async function replayCheckout(invoiceId: number): Promise<CheckoutResultDto | PosError> {
  const invoice = await prisma.invoice.findUnique({
    where: { id: invoiceId },
    select: { id: true, invoiceNo: true, total: true },
  });
  if (!invoice) return { error: 'Invoice not found' };
  const payment = await prisma.payment.findFirst({
    where: { invoiceId, type: 'RECEIPT', voidedAt: null },
    orderBy: { id: 'asc' },
    select: { referenceNo: true, mode: true },
  });
  return buildCheckoutResult(invoice, payment, true);
}

/// Single-transaction checkout: confirm invoice (+ stock) and record the tender
/// all-or-nothing. Idempotent on `sale.invoiceId` — a retried checkout returns
/// the same invoice, never double-bills.
export async function checkout(
  shopId: number,
  saleId: number,
  input: { tender: { mode: TenderMode; modeReference?: string | null }; customer?: { name?: string; phone?: string } },
  userId: number,
): Promise<CheckoutResultDto | PosError> {
  const sale = await prisma.sale.findFirst({ where: { id: saleId, shopId }, include: { lines: true } });
  if (!sale) return { error: 'Sale not found' };
  if (sale.invoiceId) return replayCheckout(sale.invoiceId);
  if (sale.status !== 'OPEN') return { error: 'Sale is not open' };
  if (sale.lines.length === 0) return { error: 'Cannot check out an empty sale' };

  // SALE invoices require a party (DB XOR constraint); a walk-in maps to the
  // shop's system party. Resolve/commit it BEFORE the tx so the resolver sees it.
  const partyId = sale.partyId ?? (await ensureWalkInParty(shopId));
  const items = sale.lines.map((l) => ({
    productId: l.productId,
    quantity: num(l.quantity),
    unitPrice: num(l.unitPrice),
    discount: num(l.lineDiscount),
  }));

  try {
    const outcome = await prisma.$transaction(
      async (tx) => {
        // Lock + re-check INSIDE the tx (the check above ran on another
        // connection, advisory). Two simultaneous checkouts on a shared cart
        // serialise here: the loser sees invoiceId set and replays.
        const locked = await tx.$queryRaw<Array<{ invoice_id: number | null; status: string }>>`
          SELECT invoice_id, status FROM sales WHERE id = ${saleId} AND shop_id = ${shopId} FOR UPDATE
        `;
        const row = locked[0];
        if (!row) return { kind: 'error' as const, error: 'Sale not found' };
        if (row.invoice_id != null) return { kind: 'replay' as const, invoiceId: row.invoice_id };
        if (row.status !== 'OPEN') return { kind: 'error' as const, error: 'Sale is not open' };

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
          // Same counterparty as the invoice (incl. walk-in) so the receipt nets
          // against the bill in the party ledger (review H1).
          partyId,
          createdById: userId,
          idempotencyKey: `POS:${saleId}:PAY`,
        });
        await tx.sale.update({
          where: { id: saleId },
          data: { status: 'CHECKED_OUT', invoiceId: invoice.id, version: { increment: 1 } },
        });
        return { kind: 'done' as const, invoice, payment };
      },
      { isolationLevel: 'Serializable' },
    );

    if (outcome.kind === 'error') return { error: outcome.error };
    if (outcome.kind === 'replay') return replayCheckout(outcome.invoiceId);
    saleBus.publish(shopId, { type: 'pos.checkout', saleId, invoiceId: outcome.invoice.id });
    return buildCheckoutResult(outcome.invoice, outcome.payment, false);
  } catch (e) {
    if (e instanceof PosInvoiceError) return { error: e.message, detail: e.detail };
    // A concurrent winner can surface as a unique/serialization failure — re-read
    // and replay rather than 500 on an already-successful sale.
    const fresh = await prisma.sale.findUnique({ where: { id: saleId }, select: { invoiceId: true } });
    if (fresh?.invoiceId) return replayCheckout(fresh.invoiceId);
    throw e;
  }
}
