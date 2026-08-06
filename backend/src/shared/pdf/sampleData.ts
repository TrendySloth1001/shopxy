import type { PdfDocumentModel } from './model.js';
import { pctWidths } from './model.js';

/// Canned "sample" documents (no real shop/customer data) used by the
/// `GET /pdf-templates/:id/sample` preview endpoint — lets a merchant see
/// what a template looks like before applying it to their real documents.

const SAMPLE_ITEM_ROWS = [
  { name: 'Cotton Kurti — Blue, Size M', sku: 'KRT-BLU-M', hsn: '6204', qty: '2 pcs', rate: '899.00', disc: '0.00', taxable: '1798.00', gst: '5%', tax1: '44.95', tax2: '44.95', total: '1887.90' },
  { name: 'Denim Jeans — Slim Fit', sku: 'JNS-SLM-32', hsn: '6203', qty: '1 pcs', rate: '1499.00', disc: '100.00', taxable: '1399.00', gst: '12%', tax1: '83.94', tax2: '83.94', total: '1566.88' },
  { name: 'Leather Belt — Brown', sku: 'BLT-BRN-L', hsn: '4203', qty: '3 pcs', rate: '349.00', disc: '0.00', taxable: '1047.00', gst: '18%', tax1: '94.23', tax2: '94.23', total: '1235.46' },
];

function invoiceItemsTable() {
  return {
    headers: [
      { text: 'Sr', align: 'left' as const },
      { text: 'Item / SKU', align: 'left' as const },
      { text: 'HSN', align: 'left' as const },
      { text: 'Qty', align: 'right' as const },
      { text: 'Rate', align: 'right' as const },
      { text: 'Disc', align: 'right' as const },
      { text: 'Taxable', align: 'right' as const },
      { text: 'GST%', align: 'right' as const },
      { text: 'CGST', align: 'right' as const },
      { text: 'SGST', align: 'right' as const },
      { text: 'Total', align: 'right' as const },
    ],
    widths: pctWidths([22, 116, 40, 34, 42, 34, 50, 30, 45, 45, 57]),
    rows: SAMPLE_ITEM_ROWS.map((it, i) => ({
      cells: [
        { text: String(i + 1), align: 'left' as const },
        { text: `${it.name}\n${it.sku}`, align: 'left' as const },
        { text: it.hsn, align: 'left' as const },
        { text: it.qty, align: 'right' as const },
        { text: it.rate, align: 'right' as const },
        { text: it.disc, align: 'right' as const },
        { text: it.taxable, align: 'right' as const },
        { text: it.gst, align: 'right' as const },
        { text: it.tax1, align: 'right' as const },
        { text: it.tax2, align: 'right' as const },
        { text: it.total, align: 'right' as const },
      ],
    })),
  };
}

export function sampleInvoiceModel(): PdfDocumentModel {
  return {
    kind: 'invoice',
    title: 'TAX INVOICE',
    titleBadgeLines: ['Original for Recipient', 'Duplicate for Transporter', 'Triplicate for Supplier'],
    shop: {
      name: 'Aanya Fashion House',
      addressLine: '12 MG Road, Indore, Madhya Pradesh - 452001',
      gstin: '23AAAAA0000A1Z5',
      pan: 'AAAAA0000A',
    },
    counterpartyLabel: 'Bill To',
    counterparty: {
      name: 'Riya Sharma',
      addressLine: '45 Park Street, Indore, Madhya Pradesh - 452010',
    },
    meta: [
      { label: 'Invoice No', value: 'INV/25-26/00042' },
      { label: 'Date', value: '05/08/2026' },
      { label: 'Place of Supply', value: '23 - Madhya Pradesh' },
      { label: 'FY', value: '2025-26' },
    ],
    items: invoiceItemsTable(),
    hsnSummary: {
      headers: [
        { text: 'HSN', align: 'left' as const },
        { text: 'Taxable Value', align: 'right' as const },
        { text: 'CGST', align: 'right' as const },
        { text: 'SGST', align: 'right' as const },
        { text: 'Cess', align: 'right' as const },
        { text: 'Total Tax', align: 'right' as const },
      ],
      widths: pctWidths([80, 100, 80, 80, 80, 95]),
      rows: [
        {
          cells: [
            { text: '6204', align: 'left' as const },
            { text: '1798.00', align: 'right' as const },
            { text: '44.95', align: 'right' as const },
            { text: '44.95', align: 'right' as const },
            { text: '0.00', align: 'right' as const },
            { text: '89.90', align: 'right' as const },
          ],
        },
      ],
    },
    totals: [
      { label: 'Subtotal', value: 'Rs. 4244.00' },
      { label: 'Total Discount', value: '- Rs. 100.00' },
      { label: 'Taxable Value', value: 'Rs. 4244.00' },
      { label: 'CGST', value: 'Rs. 223.12' },
      { label: 'SGST', value: 'Rs. 223.12' },
      { label: 'Grand Total', value: 'Rs. 4690.24', bold: true },
    ],
    amountInWords: 'Rupees Four Thousand Six Hundred Ninety and Twenty Four Paise Only',
    declaration: 'Tax payable on reverse charge: No',
    upiQr: undefined, // sample endpoint skips a live QR — no real VPA to encode
    signatureName: 'For Aanya Fashion House',
    note: 'Thank you for your business!',
    traditionalMeta: {
      documentNo: 'INV/25-26/00042',
      documentDate: '05/08/2026',
      paymentTerms: 'Cheque',
      buyersOrderNo: '00789',
      buyersOrderDate: '04/08/2026',
      termsOfDelivery: '45 days credit from invoice date',
    },
  };
}

