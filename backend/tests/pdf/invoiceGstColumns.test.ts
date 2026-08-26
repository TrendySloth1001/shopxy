import { describe, it, expect, afterAll } from 'vitest';
import zlib from 'node:zlib';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { renderInvoicePdf } from '../../src/modules/invoices/invoice-pdf-renderer.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

function pdfText(buf: Buffer): string {
  let streams = '';
  let i = 0;
  while ((i = buf.indexOf('stream', i)) !== -1) {
    let s = i + 6;
    if (buf[s] === 0x0d) s++;
    if (buf[s] === 0x0a) s++;
    const end = buf.indexOf('endstream', s);
    if (end === -1) break;
    try {
      streams += zlib.inflateSync(buf.subarray(s, end)).toString('latin1');
    } catch {
    }
    i = end + 9;
  }
  let text = '';
  for (const m of streams.matchAll(/<([0-9A-Fa-f]+)>/g)) {
    if (m[1].length % 2 === 0) text += Buffer.from(m[1], 'hex').toString('latin1');
  }
  return text.toUpperCase();
}

const GST_MARKERS = ['HSN', 'CGST', 'SGST', 'IGST', 'TAXABLE', 'GST%', 'PLACE OF SUPPLY'];

async function renderToBuffer(shopId: number, invoiceId: number): Promise<Buffer> {
  const out = await renderInvoicePdf(shopId, invoiceId, null);
  expect(Buffer.isBuffer(out)).toBe(true);
  return out as Buffer;
}

describe('invoice PDF — GST/HSN columns are omitted, not blank-filled', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('prints no GST or HSN anywhere for an unregistered shop selling an HSN-less product', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 140 });
      await prisma.product.update({ where: { id: product.id }, data: { hsnCode: null } });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Ravi Verma' },
      });
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 140, taxPercent: 0 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      const text = pdfText(await renderToBuffer(ctx.shopId, result.invoice.id));
      expect(text).toContain('BILL TO');
      expect(text).toContain('RAVI VERMA');
      expect(text).toContain('280.00');
      for (const marker of GST_MARKERS) {
        expect(text, `"${marker}" leaked onto a non-GST invoice`).not.toContain(marker);
      }
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('still prints every GST and HSN column for a registered shop', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({ where: { id: product.id }, data: { hsnCode: '6204' } });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Riya Sharma' },
      });
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18, hsn: '6204' }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      const text = pdfText(await renderToBuffer(ctx.shopId, result.invoice.id));
      for (const marker of GST_MARKERS.filter((m) => m !== 'IGST')) {
        expect(text, `"${marker}" missing from a GST invoice`).toContain(marker);
      }
      expect(text).not.toContain('IGST');
      expect(text).toContain('HSN SUMMARY');
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
