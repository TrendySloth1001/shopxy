import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import prisma from '../../infra/db/prisma.js';
import { stateNameFromCode, isInterstateSupply } from '../../shared/validation/indian.js';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';

/// One stored quotation line (the JSON shape priceItems writes).
interface QuoteLine {
  name?: string;
  sku?: string | null;
  quantity?: number;
  unitPrice?: number;
  taxPercent?: number;
  cessRate?: number;
  discount?: number;
  lineTotal?: number;
}

/// Render one quotation as a PDF — to a stream when `out` is set, or to a
/// Buffer otherwise. Returns `{ error }` when the quotation can't be found
/// for `shopId`. Dispatches to the react-pdf engine by default; set
/// `PDF_ENGINE=pdfkit` to roll back to the original layout below.
export async function renderQuotationPdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  if (process.env.PDF_ENGINE === 'pdfkit') {
    return renderQuotationPdfPdfKit(shopId, id, out, onReady);
  }
  return renderQuotationPdfReactPdf(shopId, id, out, onReady);
}

/// The original hand-drawn PDFKit layout — kept verbatim as the rollback path.
async function renderQuotationPdfPdfKit(
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
          shopStateCode: true,
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
      // GST-11 — even on a (non-statutory) quotation, label the tax by the
      // correct head so a B2B recipient sees the split they'll be billed under.
      // Interstate is derived from the shop's state vs the quote's place of
      // supply; the stored `taxAmount` is the same total either way, so we
      // split it for display (CGST = half rounded to the paisa, SGST absorbs
      // the remainder — mirrors the invoice engine). A quote with no resolvable
      // place of supply falls back to the intrastate CGST/SGST presentation.
      const shopStateCode =
        owner?.shopStateCode ?? (owner?.shopGstin ? owner.shopGstin.slice(0, 2) : null);
      const quoteInterstate = isInterstateSupply(
        shopStateCode,
        quotation.placeOfSupplyStateCode,
      );
      // `taxAmount` bundles GST + compensation cess (priceItems sums both), so
      // recompute cess from the stored lines and back it out before splitting,
      // keeping cess out of the CGST/SGST/IGST heads. CGST + SGST + Cess then
      // re-sum to the stored taxAmount exactly (gst = taxAmount − cess).
      const D = Prisma.Decimal;
      const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
      const taxTotal = new D((quotation.taxAmount ?? 0).toString());
      let cessTotal = new D(0);
      for (const it of lines) {
        const qty = new D((it.quantity ?? 0).toString());
        const unit = new D((it.unitPrice ?? 0).toString());
        const disc = new D((it.discount ?? 0).toString());
        const taxable = qty.mul(unit).sub(disc);
        const lineTaxable = taxable.gt(0) ? taxable : new D(0);
        cessTotal = cessTotal.add(round2(lineTaxable.mul(new D((it.cessRate ?? 0).toString())).div(100)));
      }
      const gstTotal = taxTotal.sub(cessTotal);
      totRow('Subtotal', money(quotation.subtotal));
      if (quoteInterstate) {
        totRow('IGST', money(gstTotal));
      } else {
        const cgst = round2(gstTotal.div(2));
        const sgst = gstTotal.sub(cgst);
        totRow('CGST', money(cgst));
        totRow('SGST', money(sgst));
      }
      if (cessTotal.gt(0)) totRow('Cess', money(cessTotal));
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

/// Converts PDFKit-style absolute point widths into percentages summing to
/// 100 — see the identical helper in `invoice-pdf-renderer.ts`.
function pct(points: number[]): number[] {
  const total = points.reduce((a, b) => a + b, 0);
  return points.map((p) => (p / total) * 100);
}

async function renderQuotationPdfReactPdf(
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
      pdfTemplateId: true,
      owner: {
        select: {
          shopName: true,
          shopAddress: true,
          shopCity: true,
          shopState: true,
          shopStateCode: true,
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

  const itemHeaders = ['Sr', 'Item / SKU', 'Qty', 'Rate', 'Disc', 'Taxable', 'GST%', 'Amount'];
  const itemWidths = pct([24, 191, 40, 56, 44, 60, 36, 64]);
  const align = (i: number): 'left' | 'right' => (i <= 1 ? 'left' : 'right');
  const itemRows = lines.map((it, idx) => {
    const qty = it.quantity ?? 0;
    const unit = it.unitPrice ?? 0;
    const disc = it.discount ?? 0;
    const taxable = Math.max(0, qty * unit - disc);
    const cells = [
      String(idx + 1),
      `${it.name ?? 'Item'}${it.sku ? `\n${it.sku}` : ''}`,
      qty % 1 === 0 ? String(qty) : qty.toFixed(2),
      num(unit),
      num(disc),
      num(taxable),
      `${it.taxPercent ?? 0}%`,
      num(it.lineTotal),
    ];
    return { cells: cells.map((text, i) => ({ text, align: align(i) })) };
  });

  const shopStateCode = owner?.shopStateCode ?? (owner?.shopGstin ? owner.shopGstin.slice(0, 2) : null);
  const quoteInterstate = isInterstateSupply(shopStateCode, quotation.placeOfSupplyStateCode);
  const D = Prisma.Decimal;
  const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
  const taxTotal = new D((quotation.taxAmount ?? 0).toString());
  let cessTotal = new D(0);
  for (const it of lines) {
    const qty = new D((it.quantity ?? 0).toString());
    const unit = new D((it.unitPrice ?? 0).toString());
    const disc = new D((it.discount ?? 0).toString());
    const taxable = qty.mul(unit).sub(disc);
    const lineTaxable = taxable.gt(0) ? taxable : new D(0);
    cessTotal = cessTotal.add(round2(lineTaxable.mul(new D((it.cessRate ?? 0).toString())).div(100)));
  }
  const gstTotal = taxTotal.sub(cessTotal);

  const totals: { label: string; value: string; bold?: boolean }[] = [
    { label: 'Subtotal', value: money(quotation.subtotal) },
  ];
  if (quoteInterstate) {
    totals.push({ label: 'IGST', value: money(gstTotal) });
  } else {
    const cgst = round2(gstTotal.div(2));
    const sgst = gstTotal.sub(cgst);
    totals.push({ label: 'CGST', value: money(cgst) });
    totals.push({ label: 'SGST', value: money(sgst) });
  }
  if (cessTotal.gt(0)) totals.push({ label: 'Cess', value: money(cessTotal) });
  totals.push({ label: 'Total', value: money(quotation.total), bold: true });

  const posName = stateNameFromCode(quotation.placeOfSupplyStateCode);
  const pos = quotation.placeOfSupplyStateCode
    ? `${quotation.placeOfSupplyStateCode}${posName ? ` - ${posName}` : ''}`
    : '-';

  const party = quotation.party;
  const model = {
    kind: 'quotation' as const,
    title: 'QUOTATION',
    titleBadgeLines: [statusLabel(quotation.status)],
    shop: {
      name: owner?.shopName ?? owner?.name ?? 'Shop',
      addressLine: composeAddress(owner?.shopAddress, owner?.shopCity, owner?.shopState, owner?.shopPinCode),
      gstin: owner?.shopGstin,
      pan: owner?.shopPan,
    },
    counterpartyLabel: 'Quote For',
    counterparty: {
      name: party?.name ?? '-',
      addressLine: composeAddress(party?.address, party?.city, party?.state, party?.pinCode),
      gstin: party?.gstin,
      pan: party?.panNumber,
    },
    meta: [
      { label: 'Quotation No', value: quotation.quotationNo },
      { label: 'Date', value: formatDDMMYYYY(quotation.createdAt) },
      { label: 'Place of Supply', value: pos },
    ],
    items: { headers: itemHeaders.map((text, i) => ({ text, align: align(i) })), widths: itemWidths, rows: itemRows },
    totals,
    declaration:
      'This is a quotation, not a tax invoice. Prices are an estimate and may change until confirmed. Taxes are computed on acceptance.',
    note: quotation.note ?? undefined,
  };

  const engine = await loadPdfEngine();
  if (out) {
    await engine.renderPdfToStream(model, shopRow?.pdfTemplateId, out, onReady);
    return null;
  }
  return engine.renderPdfToBuffer(model, shopRow?.pdfTemplateId);
}
