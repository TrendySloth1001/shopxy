/// Barrel for the one dynamic `import()` CJS callers need — this whole
/// subtree is ESM (see `./package.json`) because `@react-pdf/renderer` only
/// ships an ESM build, but the rest of the backend is CommonJS. A CJS file
/// can't `import ... from` an ESM file at the top level (TS1479), so every
/// consumer outside this directory does `await import('.../shared/pdf/index.js')`
/// instead and destructures what it needs from the result.
import { Font } from '@react-pdf/renderer';

// react-pdf hyphenates long words by default to optimize line-fill — not
// just as an overflow fallback, but whenever it thinks a break improves
// justification. That splits ordinary words mid-word ("Mumbai" →
// "Mum-"/"bai") in any column narrow enough to trigger it. Disabling it
// (return the whole word as its one "syllable") runs once, here, since this
// module only ever loads once per process (see `pdfEngineLoader.ts`).
Font.registerHyphenationCallback((word) => [word]);

export { TEMPLATE_PRESETS, DEFAULT_TEMPLATE_ID, isKnownTemplateId, resolveTemplateConfig } from './presets.js';
export { renderPdfToBuffer, renderPdfToStream } from './render.js';
export { sampleModelForKind, sampleInvoiceModel, sampleQuotationModel, sampleChallanModel } from './sampleData.js';
export type { PdfDocumentModel } from './model.js';
export { pctWidths } from './model.js';
