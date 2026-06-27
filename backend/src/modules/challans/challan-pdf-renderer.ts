import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import prisma from '../../infra/db/prisma.js';
import {
  stateNameFromCode,
  isInterstateSupply,
  isValidStateCode,
} from '../../shared/validation/indian.js';

/// Render one delivery challan as a PDF — to a stream when `out` is set, or to a
/// Buffer otherwise. Returns `{ error }` when the challan can't be found for
/// `shopId`.
///
/// LAW: CGST Rule 55(1) — a delivery challan must carry the consignor and
/// consignee identity (with GSTIN where registered), HSN + description, quantity,
/// taxable value, the tax RATE and tax AMOUNT broken into CGST/SGST/IGST (+cess),
/// the place of supply for an inter-State movement, and a signature. The bare
/// pack-slip the challan used to print omitted all of the tax fields. The tax
/// figures here are computed at render time from the product master at the SAME
/// (exclusive) convention `convertToInvoice` uses, so the challan and the tax
/// invoice eventually raised from it reconcile. Interstate is derived from the
/// consignor's state vs the consignee's (the place of supply).
export async function renderChallanPdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  const challan = await prisma.challan.findFirst({
    where: { id, shopId },
    include: {
      items: { orderBy: { id: 'asc' } },
      party: {
        select: {
          name: true,
          address: true,
          city: true,
          state: true,
          stateCode: true,
          pinCode: true,
          gstin: true,
          panNumber: true,
        },
      },
    },
  });
  if (!challan) return { error: 'Challan not found' };

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
          registrationType: true,
          name: true,
        },
      },
    },
  });
  const owner = shopRow?.owner ?? null;

  // Per-line tax source — the challan stores only product/qty, so HSN, price and
  // GST/cess rate come from the current product master (the same source
  // convertToInvoice prices from).
  const productIds = [...new Set(challan.items.map((i) => i.productId))];
  const products = productIds.length
    ? await prisma.product.findMany({
        where: { id: { in: productIds }, shopId },
        select: { id: true, hsnCode: true, sellingPrice: true, taxPercent: true, cessRate: true },
      })
    : [];
  const productMap = new Map(products.map((p) => [p.id, p]));

  // Consignor (shop) state — explicit code, else derived from the shop GSTIN.
  const shopStateCode =
    owner?.shopStateCode ?? (owner?.shopGstin ? owner.shopGstin.slice(0, 2) : null);
  // Consignee (party) state = place of supply. Explicit code, else the party's
  // GSTIN prefix (mirrors the invoice engine's B2B fallback).
  let partyStateCode = challan.party?.stateCode ?? null;
  if (!partyStateCode && challan.party?.gstin) {
    const prefix = challan.party.gstin.slice(0, 2);
    if (isValidStateCode(prefix)) partyStateCode = prefix;
  }
  const isInter = isInterstateSupply(shopStateCode, partyStateCode);

  // Only a REGULAR GST-registered consignor charges/declares output tax; an
  // unregistered/composition consignor's challan carries no tax (Sec 32 gate),
  // matching the Bill of Supply such a shop would issue.
  const chargesGst = owner?.registrationType === 'REGULAR' && !!owner?.shopGstin;

  const D = Prisma.Decimal;
  const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

  type Row = {
    name: string;
    sku: string;
    hsn: string;
    qty: Prisma.Decimal;
    unit: string;
    rate: Prisma.Decimal;
    taxable: Prisma.Decimal;
    taxPct: Prisma.Decimal;
    igst: Prisma.Decimal;
    cgst: Prisma.Decimal;
    sgst: Prisma.Decimal;
    cess: Prisma.Decimal;
    total: Prisma.Decimal;
  };
  const rows: Row[] = challan.items.map((it) => {
    const p = productMap.get(it.productId);
    const qty = new D(it.quantity.toString());
    const rate = p?.sellingPrice != null ? new D(p.sellingPrice.toString()) : new D(0);
    const taxable = round2(qty.mul(rate));
    const taxPct = chargesGst && p?.taxPercent != null ? new D(p.taxPercent.toString()) : new D(0);
    const cessRate = chargesGst && p?.cessRate != null ? new D(p.cessRate.toString()) : new D(0);
    let igst = new D(0);
    let cgst = new D(0);
    let sgst = new D(0);
    if (isInter) {
      igst = round2(taxable.mul(taxPct).div(100));
    } else {
      const gst = round2(taxable.mul(taxPct).div(100));
      cgst = round2(gst.div(2));
      sgst = gst.sub(cgst);
    }
    const cess = round2(taxable.mul(cessRate).div(100));
    const total = round2(taxable.add(igst).add(cgst).add(sgst).add(cess));
    return {
      name: it.productName,
      sku: it.productSku,
      hsn: p?.hsnCode ?? '-',
      qty,
      unit: it.unit,
      rate,
      taxable,
      taxPct,
      igst,
      cgst,
      sgst,
      cess,
      total,
    };
  });

  const sum = (pick: (r: Row) => Prisma.Decimal) =>
    rows.reduce((s, r) => s.add(pick(r)), new D(0));
  const totTaxable = round2(sum((r) => r.taxable));
  const totIgst = round2(sum((r) => r.igst));
  const totCgst = round2(sum((r) => r.cgst));
  const totSgst = round2(sum((r) => r.sgst));
  const totCess = round2(sum((r) => r.cess));
  const grandTotal = round2(sum((r) => r.total));

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
    const numFmt = (n: Prisma.Decimal): string => n.toFixed(2);
    const money = (n: Prisma.Decimal): string => `Rs. ${n.toFixed(2)}`;

    try {
      // ---------- Title ----------
      doc
        .fillColor('#111827')
        .font('Helvetica-Bold')
        .fontSize(18)
        .text('DELIVERY CHALLAN', LEFT, 40, { width: W, align: 'center' });
      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#6B7280')
        .text('Rule 55, CGST Rules 2017', LEFT, 62, { width: W, align: 'center' });
      doc.moveTo(LEFT, 78).lineTo(RIGHT, 78).strokeColor('#9CA3AF').lineWidth(1).stroke();

      // ---------- Consignor (left) + Consignee (right) ----------
      const blocksY = 88;
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
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(8).text('Consignor', leftX, blocksY, { width: colW });
      let lY = doc.y + 2;
      doc.font('Helvetica-Bold').fontSize(11).fillColor('#111827').text(shopName, leftX, lY, { width: colW });
      lY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      if (shopAddr) { doc.text(shopAddr, leftX, lY, { width: colW }); lY = doc.y; }
      if (owner?.shopGstin) { doc.text(`GSTIN: ${owner.shopGstin}`, leftX, lY, { width: colW }); lY = doc.y; }
      if (owner?.shopPan) { doc.text(`PAN: ${owner.shopPan}`, leftX, lY, { width: colW }); lY = doc.y; }
      const shopBottom = lY;

      const party = challan.party;
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(8).text('Consignee', rightX, blocksY, { width: colW });
      let rY = doc.y + 2;
      doc.font('Helvetica-Bold').fontSize(11).fillColor('#111827').text(party?.name ?? challan.partyName ?? '-', rightX, rY, { width: colW });
      rY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      const cpAddr = composeAddress(party?.address, party?.city, party?.state, party?.pinCode);
      if (cpAddr) { doc.text(cpAddr, rightX, rY, { width: colW }); rY = doc.y; }
      if (party?.gstin) { doc.text(`GSTIN: ${party.gstin}`, rightX, rY, { width: colW }); rY = doc.y; }
      if (party?.panNumber) { doc.text(`PAN: ${party.panNumber}`, rightX, rY, { width: colW }); rY = doc.y; }
      else if (challan.partyPhone) { doc.text(challan.partyPhone, rightX, rY, { width: colW }); rY = doc.y; }
      const cpBottom = rY;

      // ---------- Meta strip ----------
      let y = Math.max(shopBottom, cpBottom) + 12;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 6;

      const posName = stateNameFromCode(partyStateCode);
      const pos = partyStateCode
        ? `${partyStateCode}${posName ? ` - ${posName}` : ''}`
        : '-';
      const metaW = W / 4;
      const metaY = y;
      const drawMeta = (label: string, value: string, idx: number) => {
        const x = LEFT + idx * metaW;
        doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, metaY, { width: metaW - 6 });
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, metaY + 9, { width: metaW - 6 });
      };
      drawMeta('Challan No', challan.challanNo, 0);
      drawMeta('Date', formatDDMMYYYY(challan.createdAt), 1);
      drawMeta('Place of Supply', pos, 2);
      drawMeta('Supply Type', isInter ? 'Inter-State' : 'Intra-State', 3);
      y = metaY + 28;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 10;

      // ---------- Items table ----------
      const taxCols = isInter ? ['IGST'] : ['CGST', 'SGST'];
      const headers = ['Sr', 'Item / SKU', 'HSN', 'Qty', 'Rate', 'Taxable', 'GST%', ...taxCols, 'Total'];
      const widths: number[] = isInter
        ? [22, 132, 46, 44, 50, 56, 33, 66, 66]
        : [22, 120, 44, 40, 46, 52, 31, 53, 53, 54];
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }
      const align = (i: number): 'left' | 'right' => (i <= 2 ? 'left' : 'right');

      const paintHeader = () => {
        doc.rect(LEFT, y, W, 18).fill('#F3F4F6');
        doc.fillColor('#111827').font('Helvetica-Bold').fontSize(7.5);
        headers.forEach((h, i) => doc.text(h, xs[i] + 2, y + 5, { width: widths[i] - 4, align: align(i) }));
        y += 18;
        doc.font('Helvetica').fontSize(8);
      };
      paintHeader();

      let sr = 1;
      for (const r of rows) {
        const rowH = 28;
        if (y + rowH > 720) { doc.addPage(); y = 40; paintHeader(); }
        doc.fillColor('#111827');
        const taxValues = isInter ? [numFmt(r.igst)] : [numFmt(r.cgst), numFmt(r.sgst)];
        const cells = [
          String(sr),
          `${r.name}\n${r.sku}`,
          r.hsn,
          `${r.qty.toString()} ${r.unit}`,
          numFmt(r.rate),
          numFmt(r.taxable),
          `${r.taxPct.toString()}%`,
          ...taxValues,
          numFmt(r.total),
        ];
        cells.forEach((c, i) => doc.text(c, xs[i] + 2, y + 4, { width: widths[i] - 4, align: align(i) }));
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
      totRow('Taxable Value', money(totTaxable));
      if (isInter) {
        if (totIgst.gt(0)) totRow('IGST', money(totIgst));
      } else {
        if (totCgst.gt(0)) totRow('CGST', money(totCgst));
        if (totSgst.gt(0)) totRow('SGST', money(totSgst));
      }
      if (totCess.gt(0)) totRow('Cess', money(totCess));
      doc.moveTo(totalsX, y).lineTo(totalsX + totalsW, y).strokeColor('#9CA3AF').stroke();
      y += 4;
      totRow('Total Value of Goods', money(grandTotal), true);

      // ---------- Declaration ----------
      y += 8;
      if (y + 24 > 760) { doc.addPage(); y = 40; }
      doc
        .font('Helvetica-Oblique')
        .fontSize(8)
        .fillColor('#6B7280')
        .text(
          chargesGst
            ? 'Delivery challan issued under Rule 55 of the CGST Rules. Not a tax '
              + 'invoice — goods are dispatched against this challan; the tax invoice '
              + 'follows on supply.'
            : 'Delivery challan issued under Rule 55 of the CGST Rules. The consignor '
              + 'is not registered to collect GST, so no tax is charged on this document.',
          LEFT,
          y,
          { width: W },
        );
      y = doc.y + 6;

      if (challan.note) {
        if (y + 30 > 760) { doc.addPage(); y = 40; }
        doc.font('Helvetica-Bold').fontSize(8).fillColor('#111827').text('Notes', LEFT, y);
        doc.font('Helvetica').fontSize(8).fillColor('#374151').text(challan.note, LEFT, y + 12, { width: W });
        y = doc.y + 6;
      }

      // ---------- Signature (Rule 55(viii)) ----------
      {
        const sigW = 200;
        const sigX = RIGHT - sigW;
        let sigY = y + 10;
        if (sigY + 60 > 790) { doc.addPage(); sigY = 40; }
        doc
          .font('Helvetica-Bold')
          .fontSize(9)
          .fillColor('#111827')
          .text(`For ${shopName}`, sigX, sigY, { width: sigW, align: 'right' });
        const lineY = sigY + 40;
        doc.moveTo(sigX, lineY).lineTo(RIGHT, lineY).strokeColor('#9CA3AF').lineWidth(0.7).stroke();
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#374151')
          .text('Authorised Signatory', sigX, lineY + 4, { width: sigW, align: 'right' });
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
