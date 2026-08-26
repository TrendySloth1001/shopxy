export interface PdfEngine {
  TEMPLATE_PRESETS: { id: string; name: string; description: string; order: number }[];
  isKnownTemplateId: (id: string) => boolean;
  sampleModelForKind: (kind: 'invoice' | 'quotation' | 'challan') => unknown;
  renderPdfToBuffer: (model: unknown, templateId: string | null | undefined) => Promise<Buffer>;
  renderPdfToStream: (
    model: unknown,
    templateId: string | null | undefined,
    out: NodeJS.WritableStream,
    onReady?: () => void,
  ) => Promise<void>;
}

let enginePromise: Promise<PdfEngine> | null = null;
export function loadPdfEngine(): Promise<PdfEngine> {
  if (!enginePromise) {
    enginePromise = import('./pdf/index.js') as unknown as Promise<PdfEngine>;
  }
  return enginePromise;
}
