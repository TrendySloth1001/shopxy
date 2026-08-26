import { z } from "zod";

export const pdfTemplateSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
  order: z.number(),
});
export type PdfTemplate = z.infer<typeof pdfTemplateSchema>;

export const pdfTemplateListSchema = z.array(pdfTemplateSchema);

export const DOC_KINDS = ["invoice", "quotation", "challan"] as const;
export type DocKind = (typeof DOC_KINDS)[number];
