import { renderToBuffer, renderToStream } from '@react-pdf/renderer';
import type { Writable } from 'stream';
import type { PdfDocumentModel } from './model.js';
import { resolveTemplateConfig, type TemplateConfig } from './presets.js';
import { renderShellDocument } from './shells.js';
import { renderTraditionalDocument } from './tallyShell.js';

/// ShellA/B share one render path (`renderShellDocument`); ShellC (the
/// bordered-ledger "traditional" preset) is different enough — per-cell
/// grid borders, a nested info box, its own signature footer — to be its
/// own render function rather than another config fed into the shared one.
function buildDocument(model: PdfDocumentModel, config: TemplateConfig) {
  if (config.shellId === 'C') return renderTraditionalDocument(model, config);
  return renderShellDocument(model, config);
}

/// Renders a document model to a PDF Buffer using the resolved template
/// (falls back to the default preset for a retired/unknown `templateId`).
export async function renderPdfToBuffer(
  model: PdfDocumentModel,
  templateId: string | null | undefined,
): Promise<Buffer> {
  const config = resolveTemplateConfig(templateId);
  const element = buildDocument(model, config);
  return renderToBuffer(element);
}

/// Streams a document model straight into a Writable (the HTTP response),
/// resolving once the stream has finished flushing.
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
