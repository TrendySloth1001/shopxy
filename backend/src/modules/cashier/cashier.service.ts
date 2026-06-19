import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Cashier control center — till shifts + cash-drawer movements + the X/Z report.
///
/// A cashier opens a shift with an opening cash float; every POS sale they ring
/// up carries the shift id (set at checkout). Closing the shift reconciles the
/// counted cash against expected cash (float + cash receipts + pay-ins − pay-outs
/// − drops) and snapshots the figures onto the row (the Z-report). The same
/// computation, live, is the X-report. Module of plain functions — no classes.

// ── DTOs ────────────────────────────────────────────────────────────────────

export interface ShiftView {
  id: number;
  status: string;
  openingFloat: number;
  openedById: number;
  /** The cashier who opened the shift — shown live on the till with a timer. */
  openedByName: string | null;
  openedByEmail: string | null;
  openedAt: Date;
  closedAt: Date | null;
  closingCounted: number | null;
  expectedCash: number | null;
  variance: number | null;
  closingNote: string | null;
}

export interface TenderBreakdownDto {
  mode: string;
  amount: number;
  count: number;
}

export interface CashMovementDto {
  id: number;
  type: string;
  amount: number;
  reason: string | null;
  createdAt: Date;
}

export interface ShiftReport {
  shift: ShiftView;
  sales: { count: number; gross: number };
  tenders: TenderBreakdownDto[];
  cash: {
    openingFloat: number;
    cashSales: number;
    payIns: number;
    payOuts: number;
    drops: number;
    /** Cash refunds paid out for returns during the shift. */
    refunds: number;
    /** float + cashSales + payIns − payOuts − drops − refunds. */
    expected: number;
    /** Counted at close; null while OPEN. */
    counted: number | null;
    /** counted − expected; null while OPEN. */
    variance: number | null;
  };
  /** Sales returns (credit notes) issued during the shift window. */
  returns: { count: number; amount: number };
  gst: { taxable: number; cgst: number; sgst: number; igst: number; cess: number; total: number };
  /// GSTR-style rate-wise summary: taxable value + total tax per GST rate.
  gstByRate: GstRateRowDto[];
  movements: CashMovementDto[];
}

export interface GstRateRowDto {
  rate: number;
  taxable: number;
  tax: number;
}

export interface CashierError {
  error: string;
}

const num = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : Number(d);

const isErr = (r: unknown): r is CashierError =>
  typeof r === 'object' && r !== null && 'error' in r;

type ShiftRow = {
  id: number;
  status: string;
  openingFloat: Prisma.Decimal;
  openedById: number;
  openedAt: Date;
  closedAt: Date | null;
  closingCounted: Prisma.Decimal | null;
  expectedCash: Prisma.Decimal | null;
  variance: Prisma.Decimal | null;
  closingNote: string | null;
};

const SHIFT_SELECT = {
  id: true,
  status: true,
  openingFloat: true,
  openedById: true,
  openedAt: true,
  closedAt: true,
  closingCounted: true,
  expectedCash: true,
  variance: true,
  closingNote: true,
} as const;

function shiftView(row: ShiftRow): ShiftView {
  return {
    id: row.id,
    status: row.status,
    openingFloat: num(row.openingFloat),
    openedById: row.openedById,
    openedByName: null,
    openedByEmail: null,
    openedAt: row.openedAt,
    closedAt: row.closedAt,
    closingCounted: row.closingCounted == null ? null : num(row.closingCounted),
    expectedCash: row.expectedCash == null ? null : num(row.expectedCash),
    variance: row.variance == null ? null : num(row.variance),
    closingNote: row.closingNote,
  };
}

/// Fill in the cashier's name + email (shown on the till). openedById is a plain
/// Int (no relation on CashierShift), so we look the user up here.
async function attachOpener(view: ShiftView): Promise<ShiftView> {
  const u = await prisma.user.findUnique({
    where: { id: view.openedById },
    select: { name: true, email: true },
  });
  return { ...view, openedByName: u?.name ?? null, openedByEmail: u?.email ?? null };
}

// ── shift lifecycle ───────────────────────────────────────────────────────────

/// The caller's current OPEN shift in this shop, or null.
export async function getOpenShift(shopId: number, userId: number): Promise<ShiftView | null> {
  const row = await prisma.cashierShift.findFirst({
    where: { shopId, openedById: userId, status: 'OPEN' },
    orderBy: { id: 'desc' },
    select: SHIFT_SELECT,
  });
  return row ? attachOpener(shiftView(row)) : null;
}

/// Resolve the open-shift id for a cashier (used by POS checkout to stamp sales).
export async function openShiftIdFor(shopId: number, userId: number, db: Prisma.TransactionClient | typeof prisma = prisma): Promise<number | null> {
  const row = await db.cashierShift.findFirst({
    where: { shopId, openedById: userId, status: 'OPEN' },
    orderBy: { id: 'desc' },
    select: { id: true },
  });
  return row?.id ?? null;
}