export function sampleQuotationModel(): PdfDocumentModel {
  return {
    kind: 'quotation',
    title: 'QUOTATION',
    titleBadgeLines: ['Awaiting acceptance'],
    shop: {
      name: 'Aanya Fashion House',
      addressLine: '12 MG Road, Indore, Madhya Pradesh - 452001',
      gstin: '23AAAAA0000A1Z5',
    },
    counterpartyLabel: 'Quote For',
    counterparty: { name: 'Riya Sharma', addressLine: '45 Park Street, Indore, Madhya Pradesh - 452010' },
    meta: [
      { label: 'Quotation No', value: 'QUO/25-26/00017' },
      { label: 'Date', value: '05/08/2026' },
      { label: 'Place of Supply', value: '23 - Madhya Pradesh' },
    ],
    items: {
      headers: [
        { text: 'Sr', align: 'left' as const },
        { text: 'Item / SKU', align: 'left' as const },
        { text: 'Qty', align: 'right' as const },
        { text: 'Rate', align: 'right' as const },
        { text: 'Disc', align: 'right' as const },
        { text: 'Taxable', align: 'right' as const },
        { text: 'GST%', align: 'right' as const },
        { text: 'Amount', align: 'right' as const },
      ],
      widths: pctWidths([24, 191, 40, 56, 44, 60, 36, 64]),
      rows: SAMPLE_ITEM_ROWS.map((it, i) => ({
        cells: [
          { text: String(i + 1), align: 'left' as const },
          { text: `${it.name}\n${it.sku}`, align: 'left' as const },
          { text: it.qty, align: 'right' as const },
          { text: it.rate, align: 'right' as const },
          { text: it.disc, align: 'right' as const },
          { text: it.taxable, align: 'right' as const },
          { text: it.gst, align: 'right' as const },
          { text: it.total, align: 'right' as const },
        ],
      })),
    },
    totals: [
      { label: 'Subtotal', value: 'Rs. 4244.00' },
      { label: 'CGST', value: 'Rs. 111.56' },
      { label: 'SGST', value: 'Rs. 111.56' },
      { label: 'Total', value: 'Rs. 4467.12', bold: true },
    ],
    declaration:
      'This is a quotation, not a tax invoice. Prices are an estimate and may change until confirmed. Taxes are computed on acceptance.',
    note: 'Valid for 7 days from the date above.',
    traditionalMeta: {
      documentNo: 'QUO/25-26/00017',
      documentDate: '05/08/2026',
      termsOfDelivery: 'Valid for 7 days from the date above',
    },
  };
}

export function sampleChallanModel(): PdfDocumentModel {
  return {
    kind: 'challan',
    title: 'DELIVERY CHALLAN',
    shop: {
      name: 'Aanya Fashion House',
      addressLine: '12 MG Road, Indore, Madhya Pradesh - 452001',
      gstin: '23AAAAA0000A1Z5',
    },
    shopLabel: 'Consignor',
    counterpartyLabel: 'Consignee',
    counterparty: {
      name: 'Riya Sharma',
      addressLine: '45 Park Street, Indore, Madhya Pradesh - 452010',
      extraLine: '+91 98765 43210',
    },
    meta: [
      { label: 'Challan No', value: 'CH/25-26/00009' },
      { label: 'Date', value: '05/08/2026' },
      { label: 'Place of Supply', value: '23 - Madhya Pradesh' },
      { label: 'Supply Type', value: 'Intra-State' },
    ],
    items: invoiceItemsTable(),
    totals: [
      { label: 'Subtotal', value: 'Rs. 4244.00' },
      { label: 'CGST', value: 'Rs. 223.12' },
      { label: 'SGST', value: 'Rs. 223.12' },
      { label: 'Total', value: 'Rs. 4690.24', bold: true },
    ],
    declaration: 'Goods dispatched for delivery — not a tax invoice, no payment is due against this document.',
    signatureName: 'For Aanya Fashion House',
    note: 'Please verify item count on receipt.',
    traditionalMeta: {
      documentNo: 'CH/25-26/00009',
      documentDate: '05/08/2026',
      buyersOrderNo: '00789',
      buyersOrderDate: '04/08/2026',
    },
  };
}

export function sampleModelForKind(kind: 'invoice' | 'quotation' | 'challan'): PdfDocumentModel {
  if (kind === 'quotation') return sampleQuotationModel();
  if (kind === 'challan') return sampleChallanModel();
  return sampleInvoiceModel();
}
