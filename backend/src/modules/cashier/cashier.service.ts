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

/// CASH-7 — money at the boundary. A float amount (opening float, counted cash,
/// a cash movement) is wrapped in Decimal and rounded to 2dp HALF_UP before it
/// touches a Decimal(12,2)/(15,2) column, so a 3rd-decimal input or a binary
/// float artefact (0.1+0.2) is rounded deterministically here rather than left
/// to the DB's silent store-time coercion.
const money2dp = (n: number): Prisma.Decimal =>
  new Prisma.Decimal(n).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

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
    data: { shopId, openedById: userId, openingFloat: money2dp(openingFloat) },
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
      amount: money2dp(input.amount),
      reason: input.reason ?? null,
      createdById: userId,
    },
  });
  return report(shopId, shift.id);
}

/// Close a shift: snapshot the reconciliation (expected cash + variance vs the
/// counted figure) onto the row and return the final Z-report.
///
/// CASH-5 — the whole reconciliation runs in ONE transaction that first locks
/// the shift row `FOR UPDATE`, then aggregates receipts/movements (via `report`
/// on the same tx client) and writes the snapshot. A concurrent checkout cash
/// receipt / cash movement / cash REFUND on this shift can no longer land between
/// the read and the write, so the snapshotted `expectedCash`/`variance` always
/// reflect drawer state at close. The lock also serialises two close attempts
/// (the second sees status='CLOSED' and bails), replacing the old status guard.
export async function closeShift(
  shopId: number,
  userId: number,
  input: { countedCash: number; note?: string },
): Promise<ShiftReport | CashierError> {
  if (input.countedCash < 0) return { error: 'Counted cash cannot be negative' };
  const shift = await getOpenShift(shopId, userId);
  if (!shift) return { error: 'No open shift to close' };

  const outcome = await prisma.$transaction(async (tx) => {
    // Lock the shift row: blocks any concurrent close and pins the row for the
    // aggregation. Scope to this cashier + OPEN so a stale id reads as not-found.
    const locked = await tx.$queryRaw<Array<{ id: number; status: string }>>`
      SELECT id, status FROM cashier_shifts
      WHERE id = ${shift.id} AND shop_id = ${shopId} AND opened_by_id = ${userId}
      FOR UPDATE
    `;
    const row = locked[0];
    if (!row) return { ok: false as const, error: 'No open shift to close' };
    if (row.status !== 'OPEN') return { ok: false as const, error: 'Shift is already closed' };

    // Aggregate INSIDE the tx (and under the lock) so expected reflects drawer
    // state at close — no receipt/movement can slip in between read and write.
    const rep = await report(shopId, shift.id, { db: tx });
    if (isErr(rep)) return { ok: false as const, error: rep.error };

    // Money math in Decimal end-to-end: variance = counted − expected. Both
    // operands are rounded to 2dp HALF_UP first (CASH-7) so a 3rd-decimal
    // counted-cash input or a float-summed `expected` can't leave sub-paise
    // residue in the snapshotted variance.
    const counted = money2dp(input.countedCash);
    const expected = money2dp(rep.cash.expected);
    const variance = counted.minus(expected);
    await tx.cashierShift.update({
      where: { id: shift.id },
      data: {
        status: 'CLOSED',
        closingCounted: counted,
        expectedCash: expected,
        variance,
        closingNote: input.note ?? null,
        closedAt: new Date(),
        closedById: userId,
      },
    });
    return { ok: true as const };
  });

  if (!outcome.ok) return { error: outcome.error };
  return report(shopId, shift.id);
}

// ── reporting (X / Z) ───────────────────────────────────────────────────────

