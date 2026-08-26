import { renderToBuffer, renderToStream } from '@react-pdf/renderer';
import type { Writable } from 'stream';
import type { PdfDocumentModel } from './model.js';
import { resolveTemplateConfig, type TemplateConfig } from './presets.js';
import { renderShellDocument } from './shells.js';
import { renderTraditionalDocument } from './tallyShell.js';

function buildDocument(model: PdfDocumentModel, config: TemplateConfig) {
  if (config.shellId === 'C') return renderTraditionalDocument(model, config);
  return renderShellDocument(model, config);
}

export async function renderPdfToBuffer(
  model: PdfDocumentModel,
  templateId: string | null | undefined,
): Promise<Buffer> {
  const config = resolveTemplateConfig(templateId);
  const element = buildDocument(model, config);
  return renderToBuffer(element);
}

export async function renderPdfToStream(
  model: PdfDocumentModel,
  templateId: string | null | undefined,
  out: Writable,
  onReady?: () => void,
): Promise<void> {
  const config = resolveTemplateConfig(templateId);
  const element = buildDocument(model, config);
  const pdfStream = await renderToStream(element);
  if (onReady) onReady();
  return new Promise<void>((resolve, reject) => {
    pdfStream.on('error', reject);
    out.on('error', reject);
    out.on('finish', () => resolve());
    pdfStream.pipe(out);
  });
}
