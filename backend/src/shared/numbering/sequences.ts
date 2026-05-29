import { Prisma } from '@prisma/client';
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
/// All the public nextXxx helpers below differ only in their prefix, so they
/// delegate here — change the format once and every document type follows.
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
  const { ref, financialYear } = await fyScopedRef(shopId, prefix, invoiceDate);
  return { invoiceNo: ref, financialYear };
}

export async function nextChallanNo(shopId: number): Promise<string> {
  return (await fyScopedRef(shopId, 'CH', new Date())).ref;
}

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

/// Per-shop caution money-receipt number per FY: `CAU/25-26/00001`. A
/// refundable security deposit for goods attracts no GST, so this is an
/// ordinary money receipt (not a GST receipt voucher). Used for DEPOSIT and
/// REFUND caution txns, and for the DEPOSIT minted when a party request is
/// approved (hence the optional `tx` for the Serializable approval flow).
export async function nextCautionRef(
  shopId: number,
  date: Date = new Date(),
  tx?: Prisma.TransactionClient,
): Promise<string> {
  return (await fyScopedRef(shopId, 'CAU', date, tx)).ref;
}

/// Per-shop quotation numbering per FY: `QUO/25-26/00001`.
export async function nextQuotationNo(
  shopId: number,
  date: Date = new Date(),
  tx?: Prisma.TransactionClient,
): Promise<string> {
  return (await fyScopedRef(shopId, 'QUO', date, tx)).ref;
}

/// Per-shop stock-adjustment numbering. Adjustment numbers reset on
/// the FY boundary like invoices.
export async function nextAdjustmentNo(shopId: number): Promise<string> {
  return (await fyScopedRef(shopId, 'ADJ', new Date())).ref;
}
