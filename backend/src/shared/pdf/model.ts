/// The generic document shape every PDF template renders from. Each of the
/// three renderers (invoice/quotation/challan) builds one of these from its
/// own Prisma data — the shape is doc-kind-agnostic on purpose: a block that
/// doesn't apply to a given document (HSN summary on a challan, a UPI QR on
/// a quotation) is simply left `undefined` rather than the templates having
/// to know which doc kind they're drawing.
export interface PdfPartyInfo {
  name: string;
  addressLine?: string;
  gstin?: string | null;
  pan?: string | null;
  extraLine?: string; // e.g. a phone number when neither GSTIN nor PAN is set
}

export interface PdfMetaField {
  label: string;
  value: string;
}

export interface PdfTableCell {
  text: string;
  align: 'left' | 'right';
}

export interface PdfTableRow {
  cells: PdfTableCell[];
  // Item name + SKU/HSN are rendered as two stacked lines within one cell —
  // matching the existing PDFKit `"${name}\n${sku}"` convention.
}

export interface PdfTable {
  headers: PdfTableCell[];
  widths: number[]; // percentages of the usable width, sum ≈ 100
  rows: PdfTableRow[];
}

export interface PdfTotalRow {
  label: string;
  value: string;
  bold?: boolean;
}

export interface PdfDocumentModel {
  kind: 'invoice' | 'quotation' | 'challan';
  title: string;
  /// Small print near the title — the Original/Duplicate/Triplicate strip
  /// for invoices, a status label for quotations. Absent for challans.
  titleBadgeLines?: string[];
  shop: PdfPartyInfo;
  /// Heading above the shop block — most doc kinds show none (just the shop
  /// name); the challan labels both sides ("Consignor"/"Consignee" per
  /// Rule 55), so this is optional.
  shopLabel?: string;
  counterpartyLabel: string; // "Bill To" / "Vendor" / "Quote For" / "Consignee"
  counterparty: PdfPartyInfo;
  meta: PdfMetaField[];
  metaSecondRow?: PdfMetaField[]; // GST-2 original-invoice reference row
  items: PdfTable;
  hsnSummary?: PdfTable;
  totals: PdfTotalRow[];
  amountInWords?: string;
  declaration?: string;
  upiQr?: { buffer: Buffer; caption: string; vpaLine?: string };
  signatureName?: string; // "For <Shop Name>" — absent = no signature block
  note?: string;
}

/// Converts PDFKit-style absolute point widths (which summed to the old
/// usable width of 515pt) into percentages of the table's own width, so the
/// same proportions carry over into react-pdf's percentage-based columns.
export function pctWidths(points: number[]): number[] {
  const total = points.reduce((a, b) => a + b, 0);
  return points.map((p) => (p / total) * 100);
}