/// Open a shift with an opening float. Idempotent: returns the caller's existing
/// OPEN shift if one is already open (one open shift per cashier per shop).
export async function openShift(
  shopId: number,
  userId: number,
  openingFloat: number,
): Promise<ShiftView | CashierError> {
  if (openingFloat < 0) return { error: 'Opening float cannot be negative' };
  const existing = await getOpenShift(shopId, userId);
  if (existing) return existing;
  const row = await prisma.cashierShift.create({
    data: { shopId, openedById: userId, openingFloat: new Prisma.Decimal(openingFloat) },
    select: SHIFT_SELECT,
  });
  return attachOpener(shiftView(row));
}

/// Record a cash-drawer movement against the caller's open shift.
export async function addCashMovement(
  shopId: number,
  userId: number,
  input: { type: 'PAY_IN' | 'PAY_OUT' | 'DROP'; amount: number; reason?: string },
): Promise<ShiftReport | CashierError> {
  if (input.amount <= 0) return { error: 'Amount must be positive' };
  const shift = await getOpenShift(shopId, userId);
  if (!shift) return { error: 'Open a shift before recording cash movements' };
  await prisma.cashMovement.create({
    data: {
      shopId,
      shiftId: shift.id,
      type: input.type,
      amount: new Prisma.Decimal(input.amount),
      reason: input.reason ?? null,
      createdById: userId,
    },
  });
  return report(shopId, shift.id);
}

/// Close a shift: snapshot the reconciliation (expected cash + variance vs the
/// counted figure) onto the row and return the final Z-report. Status-guarded so
/// two close attempts can't both win.
export async function closeShift(
  shopId: number,
  userId: number,
  input: { countedCash: number; note?: string },
): Promise<ShiftReport | CashierError> {
  if (input.countedCash < 0) return { error: 'Counted cash cannot be negative' };
  const shift = await getOpenShift(shopId, userId);
  if (!shift) return { error: 'No open shift to close' };

  const rep = await report(shopId, shift.id);
  if (isErr(rep)) return rep;

  const expected = rep.cash.expected;
  const variance = input.countedCash - expected;
  const res = await prisma.cashierShift.updateMany({
    where: { id: shift.id, status: 'OPEN' },
    data: {
      status: 'CLOSED',
      closingCounted: new Prisma.Decimal(input.countedCash),
      expectedCash: new Prisma.Decimal(expected),
      variance: new Prisma.Decimal(variance),
      closingNote: input.note ?? null,
      closedAt: new Date(),
      closedById: userId,
    },
  });
  if (res.count === 0) return { error: 'Shift is already closed' };
  return report(shopId, shift.id);
}

// ── reporting (X / Z) ───────────────────────────────────────────────────────

