import prisma from '../../infra/db/prisma.js';
import { financialYearForDate } from '../validation/indian.js';

/// Atomic per-key counter. Postgres UPSERT in a single round-trip means
/// two concurrent allocations never collide — fixes the `count()+1`
/// race flagged in audit C4.
async function nextCounter(key: string): Promise<number> {
  const rows = await prisma.$queryRaw<Array<{ value: number }>>`
    INSERT INTO "counters" ("key", "value") VALUES (${key}, 1)
    ON CONFLICT ("key") DO UPDATE SET "value" = "counters"."value" + 1
    RETURNING "value"
  `;
  return rows[0].value;
}

/// Invoice number per Indian convention: ${prefix}/${FY}/${seq}.
/// Example: `INV/25-26/00001`. Resets at the FY boundary because the
/// counter key embeds the FY string.
///
/// Document types follow the same shape with different prefixes:
///   TAX_INVOICE/BILL_OF_SUPPLY → INV (sale) | PUR (purchase)
///   ESTIMATE / PROFORMA         → EST
///   CREDIT_NOTE                 → CRN
///   DEBIT_NOTE                  → DBN
export async function nextInvoiceNo(
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
  const seq = await nextCounter(`${prefix}-${fy}`);
  return {
    invoiceNo: `${prefix}/${fy}/${String(seq).padStart(5, '0')}`,
    financialYear: fy,
  };
}

export async function nextChallanNo(): Promise<string> {
  const now = new Date();
  const fy = financialYearForDate(now);
  const seq = await nextCounter(`CH-${fy}`);
  return `CH/${fy}/${String(seq).padStart(5, '0')}`;
}

/// Payment reference number per FY. Mirrors `nextInvoiceNo`:
///   * RECEIPT (money in from a party) → `RCT/FY/00001`
///   * PAYMENT (money out to a vendor) → `PAY/FY/00001`
/// Counter resets at the FY boundary because the counter key embeds FY.
export async function nextPaymentRef(
  type: 'RECEIPT' | 'PAYMENT',
  paymentDate: Date = new Date(),
): Promise<{ referenceNo: string; financialYear: string }> {
  const fy = financialYearForDate(paymentDate);
  const prefix = type === 'RECEIPT' ? 'RCT' : 'PAY';
  const seq = await nextCounter(`${prefix}-${fy}`);
  return {
    referenceNo: `${prefix}/${fy}/${String(seq).padStart(5, '0')}`,
    financialYear: fy,
  };
}
