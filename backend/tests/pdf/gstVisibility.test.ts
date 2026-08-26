import { describe, it, expect } from 'vitest';
import { Prisma } from '@prisma/client';
import { buildPdfColumns } from '../../src/shared/pdfColumns.js';
import { invoiceGstVisibility } from '../../src/modules/invoices/invoice-pdf-renderer.js';

const D = (n: number | string) => new Prisma.Decimal(n);

function item(over: Partial<{ hsn: string | null; taxPercent: number }> = {}) {
  return {
    hsn: over.hsn === undefined ? '6204' : over.hsn,
    taxPercent: D(over.taxPercent ?? 5),
  };
}

function invoice(
  over: Partial<{
    type: string;
    invoiceDate: Date;
    items: { hsn: string | null; taxPercent: Prisma.Decimal }[];
    igst: number;
    cgst: number;
    sgst: number;
    cess: number;
  }> = {},
) {
  return {
    type: over.type ?? 'SALE',
    invoiceDate: over.invoiceDate ?? new Date('2026-08-01T10:00:00.000Z'),
    items: over.items ?? [item()],
    igstAmount: D(over.igst ?? 0),
    cgstAmount: D(over.cgst ?? 0),
    sgstAmount: D(over.sgst ?? 0),
    cessAmount: D(over.cess ?? 0),
  };
}

const REGISTERED = {
  shopGstin: '23AAAAA0000A1Z5',
  registrationType: 'REGULAR' as const,
  gstEffectiveFrom: null,
};
const UNREGISTERED = {
  shopGstin: null,
  registrationType: 'UNREGISTERED' as const,
  gstEffectiveFrom: null,
};

describe('invoiceGstVisibility', () => {
  it('prints GST for a registered shop', () => {
    expect(invoiceGstVisibility(invoice(), REGISTERED).showGst).toBe(true);
  });

  it('hides GST for an unregistered shop that charged none', () => {
    const inv = invoice({ items: [item({ taxPercent: 0 })] });
    expect(invoiceGstVisibility(inv, UNREGISTERED).showGst).toBe(false);
  });

  it('hides GST when the shop row is missing entirely', () => {
    const inv = invoice({ items: [item({ taxPercent: 0 })] });
    expect(invoiceGstVisibility(inv, null).showGst).toBe(false);
  });

  it('hides GST for a composition dealer', () => {
    const inv = invoice({ items: [item({ taxPercent: 0 })] });
    const composition = { ...REGISTERED, registrationType: 'COMPOSITION' as const };
    expect(invoiceGstVisibility(inv, composition).showGst).toBe(false);
  });

  it('hides GST on a sale dated before the shop became liable', () => {
    const inv = invoice({
      invoiceDate: new Date('2026-07-01T00:00:00.000Z'),
      items: [item({ taxPercent: 0 })],
    });
    const owner = { ...REGISTERED, gstEffectiveFrom: new Date('2026-08-01T00:00:00.000Z') };
    expect(invoiceGstVisibility(inv, owner).showGst).toBe(false);
  });

  it('prints GST on a sale dated on the effective date itself', () => {
    const inv = invoice({ invoiceDate: new Date('2026-08-01T18:30:00.000Z') });
    const owner = { ...REGISTERED, gstEffectiveFrom: new Date('2026-08-01T00:00:00.000Z') };
    expect(invoiceGstVisibility(inv, owner).showGst).toBe(true);
  });

  it('still prints GST when the gate says no but the invoice recorded tax', () => {
    const inv = invoice({
      invoiceDate: new Date('2026-07-01T00:00:00.000Z'),
      items: [item({ taxPercent: 5 })],
      cgst: 44.95,
      sgst: 44.95,
    });
    const owner = { ...REGISTERED, gstEffectiveFrom: new Date('2026-08-01T00:00:00.000Z') };
    expect(invoiceGstVisibility(inv, owner).showGst).toBe(true);
  });

  it('prints GST on a purchase carrying vendor tax even when we are unregistered', () => {
    const inv = invoice({ type: 'PURCHASE', items: [item({ taxPercent: 18 })] });
    expect(invoiceGstVisibility(inv, UNREGISTERED).showGst).toBe(true);
  });

  it('hides GST on a purchase from an unregistered vendor', () => {
    const inv = invoice({ type: 'PURCHASE', items: [item({ taxPercent: 0 })] });
    expect(invoiceGstVisibility(inv, REGISTERED).showGst).toBe(false);
  });

  it('hides HSN when no line carries a code (null or blank)', () => {
    const inv = invoice({ items: [item({ hsn: null }), item({ hsn: '   ' })] });
    expect(invoiceGstVisibility(inv, REGISTERED).showHsn).toBe(false);
  });

  it('shows HSN when at least one line carries a code', () => {
    const inv = invoice({ items: [item({ hsn: null }), item({ hsn: '6204' })] });
    expect(invoiceGstVisibility(inv, REGISTERED).showHsn).toBe(true);
  });
});

describe('buildPdfColumns', () => {
  const cols = (showHsn: boolean, showGst: boolean) =>
    buildPdfColumns<{ name: string; hsn: string; gst: string; total: string }>(515, [
      { header: 'Sr', width: 22, align: 'left', cell: (_r, i) => String(i + 1) },
      { header: 'Item', width: 366, align: 'left', flex: true, cell: (r) => r.name },
      { header: 'HSN', width: 40, align: 'left', show: showHsn, cell: (r) => r.hsn },
      { header: 'GST%', width: 30, align: 'right', show: showGst, cell: (r) => r.gst },
      { header: 'Total', width: 57, align: 'right', cell: (r) => r.total },
    ]);
  const row = { name: 'Kurti', hsn: '6204', gst: '5%', total: '100.00' };

  it('keeps every column when nothing is hidden', () => {
    const c = cols(true, true);
    expect(c.headers).toEqual(['Sr', 'Item', 'HSN', 'GST%', 'Total']);
    expect(c.row(row, 0)).toEqual(['1', 'Kurti', '6204', '5%', '100.00']);
  });

  it('omits hidden columns from headers, widths and cells alike', () => {
    const c = cols(false, false);
    expect(c.headers).toEqual(['Sr', 'Item', 'Total']);
    expect(c.widths).toHaveLength(3);
    expect(c.row(row, 0)).toEqual(['1', 'Kurti', '100.00']);
  });

  it('re-sums kept widths to the declared total in every combination', () => {
    for (const [hsn, gst] of [
      [true, true],
      [true, false],
      [false, true],
      [false, false],
    ] as const) {
      const c = cols(hsn, gst);
      expect(c.widths.reduce((a, b) => a + b, 0)).toBe(515);
    }
  });

  it('hands the freed width to the flex column', () => {
    expect(cols(false, false).widths[1]).toBe(366 + 40 + 30);
  });

  it('keeps alignment paired with the surviving columns', () => {
    const c = cols(false, false);
    expect([c.align(0), c.align(1), c.align(2)]).toEqual(['left', 'left', 'right']);
  });

  it('sizes correctly when two declared columns are mutually exclusive', () => {
    const built = buildPdfColumns<{ v: string }>(100, [
      { header: 'Item', width: 40, align: 'left', flex: true, cell: (r) => r.v },
      { header: 'IGST', width: 60, align: 'right', show: false, cell: (r) => r.v },
      { header: 'CGST', width: 30, align: 'right', show: true, cell: (r) => r.v },
      { header: 'SGST', width: 30, align: 'right', show: true, cell: (r) => r.v },
    ]);
    expect(built.headers).toEqual(['Item', 'CGST', 'SGST']);
    expect(built.widths).toEqual([40, 30, 30]);
  });
});