/// Full reconciliation report for a shift — live (X-report) or final (Z-report).
export async function report(shopId: number, shiftId: number): Promise<ShiftReport | CashierError> {
  const row = await prisma.cashierShift.findFirst({
    where: { id: shiftId, shopId },
    select: SHIFT_SELECT,
  });
  if (!row) return { error: 'Shift not found' };
  const shift = await attachOpener(shiftView(row));

  // Completed sales in this shift → their invoices.
  const sales = await prisma.sale.findMany({
    where: { shopId, shiftId, invoiceId: { not: null } },
    select: { invoiceId: true },
  });
  const invoiceIds = sales.map((s) => s.invoiceId).filter((id): id is number => id != null);

  // Credit notes (sales returns) issued during this shift's window.
  const windowEnd = shift.closedAt ?? new Date();
  const returnsAgg = await prisma.invoice.aggregate({
    where: {
      shopId,
      documentType: 'CREDIT_NOTE',
      createdAt: { gte: shift.openedAt, lte: windowEnd },
    },
    _sum: { total: true },
    _count: { _all: true },
  });

  // Receipts by tender mode (live receipts only) + GST totals from the invoices.
  const [tenderRows, gst, rateRows, movementRows, movementSums] = await Promise.all([
    invoiceIds.length
      ? prisma.payment.groupBy({
          by: ['mode'],
          where: { invoiceId: { in: invoiceIds }, type: 'RECEIPT', voidedAt: null },
          _sum: { amount: true },
          _count: { _all: true },
        })
      : Promise.resolve([] as Array<{ mode: string; _sum: { amount: Prisma.Decimal | null }; _count: { _all: number } }>),
    invoiceIds.length
      ? prisma.invoice.aggregate({
          where: { id: { in: invoiceIds } },
          _sum: {
            total: true,
            taxableValue: true,
            cgstAmount: true,
            sgstAmount: true,
            igstAmount: true,
            cessAmount: true,
          },
          _count: { _all: true },
        })
      : Promise.resolve(null),
    invoiceIds.length
      ? prisma.invoiceItem.groupBy({
          by: ['taxPercent'],
          where: { invoiceId: { in: invoiceIds } },
          _sum: {
            taxableValue: true,
            cgstAmount: true,
            sgstAmount: true,
            igstAmount: true,
            cessAmount: true,
          },
        })
      : Promise.resolve([] as Array<{
          taxPercent: Prisma.Decimal;
          _sum: {
            taxableValue: Prisma.Decimal | null;
            cgstAmount: Prisma.Decimal | null;
            sgstAmount: Prisma.Decimal | null;
            igstAmount: Prisma.Decimal | null;
            cessAmount: Prisma.Decimal | null;
          };
        }>),
    prisma.cashMovement.findMany({
      where: { shiftId },
      orderBy: { id: 'asc' },
      select: { id: true, type: true, amount: true, reason: true, createdAt: true },
    }),
    prisma.cashMovement.groupBy({ by: ['type'], where: { shiftId }, _sum: { amount: true } }),
  ]);

  const tenders: TenderBreakdownDto[] = tenderRows.map((t) => ({
    mode: t.mode,
    amount: num(t._sum.amount),
    count: t._count._all,
  }));
  const cashSales = tenders.find((t) => t.mode === 'CASH')?.amount ?? 0;
  const sumOf = (type: string) => num(movementSums.find((m) => m.type === type)?._sum.amount);
  const payIns = sumOf('PAY_IN');
  const payOuts = sumOf('PAY_OUT');
  const drops = sumOf('DROP');
  const refunds = sumOf('REFUND');
  const expected = shift.openingFloat + cashSales + payIns - payOuts - drops - refunds;

  return {
    shift,
    sales: { count: gst?._count._all ?? 0, gross: num(gst?._sum.total) },
    tenders,
    cash: {
      openingFloat: shift.openingFloat,
      cashSales,
      payIns,
      payOuts,
      drops,
      refunds,
      expected,
      counted: shift.closingCounted,
      variance: shift.variance,
    },
    returns: { count: returnsAgg._count._all, amount: num(returnsAgg._sum.total) },
    gst: {
      taxable: num(gst?._sum.taxableValue),
      cgst: num(gst?._sum.cgstAmount),
      sgst: num(gst?._sum.sgstAmount),
      igst: num(gst?._sum.igstAmount),
      cess: num(gst?._sum.cessAmount),
      total: num(gst?._sum.total),
    },
    gstByRate: rateRows
      .map((r) => ({
        rate: num(r.taxPercent),
        taxable: num(r._sum.taxableValue),
        tax: num(r._sum.cgstAmount) + num(r._sum.sgstAmount) + num(r._sum.igstAmount) + num(r._sum.cessAmount),
      }))
      .sort((a, b) => a.rate - b.rate),
    movements: movementRows.map((m) => ({
      id: m.id,
      type: m.type,
      amount: num(m.amount),
      reason: m.reason,
      createdAt: m.createdAt,
    })),
  };
}

/// X-report: the caller's current open shift report, or null if none open.
export async function xReport(shopId: number, userId: number): Promise<ShiftReport | null> {
  const shift = await getOpenShift(shopId, userId);
  if (!shift) return null;
  const rep = await report(shopId, shift.id);
  return isErr(rep) ? null : rep;
}

export interface ShiftSummary {
  id: number;
  status: string;
  openedById: number;
  openedByName: string | null;
  openedAt: Date;
  closedAt: Date | null;
  openingFloat: number;
  expectedCash: number | null;
  closingCounted: number | null;
  variance: number | null;
}

/// Shift history for the shop (newest first) — the Z-receipt list. Open shifts
/// show null expected/counted/variance (those are snapshotted on close).
export async function listShifts(shopId: number, limit = 30): Promise<ShiftSummary[]> {
  const rows = await prisma.cashierShift.findMany({
    where: { shopId },
    orderBy: { id: 'desc' },
    take: Math.min(Math.max(limit, 1), 100),
    select: {
      id: true,
      status: true,
      openedById: true,
      openedAt: true,
      closedAt: true,
      openingFloat: true,
      expectedCash: true,
      closingCounted: true,
      variance: true,
    },
  });
  const userIds = [...new Set(rows.map((r) => r.openedById))];
  const users = await prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, name: true } });
  const nameById = new Map(users.map((u) => [u.id, u.name]));
  return rows.map((r) => ({
    id: r.id,
    status: r.status,
    openedById: r.openedById,
    openedByName: nameById.get(r.openedById) ?? null,
    openedAt: r.openedAt,
    closedAt: r.closedAt,
    openingFloat: num(r.openingFloat),
    expectedCash: r.expectedCash == null ? null : num(r.expectedCash),
    closingCounted: r.closingCounted == null ? null : num(r.closingCounted),
    variance: r.variance == null ? null : num(r.variance),
  }));
}
