import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import prisma from '../../infra/db/prisma.js';
import {
  stateNameFromCode,
  isInterstateSupply,
  isValidStateCode,
} from '../../shared/validation/indian.js';
import { isOutputGstRegistered } from '../invoices/gst-registration-gate.js';
import { buildPdfColumns } from '../../shared/pdfColumns.js';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';

export interface ChallanLineTax {
  taxable: Prisma.Decimal;
  taxPct: Prisma.Decimal;
  igst: Prisma.Decimal;
  cgst: Prisma.Decimal;
  sgst: Prisma.Decimal;
  cess: Prisma.Decimal;
  total: Prisma.Decimal;
}

export function computeChallanLineTax(input: {
  quantity: Prisma.Decimal | number | string;
  sellingPrice: Prisma.Decimal | number | string | null | undefined;
  taxPercent: Prisma.Decimal | number | string | null | undefined;
  cessRate: Prisma.Decimal | number | string | null | undefined;
  isInterstate: boolean;
  chargesGst: boolean;
}): ChallanLineTax {
  const D = Prisma.Decimal;
  const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
  const qty = new D((input.quantity ?? 0).toString());
  const rate = input.sellingPrice != null ? new D(input.sellingPrice.toString()) : new D(0);
  const taxable = round2(qty.mul(rate));
  const taxPct =
    input.chargesGst && input.taxPercent != null ? new D(input.taxPercent.toString()) : new D(0);
  const cessRate =
    input.chargesGst && input.cessRate != null ? new D(input.cessRate.toString()) : new D(0);
  let igst = new D(0);
  let cgst = new D(0);
  let sgst = new D(0);
  if (input.isInterstate) {
    igst = round2(taxable.mul(taxPct).div(100));
  } else {
    const gst = round2(taxable.mul(taxPct).div(100));
    cgst = round2(gst.div(2));
    sgst = gst.sub(cgst);
  }
  const cess = round2(taxable.mul(cessRate).div(100));
  const total = round2(taxable.add(igst).add(cgst).add(sgst).add(cess));
  return { taxable, taxPct, igst, cgst, sgst, cess, total };
}

export async function renderChallanPdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  if (process.env.PDF_ENGINE === 'pdfkit') {
    return renderChallanPdfPdfKit(shopId, id, out, onReady);
  }
  return renderChallanPdfReactPdf(shopId, id, out, onReady);
}

