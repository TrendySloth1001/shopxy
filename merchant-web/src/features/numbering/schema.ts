import { z } from "zod";

export const SERIES_VALUES = [
  "SALE_INVOICE",
  "PURCHASE_INVOICE",
  "ESTIMATE",
  "CREDIT_NOTE",
  "DEBIT_NOTE",
  "CHALLAN",
  "QUOTATION",
] as const;
export type Series = (typeof SERIES_VALUES)[number];

export const SERIES_LABELS: Record<Series, string> = {
  SALE_INVOICE: "Sale invoice",
  PURCHASE_INVOICE: "Purchase invoice",
  ESTIMATE: "Estimate / Proforma",
  CREDIT_NOTE: "Credit note",
  DEBIT_NOTE: "Debit note",
  CHALLAN: "Challan",
  QUOTATION: "Quotation",
};

export const SEPARATOR_VALUES = ["/", "-", ".", ""] as const;

export const numberingSchemeSchema = z.object({
  series: z.enum(SERIES_VALUES),
  prefix: z.string(),
  suffix: z.string(),
  separator: z.string(),
  padding: z.coerce.number(),
  resetYearly: z.boolean(),
  isCustom: z.boolean(),
  nextPreview: z.string(),
  nextSeq: z.coerce.number(),
  financialYear: z.string(),
});
export type NumberingScheme = z.infer<typeof numberingSchemeSchema>;

export const numberingSchemeListSchema = z.array(numberingSchemeSchema);

const CODE_RE = /^[A-Za-z0-9\-_.]*$/;

export const updateSchemeSchema = z.object({
  prefix: z.string().max(10).regex(CODE_RE, "Only letters, numbers, - _ . allowed").optional(),
  suffix: z.string().max(10).regex(CODE_RE, "Only letters, numbers, - _ . allowed").optional(),
  separator: z.enum(SEPARATOR_VALUES).optional(),
  padding: z.number().int().min(1).max(8).optional(),
  resetYearly: z.boolean().optional(),
});
export type UpdateSchemeInput = z.infer<typeof updateSchemeSchema>;

export const setNextNumberSchema = z.object({
  startAt: z.number().int().positive(),
});

export function formatDocNoPreview(
  scheme: {
    prefix: string;
    suffix: string;
    separator: string;
    padding: number;
    resetYearly: boolean;
  },
  seq: number,
  financialYear: string,
): string {
  const parts = [
    scheme.prefix,
    ...(scheme.resetYearly ? [financialYear] : []),
    String(seq).padStart(scheme.padding, "0"),
  ].filter((p) => p.length > 0);
  let out = parts.join(scheme.separator);
  if (scheme.suffix) out += scheme.separator + scheme.suffix;
  return out;
}
