import { Prisma, PrismaClient } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { financialYearForDate } from '../validation/indian.js';

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

export const DEFAULT_SCHEMES: Record<Series, SchemeFields> = {
  SALE_INVOICE: { prefix: 'INV', suffix: '', separator: '/', padding: 5, resetYearly: true },
  PURCHASE_INVOICE: { prefix: 'PUR', suffix: '', separator: '/', padding: 5, resetYearly: true },
  ESTIMATE: { prefix: 'EST', suffix: '', separator: '/', padding: 5, resetYearly: true },
  CREDIT_NOTE: { prefix: 'CRN', suffix: '', separator: '/', padding: 5, resetYearly: true },
  DEBIT_NOTE: { prefix: 'DBN', suffix: '', separator: '/', padding: 5, resetYearly: true },
  CHALLAN: { prefix: 'CH', suffix: '', separator: '/', padding: 5, resetYearly: true },
  QUOTATION: { prefix: 'QUO', suffix: '', separator: '/', padding: 5, resetYearly: true },
};

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

function counterKey(series: Series, resetYearly: boolean, financialYear: string): string {
  return resetYearly ? `${series}-${financialYear}` : series;
}

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

export async function previewNextDocNo(shopId: number, series: Series, db: Db): Promise<string> {
  const scheme = await resolveScheme(shopId, series, db);
  const { seq, financialYear } = await previewNextSeq(shopId, series, db);
  return formatDocNo(scheme, seq, financialYear);
}

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

export async function nextQuotationNo(
  shopId: number,
  date: Date,
  tx: Prisma.TransactionClient,
): Promise<string> {
  return (await nextDocNo(shopId, 'QUOTATION', date, tx)).docNo;
}

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

export async function nextAdjustmentNo(shopId: number): Promise<string> {
  return (await fyScopedRef(shopId, 'ADJ', new Date())).ref;
}
