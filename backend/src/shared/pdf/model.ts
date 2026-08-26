export interface PdfPartyInfo {
  name: string;
  addressLine?: string;
  gstin?: string | null;
  pan?: string | null;
  extraLine?: string;
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
}

export interface PdfTable {
  headers: PdfTableCell[];
  widths: number[];
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
  titleBadgeLines?: string[];
  shop: PdfPartyInfo;
  shopLabel?: string;
  counterpartyLabel: string;
  counterparty: PdfPartyInfo;
  meta: PdfMetaField[];
  metaSecondRow?: PdfMetaField[];
  items: PdfTable;
  hsnSummary?: PdfTable;
  totals: PdfTotalRow[];
  amountInWords?: string;
  declaration?: string;
  upiQr?: { buffer: Buffer; caption: string; vpaLine?: string };
  signatureName?: string;
  note?: string;
  traditionalMeta?: {
    documentNo: string;
    documentDate: string;
    deliveryNote?: string;
    paymentTerms?: string;
    buyersOrderNo?: string;
    buyersOrderDate?: string;
    dispatchDocNo?: string;
    dispatchNoteDate?: string;
    dispatchedThrough?: string;
    destination?: string;
    termsOfDelivery?: string;
  };
}

export function pctWidths(points: number[]): number[] {
  const total = points.reduce((a, b) => a + b, 0);
  return points.map((p) => (p / total) * 100);
}
