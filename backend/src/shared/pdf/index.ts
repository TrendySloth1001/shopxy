/// Barrel for the one dynamic `import()` CJS callers need — this whole
/// subtree is ESM (see `./package.json`) because `@react-pdf/renderer` only
/// ships an ESM build, but the rest of the backend is CommonJS. A CJS file
/// can't `import ... from` an ESM file at the top level (TS1479), so every
/// consumer outside this directory does `await import('.../shared/pdf/index.js')`
/// instead and destructures what it needs from the result.
export { TEMPLATE_PRESETS, DEFAULT_TEMPLATE_ID, isKnownTemplateId, resolveTemplateConfig } from './presets.js';
export { renderPdfToBuffer, renderPdfToStream } from './render.js';
export { sampleModelForKind, sampleInvoiceModel, sampleQuotationModel, sampleChallanModel } from './sampleData.js';
export type { PdfDocumentModel } from './model.js';
export { pctWidths } from './model.js';
