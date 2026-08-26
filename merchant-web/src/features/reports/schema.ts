import { z } from "zod";

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
          productId: z.coerce.string().nullish(),
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

const gstHeadSchema = z.object({
  igst: dailyNum,
  cgst: dailyNum,
  sgst: dailyNum,
});

export const gstReportSchema = z
  .object({
    outputTax: dailyNum,
    inputTax: dailyNum,
    netPayable: dailyNum,
    outputCess: dailyNum.nullish(),
    inputCess: dailyNum.nullish(),
    netCessPayable: dailyNum.nullish(),
    byHead: z
      .object({
        output: gstHeadSchema,
        input: gstHeadSchema,
        netPayable: gstHeadSchema,
      })
      .nullish(),
    returns: z
      .object({
        gst: dailyNum,
        igst: dailyNum,
        cgst: dailyNum,
        sgst: dailyNum,
        cess: dailyNum,
      })
      .nullish(),
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
    returnedCogs: dailyNum.nullish(),
    writeoffs: dailyNum,
    grossProfit: dailyNum,
    netProfit: dailyNum,
    grossMargin: dailyNum,
  })
  .passthrough();
export type PnlReport = z.infer<typeof pnlReportSchema>;

export const soldItemSchema = z.object({
  productName: z.string().nullish(),
  productSku: z.string().nullish(),
  unit: z.string().nullish(),
  quantity: dailyNum,
  total: dailyNum,
  invoiceId: z.coerce.string().nullish(),
  invoiceNo: z.string().nullish(),
  soldAt: z.string(),
});
export type SoldItem = z.infer<typeof soldItemSchema>;

const paginationSchema = z
  .object({
    page: z.coerce.number().default(1),
    limit: z.coerce.number().default(25),
    total: z.coerce.number().default(0),
    totalPages: z.coerce.number().default(0),
  })
  .nullish()
  .transform((v) => v ?? { page: 1, limit: 25, total: 0, totalPages: 0 });

export const soldItemsPageSchema = z.object({
  data: z
    .array(soldItemSchema)
    .nullish()
    .transform((v) => v ?? []),
  pagination: paginationSchema,
});
export type SoldItemsPage = z.infer<typeof soldItemsPageSchema>;

export const soldProductSchema = z.object({
  productId: z.coerce.string(),
  productName: z.string().nullish(),
  productSku: z.string().nullish(),
  unit: z.string().nullish(),
  salesCount: dailyNum,
  totalQuantity: dailyNum,
  totalAmount: dailyNum,
  lastSoldAt: z.string(),
});
export type SoldProduct = z.infer<typeof soldProductSchema>;

const soldTotalsSchema = z
  .object({
    salesCount: dailyNum,
    totalQuantity: dailyNum,
    totalAmount: dailyNum,
  })
  .nullish()
  .transform((v) => v ?? { salesCount: 0, totalQuantity: 0, totalAmount: 0 });

export const soldProductsPageSchema = z.object({
  data: z
    .array(soldProductSchema)
    .nullish()
    .transform((v) => v ?? []),
  pagination: paginationSchema,
  totals: soldTotalsSchema,
});
export type SoldProductsPage = z.infer<typeof soldProductsPageSchema>;
