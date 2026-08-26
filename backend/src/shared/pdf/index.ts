import { Font } from '@react-pdf/renderer';

Font.registerHyphenationCallback((word) => [word]);

export { TEMPLATE_PRESETS, DEFAULT_TEMPLATE_ID, isKnownTemplateId, resolveTemplateConfig } from './presets.js';
export { renderPdfToBuffer, renderPdfToStream } from './render.js';
export { sampleModelForKind, sampleInvoiceModel, sampleQuotationModel, sampleChallanModel } from './sampleData.js';
export type { PdfDocumentModel } from './model.js';
export { pctWidths } from './model.js';