async function renderChallanPdfPdfKit(
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
          gstEffectiveFrom: true,
          name: true,
        },
      },
    },
  });
  const owner = shopRow?.owner ?? null;

  const productIds = [...new Set(challan.items.map((i) => i.productId))];
  const products = productIds.length
    ? await prisma.product.findMany({
        where: { id: { in: productIds }, shopId },
        select: { id: true, hsnCode: true, sellingPrice: true, taxPercent: true, cessRate: true },
      })
    : [];
  const productMap = new Map(products.map((p) => [p.id, p]));

  const shopStateCode =
    owner?.shopStateCode ?? (owner?.shopGstin ? owner.shopGstin.slice(0, 2) : null);
  let partyStateCode = challan.party?.stateCode ?? null;
  if (!partyStateCode && challan.party?.gstin) {
    const prefix = challan.party.gstin.slice(0, 2);
    if (isValidStateCode(prefix)) partyStateCode = prefix;
  }
  const isInter = isInterstateSupply(shopStateCode, partyStateCode);

  const chargesGst = owner ? isOutputGstRegistered(owner, challan.createdAt) : false;

  const D = Prisma.Decimal;
  const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

  type Row = {
    name: string;
    sku: string;
    hsn: string;
    qty: Prisma.Decimal;
    unit: string;
    rate: Prisma.Decimal;
  } & ChallanLineTax;
  const rows: Row[] = challan.items.map((it) => {
    const p = productMap.get(it.productId);
    const tax = computeChallanLineTax({
      quantity: it.quantity,
      sellingPrice: p?.sellingPrice,
      taxPercent: p?.taxPercent,
      cessRate: p?.cessRate,
      isInterstate: isInter,
      chargesGst,
    });
    return {
      name: it.productName,
      sku: it.productSku,
      hsn: p?.hsnCode ?? '',
      qty: new D(it.quantity.toString()),
      unit: it.unit,
      rate: p?.sellingPrice != null ? new D(p.sellingPrice.toString()) : new D(0),
      ...tax,
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

  const showGst =
    chargesGst || totIgst.gt(0) || totCgst.gt(0) || totSgst.gt(0) || totCess.gt(0);
  const showHsn = rows.some((r) => r.hsn.trim().length > 0);

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

      let y = Math.max(shopBottom, cpBottom) + 12;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 6;

      const posName = stateNameFromCode(partyStateCode);
      const pos = partyStateCode
        ? `${partyStateCode}${posName ? ` - ${posName}` : ''}`
        : '-';
      const metaFields: { label: string; value: string }[] = [
        { label: 'Challan No', value: challan.challanNo },
        { label: 'Date', value: formatDDMMYYYY(challan.createdAt) },
        ...(showGst && partyStateCode ? [{ label: 'Place of Supply', value: pos }] : []),
        ...(showGst
          ? [{ label: 'Supply Type', value: isInter ? 'Inter-State' : 'Intra-State' }]
          : []),
      ];
      const metaW = W / metaFields.length;
      const metaY = y;
      const drawMeta = (label: string, value: string, idx: number) => {
        const x = LEFT + idx * metaW;
        doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, metaY, { width: metaW - 6 });
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, metaY + 9, { width: metaW - 6 });
      };
      metaFields.forEach((f, i) => drawMeta(f.label, f.value, i));
      y = metaY + 28;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 10;

      const itemCols = buildPdfColumns<Row>(W, [
        { header: 'Sr', width: 22, align: 'left', cell: (_r, i) => String(i + 1) },
        {
          header: 'Item / SKU',
          width: isInter ? 132 : 120,
          align: 'left',
          flex: true,
          cell: (r) => `${r.name}\n${r.sku}`,
        },
        { header: 'HSN', width: isInter ? 46 : 44, align: 'left', show: showHsn, cell: (r) => r.hsn },
        {
          header: 'Qty',
          width: isInter ? 44 : 40,
          align: 'right',
          cell: (r) => `${r.qty.toString()} ${r.unit}`,
        },
        { header: 'Rate', width: isInter ? 50 : 46, align: 'right', cell: (r) => numFmt(r.rate) },
        {
          header: 'Taxable',
          width: isInter ? 56 : 52,
          align: 'right',
          show: showGst,
          cell: (r) => numFmt(r.taxable),
        },
        {
          header: 'GST%',
          width: isInter ? 33 : 31,
          align: 'right',
          show: showGst,
          cell: (r) => `${r.taxPct.toString()}%`,
        },
        { header: 'IGST', width: 66, align: 'right', show: showGst && isInter, cell: (r) => numFmt(r.igst) },
        { header: 'CGST', width: 53, align: 'right', show: showGst && !isInter, cell: (r) => numFmt(r.cgst) },
        { header: 'SGST', width: 53, align: 'right', show: showGst && !isInter, cell: (r) => numFmt(r.sgst) },
        { header: 'Total', width: isInter ? 66 : 54, align: 'right', cell: (r) => numFmt(r.total) },
      ]);
      const headers = itemCols.headers;
      const widths = itemCols.widths;
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }
      const align = itemCols.align;

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
        const cells = itemCols.row(r, sr - 1);
        cells.forEach((c, i) => doc.text(c, xs[i] + 2, y + 4, { width: widths[i] - 4, align: align(i) }));
        doc.moveTo(LEFT, y + rowH).lineTo(RIGHT, y + rowH).strokeColor('#E5E7EB').stroke();
        y += rowH;
        sr += 1;
      }

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
      if (showGst) {
        totRow('Taxable Value', money(totTaxable));
        if (isInter) {
          if (totIgst.gt(0)) totRow('IGST', money(totIgst));
        } else {
          if (totCgst.gt(0)) totRow('CGST', money(totCgst));
          if (totSgst.gt(0)) totRow('SGST', money(totSgst));
        }
        if (totCess.gt(0)) totRow('Cess', money(totCess));
      }
      doc.moveTo(totalsX, y).lineTo(totalsX + totalsW, y).strokeColor('#9CA3AF').stroke();
      y += 4;
      totRow('Total Value of Goods', money(grandTotal), true);

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

