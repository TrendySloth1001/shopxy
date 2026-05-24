import prisma from '../../infra/db/prisma.js';
import { financialYearForDate } from '../validation/indian.js';

/// Atomic per-shop counter. Postgres UPSERT in a single round-trip
/// keyed on (shop_id, key) — two merchants running concurrent invoice
/// allocations never collide, and the same shop's two concurrent
/// inserts upsert via the composite primary key.
async function nextCounter(shopId: number, key: string): Promise<number> {
  const rows = await prisma.$queryRaw<Array<{ value: number }>>`
    INSERT INTO "counters" ("shop_id", "key", "value") VALUES (${shopId}, ${key}, 1)
    ON CONFLICT ("shop_id", "key") DO UPDATE SET "value" = "counters"."value" + 1
    RETURNING "value"
  `;
  return rows[0].value;
}

/// Invoice number per Indian convention, per shop:
/// `${prefix}/${FY}/${seq}`. Example: `INV/25-26/00001`. Resets at the
/// FY boundary (counter key embeds FY) AND is independent across
/// merchants (counter key is composite with shop_id).
export async function nextInvoiceNo(
  shopId: number,
  type: 'SALE' | 'PURCHASE',
  documentType:
    | 'TAX_INVOICE'
    | 'BILL_OF_SUPPLY'
    | 'ESTIMATE'
    | 'PROFORMA'
    | 'CREDIT_NOTE'
    | 'DEBIT_NOTE' = 'TAX_INVOICE',
  invoiceDate: Date = new Date(),
): Promise<{ invoiceNo: string; financialYear: string }> {
  const fy = financialYearForDate(invoiceDate);
  let prefix: string;
  switch (documentType) {
    case 'ESTIMATE':
    case 'PROFORMA':
      prefix = 'EST';
      break;
    case 'CREDIT_NOTE':
      prefix = 'CRN';
      break;
    case 'DEBIT_NOTE':
      prefix = 'DBN';
      break;
    default:
      prefix = type === 'SALE' ? 'INV' : 'PUR';
  }
  const seq = await nextCounter(shopId, `${prefix}-${fy}`);
  return {
    invoiceNo: `${prefix}/${fy}/${String(seq).padStart(5, '0')}`,
    financialYear: fy,
  };
}

export async function nextChallanNo(shopId: number): Promise<string> {
  const now = new Date();
  const fy = financialYearForDate(now);
  const seq = await nextCounter(shopId, `CH-${fy}`);
  return `CH/${fy}/${String(seq).padStart(5, '0')}`;
}

/// Payment reference number per FY per shop. Mirrors `nextInvoiceNo`:
///   * RECEIPT (money in from a party) → `RCT/FY/00001`
///   * PAYMENT (money out to a vendor) → `PAY/FY/00001`
export async function nextPaymentRef(
  shopId: number,
  type: 'RECEIPT' | 'PAYMENT',
  paymentDate: Date = new Date(),
): Promise<{ referenceNo: string; financialYear: string }> {
  const fy = financialYearForDate(paymentDate);
  const prefix = type === 'RECEIPT' ? 'RCT' : 'PAY';
  const seq = await nextCounter(shopId, `${prefix}-${fy}`);
  return {
    referenceNo: `${prefix}/${fy}/${String(seq).padStart(5, '0')}`,
    financialYear: fy,
  };
}

/// Per-shop stock-adjustment numbering. Adjustment numbers reset on
/// the FY boundary like invoices.
export async function nextAdjustmentNo(shopId: number): Promise<string> {
  const fy = financialYearForDate(new Date());
  const seq = await nextCounter(shopId, `ADJ-${fy}`);
  return `ADJ/${fy}/${String(seq).padStart(5, '0')}`;
}
