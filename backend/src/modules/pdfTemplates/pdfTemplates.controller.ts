import { Request, Response } from 'express';
import { z } from 'zod';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';

const sampleQuerySchema = z.object({
  kind: z.enum(['invoice', 'quotation', 'challan']),
});

export class PdfTemplatesController {
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