function pct(points: number[]): number[] {
  const total = points.reduce((a, b) => a + b, 0);
  return points.map((p) => (p / total) * 100);
}

async function renderChallanPdfReactPdf(
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
          registrationType: true,
          gstEffectiveFrom: true,
          name: true,
        },
      },
    },
  });
  const owner = shopRow?.owner ?? null;

  const productIds = [...new Set(challan.items.map((i) => i.productId))];
  const products = productIds.length
    ? await prisma.product.findMany({
        where: { id: { in: productIds }, shopId },
        select: { id: true, hsnCode: true, sellingPrice: true, taxPercent: true, cessRate: true },
      })
    : [];
  const productMap = new Map(products.map((p) => [p.id, p]));

  const shopStateCode = owner?.shopStateCode ?? (owner?.shopGstin ? owner.shopGstin.slice(0, 2) : null);
  let partyStateCode = challan.party?.stateCode ?? null;
  if (!partyStateCode && challan.party?.gstin) {
    const prefix = challan.party.gstin.slice(0, 2);
    if (isValidStateCode(prefix)) partyStateCode = prefix;
  }
  const isInter = isInterstateSupply(shopStateCode, partyStateCode);
  const chargesGst = owner ? isOutputGstRegistered(owner, challan.createdAt) : false;

  const D = Prisma.Decimal;
  const round2 = (v: Prisma.Decimal) => v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
  const numFmt = (n: Prisma.Decimal): string => n.toFixed(2);
  const money = (n: Prisma.Decimal): string => `Rs. ${n.toFixed(2)}`;

  type Row = {
    name: string;
    sku: string;
    hsn: string;
    qty: Prisma.Decimal;
    unit: string;
    rate: Prisma.Decimal;
  } & ChallanLineTax;
  const rows: Row[] = challan.items.map((it) => {
    const p = productMap.get(it.productId);
    const tax = computeChallanLineTax({
      quantity: it.quantity,
      sellingPrice: p?.sellingPrice,
      taxPercent: p?.taxPercent,
      cessRate: p?.cessRate,
      isInterstate: isInter,
      chargesGst,
    });
    return {
      name: it.productName,
      sku: it.productSku,
      hsn: p?.hsnCode ?? '',
      qty: new D(it.quantity.toString()),
      unit: it.unit,
      rate: p?.sellingPrice != null ? new D(p.sellingPrice.toString()) : new D(0),
      ...tax,
    };
  });

  const sum = (pick: (r: Row) => Prisma.Decimal) => rows.reduce((s, r) => s.add(pick(r)), new D(0));
  const totTaxable = round2(sum((r) => r.taxable));
  const totIgst = round2(sum((r) => r.igst));
  const totCgst = round2(sum((r) => r.cgst));
  const totSgst = round2(sum((r) => r.sgst));
  const totCess = round2(sum((r) => r.cess));
  const grandTotal = round2(sum((r) => r.total));

  const showGst =
    chargesGst || totIgst.gt(0) || totCgst.gt(0) || totSgst.gt(0) || totCess.gt(0);
  const showHsn = rows.some((r) => r.hsn.trim().length > 0);

  const itemCols = buildPdfColumns<Row>(515, [
    { header: 'Sr', width: 22, align: 'left', cell: (_r, i) => String(i + 1) },
    {
      header: 'Item / SKU',
      width: isInter ? 132 : 120,
      align: 'left',
      flex: true,
      cell: (r) => `${r.name}\n${r.sku}`,
    },
    { header: 'HSN', width: isInter ? 46 : 44, align: 'left', show: showHsn, cell: (r) => r.hsn },
    {
      header: 'Qty',
      width: isInter ? 44 : 40,
      align: 'right',
      cell: (r) => `${r.qty.toString()} ${r.unit}`,
    },
    { header: 'Rate', width: isInter ? 50 : 46, align: 'right', cell: (r) => numFmt(r.rate) },
    {
      header: 'Taxable',
      width: isInter ? 56 : 52,
      align: 'right',
      show: showGst,
      cell: (r) => numFmt(r.taxable),
    },
    {
      header: 'GST%',
      width: isInter ? 33 : 31,
      align: 'right',
      show: showGst,
      cell: (r) => `${r.taxPct.toString()}%`,
    },
    { header: 'IGST', width: 66, align: 'right', show: showGst && isInter, cell: (r) => numFmt(r.igst) },
    { header: 'CGST', width: 53, align: 'right', show: showGst && !isInter, cell: (r) => numFmt(r.cgst) },
    { header: 'SGST', width: 53, align: 'right', show: showGst && !isInter, cell: (r) => numFmt(r.sgst) },
    { header: 'Total', width: isInter ? 66 : 54, align: 'right', cell: (r) => numFmt(r.total) },
  ]);
  const itemWidths = pct(itemCols.widths);
  const align = itemCols.align;
  const itemRows = rows.map((r, idx) => ({
    cells: itemCols.row(r, idx).map((text, i) => ({ text, align: align(i) })),
  }));

  const totals: { label: string; value: string; bold?: boolean }[] = [];
  if (showGst) {
    totals.push({ label: 'Taxable Value', value: money(totTaxable) });
    if (isInter) {
      if (totIgst.gt(0)) totals.push({ label: 'IGST', value: money(totIgst) });
    } else {
      if (totCgst.gt(0)) totals.push({ label: 'CGST', value: money(totCgst) });
      if (totSgst.gt(0)) totals.push({ label: 'SGST', value: money(totSgst) });
    }
    if (totCess.gt(0)) totals.push({ label: 'Cess', value: money(totCess) });
  }
  totals.push({ label: 'Total Value of Goods', value: money(grandTotal), bold: true });

  const posName = stateNameFromCode(partyStateCode);
  const pos = partyStateCode ? `${partyStateCode}${posName ? ` - ${posName}` : ''}` : '-';
  const shopName = owner?.shopName ?? owner?.name ?? 'Shop';
  const party = challan.party;

  const model = {
    kind: 'challan' as const,
    title: 'DELIVERY CHALLAN',
    shop: {
      name: shopName,
      addressLine: composeAddress(owner?.shopAddress, owner?.shopCity, owner?.shopState, owner?.shopPinCode),
      gstin: owner?.shopGstin,
      pan: owner?.shopPan,
    },
    shopLabel: 'Consignor',
    counterpartyLabel: 'Consignee',
    counterparty: {
      name: party?.name ?? challan.partyName ?? '-',
      addressLine: composeAddress(party?.address, party?.city, party?.state, party?.pinCode),
      gstin: party?.gstin,
      pan: party?.panNumber,
      extraLine: challan.partyPhone ?? undefined,
    },
    meta: [
      { label: 'Challan No', value: challan.challanNo },
      { label: 'Date', value: formatDDMMYYYY(challan.createdAt) },
      ...(showGst && partyStateCode ? [{ label: 'Place of Supply', value: pos }] : []),
      ...(showGst ? [{ label: 'Supply Type', value: isInter ? 'Inter-State' : 'Intra-State' }] : []),
    ],
    items: {
      headers: itemCols.headers.map((text, i) => ({ text, align: align(i) })),
      widths: itemWidths,
      rows: itemRows,
    },
    totals,
    declaration: chargesGst
      ? 'Delivery challan issued under Rule 55 of the CGST Rules. Not a tax invoice — goods are dispatched against this challan; the tax invoice follows on supply.'
      : 'Delivery challan issued under Rule 55 of the CGST Rules. The consignor is not registered to collect GST, so no tax is charged on this document.',
    signatureName: `For ${shopName}`,
    note: challan.note ?? undefined,
    traditionalMeta: {
      documentNo: challan.challanNo,
      documentDate: formatDDMMYYYY(challan.createdAt),
    },
  };

  const engine = await loadPdfEngine();
  if (out) {
    await engine.renderPdfToStream(model, shopRow?.pdfTemplateId, out, onReady);
    return null;
  }
  return engine.renderPdfToBuffer(model, shopRow?.pdfTemplateId);
}
