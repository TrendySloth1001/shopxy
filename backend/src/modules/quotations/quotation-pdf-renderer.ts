import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import prisma from '../../infra/db/prisma.js';
import { stateNameFromCode } from '../../shared/validation/indian.js';

/// One stored quotation line (the JSON shape priceItems writes).
interface QuoteLine {
  name?: string;
  sku?: string | null;
  quantity?: number;
  unitPrice?: number;
  taxPercent?: number;
  discount?: number;
  lineTotal?: number;
}

/// Render one quotation as a clean, text-only PDF — to a stream when `out` is
/// set, or to a Buffer otherwise. Returns `{ error }` when the quotation can't
/// be found for `shopId`. Sibling of [renderInvoicePdf]; deliberately simpler —
/// a quotation is an offer, not a tax document (no HSN summary, no UPI QR).
export async function renderQuotationPdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  const quotation = await prisma.quotation.findFirst({
    where: { id, shopId },
    select: {
      quotationNo: true,
      status: true,
      items: true,
      subtotal: true,
      taxAmount: true,
      total: true,
      note: true,
      placeOfSupplyStateCode: true,
      createdAt: true,
      party: {
        select: {
          name: true,
          address: true,
          city: true,
          state: true,
          pinCode: true,
          gstin: true,
          panNumber: true,
        },
      },
    },
  });
  if (!quotation) return { error: 'Quotation not found' };

  const shopRow = await prisma.shop.findUnique({
    where: { id: shopId },
    select: {
      owner: {
        select: {
          shopName: true,
          shopAddress: true,
          shopCity: true,
          shopState: true,
          shopPinCode: true,
          shopGstin: true,
          shopPan: true,
          name: true,
        },
      },
    },
  });
  const owner = shopRow?.owner ?? null;

  const lines = (quotation.items as unknown as QuoteLine[]) ?? [];
  const num = (n: number | null | undefined): string => (n ?? 0).toFixed(2);
  const money = (n: Prisma.Decimal | number | string | null | undefined): string =>
    `Rs. ${Number((n ?? 0).toString()).toFixed(2)}`;

  return new Promise<Buffer | null>((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const chunks: Buffer[] | null = out ? null : [];
    let settled = false;
    const cleanup = () => {
      const anyDoc = doc as unknown as { destroy?: () => void };
      try {
        if (typeof anyDoc.destroy === 'function') anyDoc.destroy();
        else doc.end();
      } catch {
        // best-effort
      }
    };
    if (out) {
      if (onReady) {
        try {
          onReady();
        } catch (err) {
          settled = true;
          reject(err);
          return;
        }
      }
      doc.pipe(out);
      out.on('finish', () => {
        if (settled) return;
        settled = true;
        resolve(null);
      });
      out.on('error', (err) => {
        if (settled) return;
        settled = true;
        cleanup();
        reject(err);
      });
    } else {
      doc.on('data', (c: Buffer) => chunks!.push(c));
      doc.on('end', () => {
        if (settled) return;
        settled = true;
        resolve(Buffer.concat(chunks!));
      });
    }
    doc.on('error', (err) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(err);
    });

    const W = 515;
    const LEFT = 40;
    const RIGHT = 555;

    try {
      // ---------- Title ----------
      doc
        .fillColor('#111827')
        .font('Helvetica-Bold')
        .fontSize(18)
        .text('QUOTATION', LEFT, 40, { width: W, align: 'center' });
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#6B7280')
        .text(statusLabel(quotation.status), LEFT, 62, {
          width: W,
          align: 'center',
        });

      doc.moveTo(LEFT, 80).lineTo(RIGHT, 80).strokeColor('#9CA3AF').lineWidth(1).stroke();

      // ---------- Shop (left) + Bill To (right) ----------
      const blocksY = 90;
      const colW = (W - 20) / 2;
      const leftX = LEFT;
      const rightX = LEFT + colW + 20;

      const shopName = owner?.shopName ?? owner?.name ?? 'Shop';
      const shopAddr = composeAddress(
        owner?.shopAddress,
        owner?.shopCity,
        owner?.shopState,
        owner?.shopPinCode,
      );
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(11).text(shopName, leftX, blocksY, { width: colW });
      let lY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      if (shopAddr) { doc.text(shopAddr, leftX, lY, { width: colW }); lY = doc.y; }
      if (owner?.shopGstin) { doc.text(`GSTIN: ${owner.shopGstin}`, leftX, lY, { width: colW }); lY = doc.y; }
      if (owner?.shopPan) { doc.text(`PAN: ${owner.shopPan}`, leftX, lY, { width: colW }); lY = doc.y; }
      const shopBottom = lY;

      const party = quotation.party;
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(9).text('Quote For', rightX, blocksY, { width: colW });
      let rY = doc.y + 2;
      doc.font('Helvetica-Bold').fontSize(11).fillColor('#111827').text(party?.name ?? '-', rightX, rY, { width: colW });
      rY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      const cpAddr = composeAddress(party?.address, party?.city, party?.state, party?.pinCode);
      if (cpAddr) { doc.text(cpAddr, rightX, rY, { width: colW }); rY = doc.y; }
      if (party?.gstin) { doc.text(`GSTIN: ${party.gstin}`, rightX, rY, { width: colW }); rY = doc.y; }
      if (party?.panNumber) { doc.text(`PAN: ${party.panNumber}`, rightX, rY, { width: colW }); rY = doc.y; }
      const cpBottom = rY;

      // ---------- Meta strip ----------
      let y = Math.max(shopBottom, cpBottom) + 12;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 6;

      const posName = stateNameFromCode(quotation.placeOfSupplyStateCode);
      const pos = quotation.placeOfSupplyStateCode
        ? `${quotation.placeOfSupplyStateCode}${posName ? ` - ${posName}` : ''}`
        : '-';
      const metaW = W / 3;
      const metaY = y;
      const drawMeta = (label: string, value: string, idx: number) => {
        const x = LEFT + idx * metaW;
        doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, metaY, { width: metaW - 6 });
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, metaY + 9, { width: metaW - 6 });
      };
      drawMeta('Quotation No', quotation.quotationNo, 0);
      drawMeta('Date', formatDDMMYYYY(quotation.createdAt), 1);
      drawMeta('Place of Supply', pos, 2);
      y = metaY + 28;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 10;

      // ---------- Items table ----------
      // Sr | Item / SKU | Qty | Rate | Disc | Taxable | GST% | Amount
      const headers = ['Sr', 'Item / SKU', 'Qty', 'Rate', 'Disc', 'Taxable', 'GST%', 'Amount'];
      const widths = [24, 191, 40, 56, 44, 60, 36, 64];
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }
      const align = (i: number): 'left' | 'right' => (i <= 1 ? 'left' : 'right');

      const paintHeader = () => {
        doc.rect(LEFT, y, W, 18).fill('#F3F4F6');
        doc.fillColor('#111827').font('Helvetica-Bold').fontSize(7.5);
        headers.forEach((h, i) => doc.text(h, xs[i] + 2, y + 5, { width: widths[i] - 4, align: align(i) }));
        y += 18;
        doc.font('Helvetica').fontSize(8);
      };
      paintHeader();

      let sr = 1;
      for (const it of lines) {
        const rowH = 26;
        if (y + rowH > 720) { doc.addPage(); y = 40; paintHeader(); }
        doc.fillColor('#111827');
        const qty = it.quantity ?? 0;
        const unit = it.unitPrice ?? 0;
        const disc = it.discount ?? 0;
        const taxable = Math.max(0, qty * unit - disc);
        const row = [
          String(sr),
          `${it.name ?? 'Item'}${it.sku ? `\n${it.sku}` : ''}`,
          qty % 1 === 0 ? String(qty) : qty.toFixed(2),
          num(unit),
          num(disc),
          num(taxable),
          `${it.taxPercent ?? 0}%`,
          num(it.lineTotal),
        ];
        row.forEach((c, i) => doc.text(c, xs[i] + 2, y + 4, { width: widths[i] - 4, align: align(i) }));
        doc.moveTo(LEFT, y + rowH).lineTo(RIGHT, y + rowH).strokeColor('#E5E7EB').stroke();
        y += rowH;
        sr += 1;
      }

      // ---------- Totals ----------
      y += 10;
      const totalsX = 360;
      const totalsW = RIGHT - totalsX;
      const totRow = (label: string, value: string, bold = false) => {
        if (y + 16 > 770) { doc.addPage(); y = 40; }
        doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(9).fillColor('#111827');
        doc.text(label, totalsX, y, { width: totalsW - 90 });
        doc.text(value, totalsX + (totalsW - 90), y, { width: 90, align: 'right' });
        y += 15;
      };
      totRow('Subtotal', money(quotation.subtotal));
      totRow('GST', money(quotation.taxAmount));
      doc.moveTo(totalsX, y).lineTo(totalsX + totalsW, y).strokeColor('#9CA3AF').stroke();
      y += 4;
      totRow('Total', money(quotation.total), true);

      // ---------- Validity + note ----------
      y += 8;
      if (y + 24 > 770) { doc.addPage(); y = 40; }
      doc
        .font('Helvetica-Oblique')
        .fontSize(8)
        .fillColor('#6B7280')
        .text(
          'This is a quotation, not a tax invoice. Prices are an estimate and may '
          + 'change until confirmed. Taxes are computed on acceptance.',
          LEFT,
          y,
          { width: W },
        );
      y = doc.y + 6;

      if (quotation.note) {
        if (y + 30 > 770) { doc.addPage(); y = 40; }
        doc.font('Helvetica-Bold').fontSize(8).fillColor('#111827').text('Notes', LEFT, y);
        doc.font('Helvetica').fontSize(8).fillColor('#374151').text(quotation.note, LEFT, y + 12, { width: W });
      }

      // ---------- Footer ----------
      const range = doc.bufferedPageRange();
      for (let i = 0; i < range.count; i++) {
        doc.switchToPage(range.start + i);
        doc
          .font('Helvetica')
          .fontSize(7)
          .fillColor('#6B7280')
          .text(
            `This is a computer-generated document.   Page ${i + 1} of ${range.count}`,
            LEFT,
            800,
            { width: W, align: 'center' },
          );
      }

      doc.end();
    } catch (err) {
      if (!settled) {
        settled = true;
        cleanup();
        reject(err);
      }
    }
  });
}

function statusLabel(status: string): string {
  switch (status) {
    case 'REQUESTED': return 'Requested by customer';
    case 'PENDING': return 'Awaiting acceptance';
    case 'ACCEPTED': return 'Accepted';
    case 'DECLINED': return 'Declined';
    case 'CANCELLED': return 'Cancelled';
    case 'EXPIRED': return 'Expired';
    default: return status;
  }
}

function composeAddress(
  addr: string | null | undefined,
  city: string | null | undefined,
  state: string | null | undefined,
  pin: string | null | undefined,
): string {
  const parts: string[] = [];
  if (addr && addr.length > 0) parts.push(addr);
  if (city && city.length > 0) parts.push(city);
  if (state && state.length > 0) {
    parts.push(pin && pin.length > 0 ? `${state} - ${pin}` : state);
  } else if (pin && pin.length > 0) {
    parts.push(pin);
  }
  return parts.join(', ');
}

function formatDDMMYYYY(d: Date | string): string {
  const dt = d instanceof Date ? d : new Date(d);
  const dd = String(dt.getDate()).padStart(2, '0');
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const yy = dt.getFullYear();
  return `${dd}/${mm}/${yy}`;
}
