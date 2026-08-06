import { Prisma, PrismaClient } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { financialYearForDate } from '../validation/indian.js';

/// Atomic per-shop counter. Postgres UPSERT in a single round-trip
/// keyed on (shop_id, key) — two merchants running concurrent invoice
/// allocations never collide, and the same shop's two concurrent
/// inserts upsert via the composite primary key.
///
/// Accepts an optional `tx` so callers running inside an outer
/// transaction can enroll the counter bump in the same atomic unit
/// (matters for Serializable-isolation flows that need to see a
/// consistent snapshot of related rows).
async function nextCounter(
  shopId: number,
  key: string,
  tx?: Prisma.TransactionClient,
): Promise<number> {
  const db = tx ?? prisma;
  const rows = await db.$queryRaw<Array<{ value: number }>>`
    INSERT INTO "counters" ("shop_id", "key", "value") VALUES (${shopId}, ${key}, 1)
    ON CONFLICT ("shop_id", "key") DO UPDATE SET "value" = "counters"."value" + 1
    RETURNING "value"
  `;
  return rows[0].value;
}

/// FY-scoped, per-shop document reference: `${prefix}/${FY}/${seq}` (e.g.
/// `INV/25-26/00001`). Resets at the FY boundary (the counter key embeds FY)
/// and is independent across merchants (the key is composite with shop_id).
/// Kept exactly as-is for the two series NOT covered by customizable
/// numbering (`nextPaymentRef`, `nextAdjustmentNo`) — everything else now
/// goes through `nextDocNo` below.
async function fyScopedRef(
  shopId: number,
  prefix: string,
  date: Date,
  tx?: Prisma.TransactionClient,
): Promise<{ ref: string; financialYear: string }> {
  const fy = financialYearForDate(date);
  const seq = await nextCounter(shopId, `${prefix}-${fy}`, tx);
  return { ref: `${prefix}/${fy}/${String(seq).padStart(5, '0')}`, financialYear: fy };
}

// ─────────────────────────────────────────────────────────────────────────
// Customizable numbering — invoices, challans, quotations.
//
// A shop can override the prefix/suffix/separator/padding/yearly-reset of
// each series below from Invoice Settings (see `src/modules/numbering/`).
// No saved `NumberingScheme` row for a series = the DEFAULT_SCHEMES entry,
// which reproduces today's hardcoded format byte-for-byte — every existing
// shop is unaffected until it explicitly customizes a series.
// ─────────────────────────────────────────────────────────────────────────

export type Series =
  | 'SALE_INVOICE'
  | 'PURCHASE_INVOICE'
  | 'ESTIMATE'
  | 'CREDIT_NOTE'
  | 'DEBIT_NOTE'
  | 'CHALLAN'
  | 'QUOTATION';

export const ALL_SERIES: readonly Series[] = [
  'SALE_INVOICE',
  'PURCHASE_INVOICE',
  'ESTIMATE',
  'CREDIT_NOTE',
  'DEBIT_NOTE',
  'CHALLAN',
  'QUOTATION',
];

export interface SchemeFields {
  prefix: string;
  suffix: string;
  separator: string;
  padding: number;
  resetYearly: boolean;
}

/// Reproduces today's hardcoded prefixes exactly — `INV/25-26/00001`,
/// `PUR/...`, `EST/...`, `CRN/...`, `DBN/...`, `CH/...`, `QUO/...`.
export const DEFAULT_SCHEMES: Record<Series, SchemeFields> = {
  SALE_INVOICE: { prefix: 'INV', suffix: '', separator: '/', padding: 5, resetYearly: true },
  PURCHASE_INVOICE: { prefix: 'PUR', suffix: '', separator: '/', padding: 5, resetYearly: true },
  ESTIMATE: { prefix: 'EST', suffix: '', separator: '/', padding: 5, resetYearly: true },
  CREDIT_NOTE: { prefix: 'CRN', suffix: '', separator: '/', padding: 5, resetYearly: true },
  DEBIT_NOTE: { prefix: 'DBN', suffix: '', separator: '/', padding: 5, resetYearly: true },
  CHALLAN: { prefix: 'CH', suffix: '', separator: '/', padding: 5, resetYearly: true },
  QUOTATION: { prefix: 'QUO', suffix: '', separator: '/', padding: 5, resetYearly: true },
};

