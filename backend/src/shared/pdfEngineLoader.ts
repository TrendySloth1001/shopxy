/// `shared/pdf/` is an ESM-only subtree (its own package.json sets
/// `"type": "module"`, required because @react-pdf/renderer ships no CJS
/// build) inside an otherwise-CommonJS backend. Every CJS file that needs
/// it — the pdf-templates module and the 3 document renderers — crosses
/// the boundary through this one dynamic `import()`, cached after the
/// first call. See `shared/pdf/index.ts` for what's exported.
///
/// The shape below is hand-described rather than type-imported from
/// `shared/pdf/index.ts`: TS's Node16 module mode won't let a CJS file
/// even *type-import* across a CJS/ESM boundary without a `resolution-mode`
/// attribute that Node16 doesn't support (NodeNext would, but that's a
/// repo-wide config change out of scope here). `model`/`out` are typed
/// `unknown` on purpose — callers build a plain object shaped like
/// `PdfDocumentModel` (see `shared/pdf/model.ts`) rather than importing it.
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