/// Full reconciliation report for a shift — live (X-report) or final (Z-report).
///
/// `openedById` restricts the lookup to the caller's own shift: a plain
/// cashier may only pull their own Z-report, so the controller passes their
/// id; a manager/owner leaves it undefined and can pull any shift's. A
/// mismatch reads as "not found" rather than leaking the shift's existence.
export async function report(
  shopId: number,
  shiftId: number,
  opts: { openedById?: number; db?: Prisma.TransactionClient | typeof prisma } = {},
): Promise<ShiftReport | CashierError> {
  // CASH-5 — `db` lets closeShift run this aggregation INSIDE its close tx (after
  // locking the shift row FOR UPDATE) so the expected-cash snapshot reflects
  // drawer state at close, with no receipt/movement slipping in between read and
  // write. Defaults to the global client for plain X/Z report reads.
  const db = opts.db ?? prisma;
  const row = await db.cashierShift.findFirst({
    where: { id: shiftId, shopId, ...(opts.openedById != null ? { openedById: opts.openedById } : {}) },
    select: SHIFT_SELECT,
  });
  if (!row) return { error: 'Shift not found' };
  const shift = await attachOpener(shiftView(row));

  // Completed sales in this shift → their invoices.
  const sales = await db.sale.findMany({
    where: { shopId, shiftId, invoiceId: { not: null } },
    select: { invoiceId: true },
  });
  const invoiceIds = sales.map((s) => s.invoiceId).filter((id): id is number => id != null);

  // Credit notes (sales returns) issued ON this shift. CASH-1 — scope by the
  // note's shiftId (stamped at issue time), not a shop-wide createdAt window,
  // so concurrent shifts on different tills can't claim each other's returns.
  // CASH-8 — also sum the credit notes' output-tax fields so the shift's GST
  // summary can NET returns (Sec 34 / GSTR-1 credit-note adjustment) instead of
  // reporting gross-of-returns output tax.
  const returnNotes = await db.invoice.findMany({
    where: { shopId, documentType: 'CREDIT_NOTE', shiftId },
    select: { id: true },
  });
  const returnInvoiceIds = returnNotes.map((n) => n.id);
  const returnsAgg = await db.invoice.aggregate({
    where: { id: { in: returnInvoiceIds } },
    _sum: {
      total: true,
      taxableValue: true,
      cgstAmount: true,
      sgstAmount: true,
      igstAmount: true,
      cessAmount: true,
    },
    _count: { _all: true },
  });

  // Receipts by tender mode (live receipts only) + GST totals from the invoices.
  // CASH-8 — `returnRateRows` is the rate-wise output-tax on the shift's credit
  // notes, netted out of `gstByRate` below.
  const [tenderRows, gst, rateRows, returnRateRows, movementRows, movementSums] = await Promise.all([
    invoiceIds.length
      ? db.payment.groupBy({
          by: ['mode'],
          where: { invoiceId: { in: invoiceIds }, type: 'RECEIPT', voidedAt: null },
          _sum: { amount: true },
          _count: { _all: true },
        })
      : Promise.resolve([] as Array<{ mode: string; _sum: { amount: Prisma.Decimal | null }; _count: { _all: number } }>),
    invoiceIds.length
      ? db.invoice.aggregate({
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
      ? db.invoiceItem.groupBy({
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
    // CASH-8 — rate-wise output tax on the shift's credit notes (returns), to
    // net against the sale rate rows so `gstByRate` shows tax net of returns.
    returnInvoiceIds.length
      ? db.invoiceItem.groupBy({
          by: ['taxPercent'],
          where: { invoiceId: { in: returnInvoiceIds } },
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
    db.cashMovement.findMany({
      where: { shiftId },
      orderBy: { id: 'asc' },
      select: { id: true, type: true, amount: true, reason: true, createdAt: true },
    }),
    db.cashMovement.groupBy({ by: ['type'], where: { shiftId }, _sum: { amount: true } }),
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

  // CASH-8 — net the shift's credit-note output tax out of the GST summary so
  // the Z-report's rate-wise + total figures are GSTR-ready (net of returns,
  // per Sec 34) rather than gross-of-returns. Netting is done in Decimal to
  // avoid float residue, then surfaced as numbers like the rest of the report.
  const D = (d: Prisma.Decimal | null | undefined) => new Prisma.Decimal(d ?? 0);
  const netGst = {
    taxable: D(gst?._sum.taxableValue).minus(D(returnsAgg._sum.taxableValue)),
    cgst: D(gst?._sum.cgstAmount).minus(D(returnsAgg._sum.cgstAmount)),
    sgst: D(gst?._sum.sgstAmount).minus(D(returnsAgg._sum.sgstAmount)),
    igst: D(gst?._sum.igstAmount).minus(D(returnsAgg._sum.igstAmount)),
    cess: D(gst?._sum.cessAmount).minus(D(returnsAgg._sum.cessAmount)),
    total: D(gst?._sum.total).minus(D(returnsAgg._sum.total)),
  };

  // Rate-wise: subtract credit-note taxable + tax per rate, then drop rows that
  // net to zero (a fully-returned rate).
  const rateMap = new Map<number, { taxable: Prisma.Decimal; tax: Prisma.Decimal }>();
  const tax = (s: { cgstAmount: Prisma.Decimal | null; sgstAmount: Prisma.Decimal | null; igstAmount: Prisma.Decimal | null; cessAmount: Prisma.Decimal | null }) =>
    D(s.cgstAmount).plus(D(s.sgstAmount)).plus(D(s.igstAmount)).plus(D(s.cessAmount));
  for (const r of rateRows) {
    const rate = num(r.taxPercent);
    const cur = rateMap.get(rate) ?? { taxable: new Prisma.Decimal(0), tax: new Prisma.Decimal(0) };
    rateMap.set(rate, { taxable: cur.taxable.plus(D(r._sum.taxableValue)), tax: cur.tax.plus(tax(r._sum)) });
  }
  for (const r of returnRateRows) {
    const rate = num(r.taxPercent);
    const cur = rateMap.get(rate) ?? { taxable: new Prisma.Decimal(0), tax: new Prisma.Decimal(0) };
    rateMap.set(rate, { taxable: cur.taxable.minus(D(r._sum.taxableValue)), tax: cur.tax.minus(tax(r._sum)) });
  }

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
    // CASH-8 — net of credit notes (returns) issued on this shift.
    gst: {
      taxable: netGst.taxable.toNumber(),
      cgst: netGst.cgst.toNumber(),
      sgst: netGst.sgst.toNumber(),
      igst: netGst.igst.toNumber(),
      cess: netGst.cess.toNumber(),
      total: netGst.total.toNumber(),
    },
    gstByRate: [...rateMap.entries()]
      .map(([rate, v]) => ({ rate, taxable: v.taxable.toNumber(), tax: v.tax.toNumber() }))
      // Drop rows that fully netted to zero (a rate entirely returned).
      .filter((r) => r.taxable !== 0 || r.tax !== 0)
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
  openedByEmail: string | null;
  openedAt: Date;
  closedAt: Date | null;
  openingFloat: number;
  expectedCash: number | null;
  closingCounted: number | null;
  variance: number | null;
}

/// Shift history (newest first) — the Z-receipt list. Open shifts show null
/// expected/counted/variance (those are snapshotted on close).
///
/// `openedById` scopes the list to one cashier's own shifts. The controller
/// passes the caller's id for a plain cashier (they only ever see their own
/// Z-reports) and leaves it undefined for a manager/owner (who see every
/// employee's, labelled by name + email).
export async function listShifts(
  shopId: number,
  opts: { limit?: number; openedById?: number } = {},
): Promise<ShiftSummary[]> {
  const limit = opts.limit ?? 30;
  const rows = await prisma.cashierShift.findMany({
    where: { shopId, ...(opts.openedById != null ? { openedById: opts.openedById } : {}) },
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
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, name: true, email: true },
  });
  const byId = new Map(users.map((u) => [u.id, u]));
  return rows.map((r) => ({
    id: r.id,
    status: r.status,
    openedById: r.openedById,
    openedByName: byId.get(r.openedById)?.name ?? null,
    openedByEmail: byId.get(r.openedById)?.email ?? null,
    openedAt: r.openedAt,
    closedAt: r.closedAt,
    openingFloat: num(r.openingFloat),
    expectedCash: r.expectedCash == null ? null : num(r.expectedCash),
    closingCounted: r.closingCounted == null ? null : num(r.closingCounted),
    variance: r.variance == null ? null : num(r.variance),
  }));
}