/// Pure formatting — no DB access. `seq` is padded to a MINIMUM width
/// (`padStart` never truncates: padding=3 with seq=1200 renders "1200",
/// not a crop). Segments are joined by `separator`, empty ones (a blank
/// prefix, or the FY segment when `resetYearly` is false) are omitted
/// entirely rather than leaving a stray separator.
export function formatDocNo(scheme: SchemeFields, seq: number, financialYear: string): string {
  const parts = [
    scheme.prefix,
    ...(scheme.resetYearly ? [financialYear] : []),
    String(seq).padStart(scheme.padding, '0'),
  ].filter((p) => p.length > 0);
  let out = parts.join(scheme.separator);
  if (scheme.suffix) out += scheme.separator + scheme.suffix;
  return out;
}

type Db = Prisma.TransactionClient | PrismaClient;

/// Merged view of a shop's scheme for one series: the saved
/// `NumberingScheme` row if the shop customized it, otherwise
/// `DEFAULT_SCHEMES[series]`. Never writes anything.
export async function resolveScheme(shopId: number, series: Series, db: Db): Promise<SchemeFields> {
  const row = await db.numberingScheme.findUnique({
    where: { shopId_series: { shopId, series } },
  });
  if (!row) return DEFAULT_SCHEMES[series];
  return {
    prefix: row.prefix,
    suffix: row.suffix,
    separator: row.separator,
    padding: row.padding,
    resetYearly: row.resetYearly,
  };
}

/// The counter this series allocates from — keyed by the STABLE series
/// name (plus FY when `resetYearly`), never by the display prefix/suffix.
/// Renaming a scheme's prefix must never reset the running sequence; only
/// toggling `resetYearly` changes which counter row is used (a documented
/// behavior change, not a silent one).
function counterKey(series: Series, resetYearly: boolean, financialYear: string): string {
  return resetYearly ? `${series}-${financialYear}` : series;
}

/// Allocates + persists the next number for a series. `tx` is REQUIRED
/// (not optional, unlike the legacy `fyScopedRef`/`nextCounter`) — this is
/// deliberate: the counter bump and the document insert that uses it MUST
/// commit or roll back together, and making `tx` mandatory turns a missed
/// enrollment into a compile error instead of a silent gap in the
/// sequence on a failed create.
export async function nextDocNo(
  shopId: number,
  series: Series,
  date: Date,
  tx: Prisma.TransactionClient,
): Promise<{ docNo: string; financialYear: string }> {
  const scheme = await resolveScheme(shopId, series, tx);
  const financialYear = financialYearForDate(date);
  const key = counterKey(series, scheme.resetYearly, financialYear);
  const seq = await nextCounter(shopId, key, tx);
  return { docNo: formatDocNo(scheme, seq, financialYear), financialYear };
}

/// Read-only: the raw sequence number + financial year the NEXT allocation
/// for this series would use, without allocating it. Exposed (not just the
/// formatted string) so the numbering settings screens can recompute a
/// live preview locally as the merchant edits prefix/suffix/padding,
/// without a network round-trip per keystroke.
export async function previewNextSeq(
  shopId: number,
  series: Series,
  db: Db,
): Promise<{ seq: number; financialYear: string }> {
  const scheme = await resolveScheme(shopId, series, db);
  const financialYear = financialYearForDate(new Date());
  const key = counterKey(series, scheme.resetYearly, financialYear);
  const counter = await db.counter.findUnique({ where: { shopId_key: { shopId, key } } });
  return { seq: (counter?.value ?? 0) + 1, financialYear };
}

/// Preview-only: what the NEXT number for a series would look like right
/// now, without allocating it. Used by the numbering settings screens to
/// show a live "next number" preview.
export async function previewNextDocNo(shopId: number, series: Series, db: Db): Promise<string> {
  const scheme = await resolveScheme(shopId, series, db);
  const { seq, financialYear } = await previewNextSeq(shopId, series, db);
  return formatDocNo(scheme, seq, financialYear);
}

