import { z } from "zod";

/**
 * Report shapes, mirroring the backend `reports` module (`/reports/*`). Each
 * report takes a `from`/`to` ISO range and returns confirmed-document totals.
 * All money is rupees (Decimal serialised as a number).
 */

const dailyNum = z.coerce.number().default(0);

export const salesReportSchema = z
  .object({
    summary: z.object({
      invoiceCount: z.coerce.number().default(0),
      subtotal: dailyNum,
      taxableValue: dailyNum,
      taxAmount: dailyNum,
      total: dailyNum,
      refunds: dailyNum,
      netRevenue: dailyNum,
      refundCount: z.coerce.number().default(0),
    }),
    daily: z
      .array(z.object({ day: z.string(), invoices: dailyNum, revenue: dailyNum, tax: dailyNum }))
      .nullish()
      .transform((v) => v ?? []),
    topProducts: z
      .array(
        z.object({
          productName: z.string().nullish(),
          productSku: z.string().nullish(),
          quantity: dailyNum,
          revenue: dailyNum,
        }),
      )
      .nullish()
      .transform((v) => v ?? []),
    topCustomers: z
      .array(z.object({ name: z.string().nullish(), revenue: dailyNum, invoices: dailyNum }))
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();
export type SalesReport = z.infer<typeof salesReportSchema>;

export const purchasesReportSchema = z
  .object({
    summary: z.object({
      invoiceCount: z.coerce.number().default(0),
      subtotal: dailyNum,
      taxableValue: dailyNum,
      taxAmount: dailyNum,
      total: dailyNum,
    }),
    daily: z
      .array(z.object({ day: z.string(), invoices: dailyNum, spend: dailyNum, tax: dailyNum }))
      .nullish()
      .transform((v) => v ?? []),
    topProducts: z
      .array(
        z.object({
          productName: z.string().nullish(),
          productSku: z.string().nullish(),
          quantity: dailyNum,
          spend: dailyNum,
        }),
      )
      .nullish()
      .transform((v) => v ?? []),
    topVendors: z
      .array(z.object({ name: z.string().nullish(), spend: dailyNum, invoices: dailyNum }))
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();
export type PurchasesReport = z.infer<typeof purchasesReportSchema>;

const gstRateSchema = z.object({
  rate: z.coerce.number().default(0),
  taxable: dailyNum,
  tax: dailyNum,
  cess: dailyNum.nullish(),
});

export const gstReportSchema = z
  .object({
    outputTax: dailyNum,
    inputTax: dailyNum,
    netPayable: dailyNum,
    outputCess: dailyNum.nullish(),
    inputCess: dailyNum.nullish(),
    netCessPayable: dailyNum.nullish(),
    outputByRate: z
      .array(gstRateSchema)
      .nullish()
      .transform((v) => v ?? []),
    inputByRate: z
      .array(gstRateSchema)
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();
export type GstReport = z.infer<typeof gstReportSchema>;

export const pnlReportSchema = z
  .object({
    revenue: dailyNum,
    refunds: dailyNum.nullish(),
    cogs: dailyNum,
    writeoffs: dailyNum,
    grossProfit: dailyNum,
    netProfit: dailyNum,
    grossMargin: dailyNum,
  })
  .passthrough();
export type PnlReport = z.infer<typeof pnlReportSchema>;
