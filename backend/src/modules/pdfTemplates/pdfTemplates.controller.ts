import { Request, Response } from 'express';
import { z } from 'zod';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';

const sampleQuerySchema = z.object({
  kind: z.enum(['invoice', 'quotation', 'challan']),
});

export class PdfTemplatesController {
  /// Metadata only (id/name/description/order) — thumbnail *images* are
  /// bundled as static assets client-side, not served from here.
  async list(_req: Request, res: Response): Promise<void> {
    const { TEMPLATE_PRESETS } = await loadPdfEngine();
    res.json(
      TEMPLATE_PRESETS.map((p) => ({
        id: p.id,
        name: p.name,
        description: p.description,
        order: p.order,
      })),
    );
  }

  /// Renders one canned sample document (no real shop/customer data) in the
  /// requested template — lets a merchant preview a look before applying it.
  /// Auth-gated like the real download endpoints (rendering isn't free) and
  /// 400s on an unrecognized template id rather than silently substituting
  /// the default, which would just confuse a side-by-side comparison.
  async sample(req: Request, res: Response): Promise<void> {
    const { isKnownTemplateId, sampleModelForKind, renderPdfToBuffer } = await loadPdfEngine();
    const templateId = req.params.id;
    if (!isKnownTemplateId(templateId)) {
      res.status(400).json({ error: 'Unknown template id' });
      return;
    }
    const parsed = sampleQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'kind must be one of invoice, quotation, challan' });
      return;
    }
    const model = sampleModelForKind(parsed.data.kind);
    const buffer = await renderPdfToBuffer(model, templateId);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${templateId}-sample.pdf"`);
    res.send(buffer);
  }
}

export const pdfTemplatesController = new PdfTemplatesController();