/// Explicit one-time override: makes the NEXT allocated number for this
/// series equal `startAt`, by writing the counter's raw value to
/// `startAt - 1`. For merchants migrating from another system who need to
/// continue an existing sequence rather than restart at 1. No floor check
/// against the current value — the `@@unique([shopId, invoiceNo])`
/// constraint on `Invoice` (and the equivalent on Challan/Quotation) is
/// the real backstop against an actual collision: a document create fails
/// loudly rather than silently duplicating a number.
export async function setCounterStart(
  shopId: number,
  series: Series,
  startAt: number,
  db: Db,
): Promise<void> {
  const scheme = await resolveScheme(shopId, series, db);
  const financialYear = financialYearForDate(new Date());
  const key = counterKey(series, scheme.resetYearly, financialYear);
  await db.counter.upsert({
    where: { shopId_key: { shopId, key } },
    create: { shopId, key, value: startAt - 1 },
    update: { value: startAt - 1 },
  });
}

function seriesForInvoice(
  type: 'SALE' | 'PURCHASE',
  documentType:
    | 'TAX_INVOICE'
    | 'BILL_OF_SUPPLY'
    | 'ESTIMATE'
    | 'PROFORMA'
    | 'CREDIT_NOTE'
    | 'DEBIT_NOTE',
): Series {
  switch (documentType) {
    case 'ESTIMATE':
    case 'PROFORMA':
      return 'ESTIMATE';
    case 'CREDIT_NOTE':
      return 'CREDIT_NOTE';
    case 'DEBIT_NOTE':
      return 'DEBIT_NOTE';
    default:
      return type === 'SALE' ? 'SALE_INVOICE' : 'PURCHASE_INVOICE';
  }
}

/// Invoice number, per shop — customizable per series via Invoice Settings
/// (default matches the Indian convention `${prefix}/${FY}/${seq}`, e.g.
/// `INV/25-26/00001`). `tx` is required — see `nextDocNo`.
export async function nextInvoiceNo(
  shopId: number,
  type: 'SALE' | 'PURCHASE',
  documentType:
    | 'TAX_INVOICE'
    | 'BILL_OF_SUPPLY'
    | 'ESTIMATE'
    | 'PROFORMA'
    | 'CREDIT_NOTE'
    | 'DEBIT_NOTE',
  invoiceDate: Date,
  tx: Prisma.TransactionClient,
): Promise<{ invoiceNo: string; financialYear: string }> {
  const { docNo, financialYear } = await nextDocNo(
    shopId,
    seriesForInvoice(type, documentType),
    invoiceDate,
    tx,
  );
  return { invoiceNo: docNo, financialYear };
}

export async function nextChallanNo(shopId: number, tx: Prisma.TransactionClient): Promise<string> {
  return (await nextDocNo(shopId, 'CHALLAN', new Date(), tx)).docNo;
}

/// Per-shop quotation numbering per FY: `QUO/25-26/00001` by default.
export async function nextQuotationNo(
  shopId: number,
  date: Date,
  tx: Prisma.TransactionClient,
): Promise<string> {
  return (await nextDocNo(shopId, 'QUOTATION', date, tx)).docNo;
}

// ─────────────────────────────────────────────────────────────────────────
// Out of scope for customizable numbering — untouched, same as before.
// ─────────────────────────────────────────────────────────────────────────

/// Payment reference number per FY per shop. Mirrors `nextInvoiceNo`:
///   * RECEIPT (money in from a party) → `RCT/FY/00001`
///   * PAYMENT (money out to a vendor) → `PAY/FY/00001`
export async function nextPaymentRef(
  shopId: number,
  type: 'RECEIPT' | 'PAYMENT',
  paymentDate: Date = new Date(),
  tx?: Prisma.TransactionClient,
): Promise<{ referenceNo: string; financialYear: string }> {
  const prefix = type === 'RECEIPT' ? 'RCT' : 'PAY';
  const { ref, financialYear } = await fyScopedRef(shopId, prefix, paymentDate, tx);
  return { referenceNo: ref, financialYear };
}

/// Per-shop stock-adjustment numbering. Adjustment numbers reset on
/// the FY boundary like invoices.
export async function nextAdjustmentNo(shopId: number): Promise<string> {
  return (await fyScopedRef(shopId, 'ADJ', new Date())).ref;
}
