import { z } from "zod";

/**
 * The ~7 preset PDF look-and-feels a shop's invoices/quotations/challans can
 * render with — mirrors the backend `TEMPLATE_PRESETS` registry
 * (`backend/src/shared/pdf/presets.ts`). Metadata (id/name/description) is
 * fetched from `GET /pdf-templates` rather than hardcoded here, so a new
 * preset shows up without a client release; only the *thumbnail images* are
 * bundled client-side (`public/template-thumbnails/<id>.png`).
 */

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
