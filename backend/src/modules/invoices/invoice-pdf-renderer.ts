import PDFDocument from 'pdfkit';
import { Prisma, type RegistrationType } from '@prisma/client';
import { Writable } from 'stream';
import QRCode from 'qrcode';
import prisma from '../../infra/db/prisma.js';
import { stateNameFromCode } from '../../shared/validation/indian.js';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';
import { buildPdfColumns } from '../../shared/pdfColumns.js';
import { isOutputGstRegistered } from './gst-registration-gate.js';

export async function renderInvoicePdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  if (process.env.PDF_ENGINE === 'pdfkit') {
    return renderInvoicePdfPdfKit(shopId, id, out, onReady);
  }
  return renderInvoicePdfReactPdf(shopId, id, out, onReady);
}

async function renderInvoicePdfPdfKit(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
    const invoice = await prisma.invoice.findFirst({
      where: { id, shopId },
      include: { vendor: true, party: true, items: { orderBy: { id: 'asc' } } },
    });

    if (!invoice) return { error: 'Invoice not found' };

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
            upiVpa: true,
            name: true,
            email: true,
          },
        },
      },
    });
    const owner = shopRow?.owner ?? null;
    const { showGst, showHsn } = invoiceGstVisibility(invoice, owner);

    let originalRef: { invoiceNo: string; invoiceDate: Date } | null = null;
    if (
      (invoice.documentType === 'CREDIT_NOTE' || invoice.documentType === 'DEBIT_NOTE') &&
      invoice.originalInvoiceId
    ) {
      const orig = await prisma.invoice.findFirst({
        where: { id: invoice.originalInvoiceId, shopId },
        select: { invoiceNo: true, invoiceDate: true },
      });
      if (orig) originalRef = orig;
    }

    const D = Prisma.Decimal;
    const total = new D(invoice.total.toString());
    let upiQr: { buffer: Buffer; link: string } | null = null;
    if (
      invoice.type === 'SALE' &&
      owner?.upiVpa &&
      total.gt(0) &&
      (await hasOutstandingBalance(shopId, invoice.id, total))
    ) {
      const payeeName = owner.shopName ?? owner.name ?? 'Merchant';
      const link =
        `upi://pay?pa=${encodeURIComponent(owner.upiVpa)}` +
        `&pn=${encodeURIComponent(payeeName)}` +
        `&am=${total.toFixed(2)}` +
        `&cu=INR` +
        `&tn=${encodeURIComponent(`Invoice ${invoice.invoiceNo}`)}`;
      try {
        const buffer = await QRCode.toBuffer(link, { type: 'png', width: 220, margin: 1 });
        upiQr = { buffer, link };
      } catch {
        upiQr = null;
      }
    }

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
      const PAGE_W = 595;
      const LEFT = 40;
      const RIGHT = 555;
      const invoiceDate = formatDDMMYYYY(invoice.invoiceDate);
      const currencyFmt = (n: number | string | Prisma.Decimal | null | undefined): string => {
        if (n === null || n === undefined) return 'Rs. 0.00';
        return `Rs. ${new D(n.toString()).toFixed(2)}`;
      };
      const numFmt = (n: number | string | Prisma.Decimal | null | undefined): string => {
        if (n === null || n === undefined) return '0.00';
        return new D(n.toString()).toFixed(2);
      };
      const signedRoundOff = (v: Prisma.Decimal | number | string | null | undefined): string => {
        if (v === null || v === undefined) return '+0.00';
        const d = new D(v.toString());
        if (d.gte(0)) return `+${d.toFixed(2)}`;
        return `−${d.abs().toFixed(2)}`;
      };

      try {
      const docTitle = documentTypeLabel(invoice.documentType);
      doc
        .fillColor('#111827')
        .font('Helvetica-Bold')
        .fontSize(18)
        .text(docTitle, LEFT, 40, { width: W, align: 'center' });

      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#6B7280')
        .text('Original for Recipient', LEFT, 40, { width: W, align: 'right' })
        .text('Duplicate for Transporter', LEFT, 50, { width: W, align: 'right' })
        .text('Triplicate for Supplier', LEFT, 60, { width: W, align: 'right' });

      doc.fillColor('#111827');
      doc.moveTo(LEFT, 78).lineTo(RIGHT, 78).strokeColor('#9CA3AF').lineWidth(1).stroke();

      const blocksY = 88;
      const colW = (W - 20) / 2;
      const leftX = LEFT;
      const rightX = LEFT + colW + 20;

      const shopName = owner?.shopName ?? owner?.name ?? 'Shop';
      const shopAddressLine = composeAddress(
        owner?.shopAddress,
        owner?.shopCity,
        owner?.shopState,
        owner?.shopPinCode,
      );
      doc.font('Helvetica-Bold').fontSize(11).text(shopName, leftX, blocksY, { width: colW });
      let lY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      if (shopAddressLine) {
        doc.text(shopAddressLine, leftX, lY, { width: colW });
        lY = doc.y;
      }
      if (owner?.shopGstin) {
        doc.text(`GSTIN: ${owner.shopGstin}`, leftX, lY, { width: colW });
        lY = doc.y;
      }
      if (owner?.shopPan) {
        doc.text(`PAN: ${owner.shopPan}`, leftX, lY, { width: colW });
        lY = doc.y;
      }
      const shopBlockBottom = lY;

      const isSale = invoice.type === 'SALE';
      const cpLabel = isSale ? 'Bill To' : 'Vendor';
      const cpName = isSale
        ? (invoice.customerName ?? invoice.party?.name ?? '-')
        : (invoice.vendorName ?? invoice.vendor?.name ?? '-');
      const cpAddress = isSale
        ? composeAddress(invoice.customerAddress, invoice.customerCity, invoice.customerState, invoice.customerPinCode)
        : composeAddress(invoice.vendorAddress, invoice.vendorCity, invoice.vendorState, invoice.vendorPinCode);
      const cpGstin = isSale ? invoice.customerGstin : invoice.vendorGstin;
      const cpPan = isSale ? invoice.customerPanNumber : invoice.vendorPanNumber;

      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(9).text(cpLabel, rightX, blocksY, { width: colW });
      let rY = doc.y + 2;
      doc.font('Helvetica-Bold').fontSize(11).fillColor('#111827').text(cpName, rightX, rY, { width: colW });
      rY = doc.y + 2;
      doc.font('Helvetica').fontSize(9).fillColor('#374151');
      if (cpAddress) {
        doc.text(cpAddress, rightX, rY, { width: colW });
        rY = doc.y;
      }
      if (cpGstin) {
        doc.text(`GSTIN: ${cpGstin}`, rightX, rY, { width: colW });
        rY = doc.y;
      }
      if (cpPan) {
        doc.text(`PAN: ${cpPan}`, rightX, rY, { width: colW });
        rY = doc.y;
      }
      const cpBlockBottom = rY;

      let y = Math.max(shopBlockBottom, cpBlockBottom) + 12;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 6;

      const posStateName = stateNameFromCode(invoice.placeOfSupplyStateCode);
      const placeOfSupply = invoice.placeOfSupplyStateCode
        ? `${invoice.placeOfSupplyStateCode}${posStateName ? ` - ${posStateName}` : ''}`
        : '-';

      doc.fillColor('#111827').font('Helvetica').fontSize(9);
      const metaFields: { label: string; value: string }[] = [
        { label: 'Invoice No', value: invoice.invoiceNo },
        { label: 'Date', value: invoiceDate },
        ...(showGst && invoice.placeOfSupplyStateCode
          ? [{ label: 'Place of Supply', value: placeOfSupply }]
          : []),
        { label: 'FY', value: invoice.financialYear },
      ];
      const metaW = W / metaFields.length;
      const metaRowY = y;
      const drawMeta = (label: string, value: string, idx: number) => {
        const x = LEFT + idx * metaW;
        doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, metaRowY, { width: metaW - 6 });
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, metaRowY + 9, { width: metaW - 6 });
      };
      metaFields.forEach((f, i) => drawMeta(f.label, f.value, i));
      y = metaRowY + 28;

      if (originalRef) {
        const origRowY = y;
        const drawMeta2 = (label: string, value: string, idx: number) => {
          const x = LEFT + idx * metaW;
          doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, origRowY, { width: metaW - 6 });
          doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, origRowY + 9, { width: metaW - 6 });
        };
        drawMeta2('Original Invoice No', originalRef.invoiceNo, 0);
        drawMeta2('Original Invoice Date', formatDDMMYYYY(originalRef.invoiceDate), 1);
        y = origRowY + 28;
      }

      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 10;

      const isInter = invoice.isInterstate;
      const itemCols = buildPdfColumns<(typeof invoice.items)[number]>(W, [
        { header: 'Sr', width: 22, align: 'left', cell: (_it, i) => String(i + 1) },
        {
          header: 'Item / SKU',
          width: isInter ? 120 : 116,
          align: 'left',
          flex: true,
          cell: (it) => `${it.productName}\n${it.productSku}`,
        },
        { header: 'HSN', width: isInter ? 42 : 40, align: 'left', show: showHsn, cell: (it) => it.hsn ?? '' },
        {
          header: 'Qty',
          width: isInter ? 38 : 34,
          align: 'right',
          cell: (it) => `${new D(it.quantity.toString()).toString()} ${it.unit}`,
        },
        { header: 'Rate', width: isInter ? 46 : 42, align: 'right', cell: (it) => numFmt(it.unitPrice) },
        { header: 'Disc', width: isInter ? 38 : 34, align: 'right', cell: (it) => numFmt(it.discount) },
        {
          header: 'Taxable',
          width: isInter ? 52 : 50,
          align: 'right',
          show: showGst,
          cell: (it) => numFmt(it.taxableValue),
        },
        {
          header: 'GST%',
          width: isInter ? 32 : 30,
          align: 'right',
          show: showGst,
          cell: (it) => `${new D(it.taxPercent.toString()).toString()}%`,
        },
        { header: 'IGST', width: 65, align: 'right', show: showGst && isInter, cell: (it) => numFmt(it.igstAmount) },
        { header: 'CGST', width: 45, align: 'right', show: showGst && !isInter, cell: (it) => numFmt(it.cgstAmount) },
        { header: 'SGST', width: 45, align: 'right', show: showGst && !isInter, cell: (it) => numFmt(it.sgstAmount) },
        { header: 'Total', width: isInter ? 60 : 57, align: 'right', cell: (it) => numFmt(it.total) },
      ]);
      const headers = itemCols.headers;
      const widths = itemCols.widths;
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }

      const align = itemCols.align;

      doc.rect(LEFT, y, W, 18).fill('#F3F4F6');
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(7.5);
      headers.forEach((h, i) => {
        doc.text(h, xs[i] + 2, y + 5, { width: widths[i] - 4, align: align(i) });
      });
      y += 18;
      doc.font('Helvetica').fontSize(8);

      let sr = 1;
      for (const item of invoice.items) {
        const rowH = 28;
        if (y + rowH > 720) {
          doc.addPage();
          y = 40;
          doc.rect(LEFT, y, W, 18).fill('#F3F4F6');
          doc.fillColor('#111827').font('Helvetica-Bold').fontSize(7.5);
          headers.forEach((h, i) => {
            doc.text(h, xs[i] + 2, y + 5, { width: widths[i] - 4, align: align(i) });
          });
          y += 18;
          doc.font('Helvetica').fontSize(8);
        }
        doc.fillColor('#111827');
        const row = itemCols.row(item, sr - 1);
        row.forEach((c, i) => {
          doc.text(c, xs[i] + 2, y + 4, { width: widths[i] - 4, align: align(i) });
        });
        doc.moveTo(LEFT, y + rowH).lineTo(RIGHT, y + rowH).strokeColor('#E5E7EB').stroke();
        y += rowH;
        sr += 1;
      }

      type HsnAgg = {
        taxable: Prisma.Decimal;
        igst: Prisma.Decimal;
        cgst: Prisma.Decimal;
        sgst: Prisma.Decimal;
        cess: Prisma.Decimal;
      };
      const hsnMap = new Map<string, HsnAgg>();
      for (const it of showGst ? invoice.items : []) {
        if (!it.hsn) continue;
        const cur = hsnMap.get(it.hsn) ?? {
          taxable: new D(0), igst: new D(0), cgst: new D(0), sgst: new D(0), cess: new D(0),
        };
        cur.taxable = cur.taxable.add(new D(it.taxableValue.toString()));
        cur.igst = cur.igst.add(new D(it.igstAmount.toString()));
        cur.cgst = cur.cgst.add(new D(it.cgstAmount.toString()));
        cur.sgst = cur.sgst.add(new D(it.sgstAmount.toString()));
        cur.cess = cur.cess.add(new D(it.cessAmount.toString()));
        hsnMap.set(it.hsn, cur);
      }

      if (hsnMap.size > 0) {
        y += 10;
        if (y + 60 > 760) { doc.addPage(); y = 40; }
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text('HSN Summary', LEFT, y);
        y += 14;
        const hsnHeaders = isInter
          ? ['HSN', 'Taxable Value', 'IGST', 'Cess', 'Total Tax']
          : ['HSN', 'Taxable Value', 'CGST', 'SGST', 'Cess', 'Total Tax'];
        const hsnWidths = isInter ? [80, 110, 100, 100, 125] : [80, 100, 80, 80, 80, 95];
        const hsnXs: number[] = [];
        let hx = LEFT;
        for (const w of hsnWidths) { hsnXs.push(hx); hx += w; }
        const hsnAlign = (i: number): 'left' | 'right' => i === 0 ? 'left' : 'right';

        doc.rect(LEFT, y, W, 16).fill('#F3F4F6');
        doc.fillColor('#111827').font('Helvetica-Bold').fontSize(7.5);
        hsnHeaders.forEach((h, i) => {
          doc.text(h, hsnXs[i] + 2, y + 4, { width: hsnWidths[i] - 4, align: hsnAlign(i) });
        });
        y += 16;
        doc.font('Helvetica').fontSize(8);

        for (const [hsn, agg] of hsnMap) {
          if (y + 18 > 760) { doc.addPage(); y = 40; }
          const totalTax = agg.igst.add(agg.cgst).add(agg.sgst).add(agg.cess);
          const cells = isInter
            ? [hsn, numFmt(agg.taxable), numFmt(agg.igst), numFmt(agg.cess), numFmt(totalTax)]
            : [hsn, numFmt(agg.taxable), numFmt(agg.cgst), numFmt(agg.sgst), numFmt(agg.cess), numFmt(totalTax)];
          cells.forEach((c, i) => {
            doc.text(c, hsnXs[i] + 2, y + 4, { width: hsnWidths[i] - 4, align: hsnAlign(i) });
          });
          doc.moveTo(LEFT, y + 16).lineTo(RIGHT, y + 16).strokeColor('#E5E7EB').stroke();
          y += 16;
        }
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

      let lineDiscount = new D(0);
      for (const it of invoice.items) lineDiscount = lineDiscount.add(new D(it.discount.toString()));
      const totalDiscount = new D(invoice.discount.toString()).add(lineDiscount);

      totRow('Subtotal', currencyFmt(invoice.subtotal));
      if (totalDiscount.gt(0)) totRow('Total Discount', `- ${currencyFmt(totalDiscount)}`);
      if (showGst) {
        totRow('Taxable Value', currencyFmt(invoice.taxableValue));
        if (isInter) {
          totRow('IGST', currencyFmt(invoice.igstAmount));
        } else {
          totRow('CGST', currencyFmt(invoice.cgstAmount));
          totRow('SGST', currencyFmt(invoice.sgstAmount));
        }
        if (new D(invoice.cessAmount.toString()).gt(0)) totRow('Cess', currencyFmt(invoice.cessAmount));
      }
      if (!new D(invoice.roundOff.toString()).eq(0)) totRow('Round-off', signedRoundOff(invoice.roundOff));
      doc.moveTo(totalsX, y).lineTo(totalsX + totalsW, y).strokeColor('#9CA3AF').stroke();
      y += 4;
      totRow('Grand Total', currencyFmt(invoice.total), true);

      if (invoice.amountInWords) {
        y += 4;
        if (y + 14 > 770) { doc.addPage(); y = 40; }
        doc
          .font('Helvetica-Oblique')
          .fontSize(9)
          .fillColor('#374151')
          .text(invoice.amountInWords, LEFT, y, { width: W });
        y = doc.y + 4;
      }

      {
        if (y + 26 > 770) { doc.addPage(); y = 40; }
        if (invoice.documentType === 'BILL_OF_SUPPLY') {
          doc
            .font('Helvetica-Oblique')
            .fontSize(8)
            .fillColor('#6B7280')
            .text(
              'Bill of Supply — the supplier is not registered to collect GST / is under the composition scheme. No tax is charged on this document.',
              LEFT,
              y,
              { width: W },
            );
          y = doc.y + 4;
        } else if (invoice.documentType === 'TAX_INVOICE') {
          const reverseCharge =
            (invoice as { reverseCharge?: boolean | null }).reverseCharge === true;
          doc
            .font('Helvetica')
            .fontSize(8)
            .fillColor('#6B7280')
            .text(
              `Tax payable on reverse charge: ${reverseCharge ? 'Yes' : 'No'}`,
              LEFT,
              y,
              { width: W },
            );
          y = doc.y + 4;
        }
      }

      const bandTop = y;
      if (upiQr) {
        if (y + 140 > 770) { doc.addPage(); y = 40; }
        const qY = y;
        doc.image(upiQr.buffer, LEFT, qY, { width: 110 });
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#374151')
          .text('Scan to pay with any UPI app', LEFT, qY + 114, { width: 140 });
        if (owner?.upiVpa) {
          doc.fontSize(8).fillColor('#6B7280').text(`UPI: ${owner.upiVpa}`, LEFT, qY + 126, { width: 200 });
        }
        y = qY + 140;
      }

      {
        const sigW = 200;
        const sigX = RIGHT - sigW;
        let sigY = upiQr ? bandTop : y;
        if (sigY + 90 > 790) { doc.addPage(); sigY = 40; y = 40; }
        const supplierName = owner?.shopName ?? owner?.name ?? 'Supplier';
        doc
          .font('Helvetica-Bold')
          .fontSize(9)
          .fillColor('#111827')
          .text(`For ${supplierName}`, sigX, sigY, { width: sigW, align: 'right' });

        const signatureImage: Buffer | null = null;
        const lineY = sigY + 46;
        if (signatureImage) {
          try {
            doc.image(signatureImage, sigX + sigW - 120, sigY + 12, { width: 120, height: 32 });
          } catch {
          }
        }
        doc.moveTo(sigX, lineY).lineTo(RIGHT, lineY).strokeColor('#9CA3AF').lineWidth(0.7).stroke();
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#374151')
          .text('Authorised Signatory', sigX, lineY + 4, { width: sigW, align: 'right' });
        y = Math.max(y, lineY + 18);
      }

      if (invoice.note) {
        y += 6;
        if (y + 30 > 770) { doc.addPage(); y = 40; }
        doc.font('Helvetica-Bold').fontSize(8).fillColor('#111827').text('Notes', LEFT, y);
        doc.font('Helvetica').fontSize(8).fillColor('#374151').text(invoice.note, LEFT, y + 12, { width: W });
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
      void PAGE_W;

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

export function invoiceGstVisibility(
  invoice: {
    type: string;
    invoiceDate: Date;
    items: { hsn: string | null; taxPercent: Prisma.Decimal }[];
    igstAmount: Prisma.Decimal;
    cgstAmount: Prisma.Decimal;
    sgstAmount: Prisma.Decimal;
    cessAmount: Prisma.Decimal;
  },
  owner: {
    shopGstin: string | null;
    registrationType: RegistrationType;
    gstEffectiveFrom: Date | null;
  } | null,
): { showGst: boolean; showHsn: boolean } {
  const D = Prisma.Decimal;
  const hasTaxFigures =
    invoice.items.some((it) => new D(it.taxPercent.toString()).gt(0)) ||
    [invoice.igstAmount, invoice.cgstAmount, invoice.sgstAmount, invoice.cessAmount].some((v) =>
      new D(v.toString()).gt(0),
    );
  const registered =
    invoice.type === 'SALE' && owner ? isOutputGstRegistered(owner, invoice.invoiceDate) : false;
  return {
    showGst: registered || hasTaxFigures,
    showHsn: invoice.items.some((it) => (it.hsn ?? '').trim().length > 0),
  };
}

function documentTypeLabel(docType: string): string {
  switch (docType) {
    case 'TAX_INVOICE': return 'TAX INVOICE';
    case 'BILL_OF_SUPPLY': return 'BILL OF SUPPLY';
    case 'ESTIMATE': return 'ESTIMATE';
    case 'PROFORMA': return 'PROFORMA INVOICE';
    case 'CREDIT_NOTE': return 'CREDIT NOTE';
    case 'DEBIT_NOTE': return 'DEBIT NOTE';
    default: return docType.replace(/_/g, ' ').toUpperCase();
  }
}

async function hasOutstandingBalance(shopId: number, invoiceId: number, total: Prisma.Decimal): Promise<boolean> {
  const allocated = await prisma.payment.aggregate({
    where: { invoiceId, shopId, voidedAt: null },
    _sum: { amount: true },
  });
  const applied = new Prisma.Decimal(allocated._sum.amount?.toString() ?? '0');
  return total.minus(applied).gt(0);
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

async function renderInvoicePdfReactPdf(
  shopId: number,
  id: number,
  out: Writable | null,
  onReady?: () => void,
): Promise<Buffer | null | { error: string }> {
  const invoice = await prisma.invoice.findFirst({
    where: { id, shopId },
    include: { vendor: true, party: true, items: { orderBy: { id: 'asc' } } },
  });
  if (!invoice) return { error: 'Invoice not found' };

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
          upiVpa: true,
          name: true,
          email: true,
        },
      },
    },
  });
  const owner = shopRow?.owner ?? null;

  let originalRef: { invoiceNo: string; invoiceDate: Date } | null = null;
  if (
    (invoice.documentType === 'CREDIT_NOTE' || invoice.documentType === 'DEBIT_NOTE') &&
    invoice.originalInvoiceId
  ) {
    const orig = await prisma.invoice.findFirst({
      where: { id: invoice.originalInvoiceId, shopId },
      select: { invoiceNo: true, invoiceDate: true },
    });
    if (orig) originalRef = orig;
  }

  const D = Prisma.Decimal;
  const total = new D(invoice.total.toString());
  let upiQr: { buffer: Buffer; link: string } | null = null;
  if (
    invoice.type === 'SALE' &&
    owner?.upiVpa &&
    total.gt(0) &&
    (await hasOutstandingBalance(shopId, invoice.id, total))
  ) {
    const payeeName = owner.shopName ?? owner.name ?? 'Merchant';
    const link =
      `upi://pay?pa=${encodeURIComponent(owner.upiVpa)}` +
      `&pn=${encodeURIComponent(payeeName)}` +
      `&am=${total.toFixed(2)}` +
      `&cu=INR` +
      `&tn=${encodeURIComponent(`Invoice ${invoice.invoiceNo}`)}`;
    try {
      const buffer = await QRCode.toBuffer(link, { type: 'png', width: 220, margin: 1 });
      upiQr = { buffer, link };
    } catch {
      upiQr = null;
    }
  }

  const currencyFmt = (n: number | string | Prisma.Decimal | null | undefined): string => {
    if (n === null || n === undefined) return 'Rs. 0.00';
    return `Rs. ${new D(n.toString()).toFixed(2)}`;
  };
  const numFmt = (n: number | string | Prisma.Decimal | null | undefined): string => {
    if (n === null || n === undefined) return '0.00';
    return new D(n.toString()).toFixed(2);
  };
  const signedRoundOff = (v: Prisma.Decimal | number | string | null | undefined): string => {
    if (v === null || v === undefined) return '+0.00';
    const d = new D(v.toString());
    if (d.gte(0)) return `+${d.toFixed(2)}`;
    return `−${d.abs().toFixed(2)}`;
  };

  const isSale = invoice.type === 'SALE';
  const cpLabel = isSale ? 'Bill To' : 'Vendor';
  const cpName = isSale
    ? (invoice.customerName ?? invoice.party?.name ?? '-')
    : (invoice.vendorName ?? invoice.vendor?.name ?? '-');
  const cpAddress = isSale
    ? composeAddress(invoice.customerAddress, invoice.customerCity, invoice.customerState, invoice.customerPinCode)
    : composeAddress(invoice.vendorAddress, invoice.vendorCity, invoice.vendorState, invoice.vendorPinCode);
  const cpGstin = isSale ? invoice.customerGstin : invoice.vendorGstin;
  const cpPan = isSale ? invoice.customerPanNumber : invoice.vendorPanNumber;

  const posStateName = stateNameFromCode(invoice.placeOfSupplyStateCode);
  const placeOfSupply = invoice.placeOfSupplyStateCode
    ? `${invoice.placeOfSupplyStateCode}${posStateName ? ` - ${posStateName}` : ''}`
    : '-';

  const isInter = invoice.isInterstate;
  const { showGst, showHsn } = invoiceGstVisibility(invoice, owner);

  const itemCols = buildPdfColumns<(typeof invoice.items)[number]>(515, [
    { header: 'Sr', width: 22, align: 'left', cell: (_it, i) => String(i + 1) },
    {
      header: 'Item / SKU',
      width: isInter ? 120 : 116,
      align: 'left',
      flex: true,
      cell: (it) => `${it.productName}\n${it.productSku}`,
    },
    { header: 'HSN', width: isInter ? 42 : 40, align: 'left', show: showHsn, cell: (it) => it.hsn ?? '' },
    {
      header: 'Qty',
      width: isInter ? 38 : 34,
      align: 'right',
      cell: (it) => `${new D(it.quantity.toString()).toString()} ${it.unit}`,
    },
    { header: 'Rate', width: isInter ? 46 : 42, align: 'right', cell: (it) => numFmt(it.unitPrice) },
    { header: 'Disc', width: isInter ? 38 : 34, align: 'right', cell: (it) => numFmt(it.discount) },
    {
      header: 'Taxable',
      width: isInter ? 52 : 50,
      align: 'right',
      show: showGst,
      cell: (it) => numFmt(it.taxableValue),
    },
    {
      header: 'GST%',
      width: isInter ? 32 : 30,
      align: 'right',
      show: showGst,
      cell: (it) => `${new D(it.taxPercent.toString()).toString()}%`,
    },
    { header: 'IGST', width: 65, align: 'right', show: showGst && isInter, cell: (it) => numFmt(it.igstAmount) },
    { header: 'CGST', width: 45, align: 'right', show: showGst && !isInter, cell: (it) => numFmt(it.cgstAmount) },
    { header: 'SGST', width: 45, align: 'right', show: showGst && !isInter, cell: (it) => numFmt(it.sgstAmount) },
    { header: 'Total', width: isInter ? 60 : 57, align: 'right', cell: (it) => numFmt(it.total) },
  ]);
  const itemWidths = pct(itemCols.widths);
  const align = itemCols.align;

  const itemRows = invoice.items.map((item, idx) => ({
    cells: itemCols.row(item, idx).map((text, i) => ({ text, align: align(i) })),
  }));

  type HsnAgg = {
    taxable: Prisma.Decimal;
    igst: Prisma.Decimal;
    cgst: Prisma.Decimal;
    sgst: Prisma.Decimal;
    cess: Prisma.Decimal;
  };
  const hsnMap = new Map<string, HsnAgg>();
  for (const it of invoice.items) {
    if (!it.hsn) continue;
    const cur = hsnMap.get(it.hsn) ?? {
      taxable: new D(0), igst: new D(0), cgst: new D(0), sgst: new D(0), cess: new D(0),
    };
    cur.taxable = cur.taxable.add(new D(it.taxableValue.toString()));
    cur.igst = cur.igst.add(new D(it.igstAmount.toString()));
    cur.cgst = cur.cgst.add(new D(it.cgstAmount.toString()));
    cur.sgst = cur.sgst.add(new D(it.sgstAmount.toString()));
    cur.cess = cur.cess.add(new D(it.cessAmount.toString()));
    hsnMap.set(it.hsn, cur);
  }
  const hsnHeaders = isInter
    ? ['HSN', 'Taxable Value', 'IGST', 'Cess', 'Total Tax']
    : ['HSN', 'Taxable Value', 'CGST', 'SGST', 'Cess', 'Total Tax'];
  const hsnWidths = isInter ? pct([80, 110, 100, 100, 125]) : pct([80, 100, 80, 80, 80, 95]);
  const hsnAlign = (i: number): 'left' | 'right' => (i === 0 ? 'left' : 'right');
  const hsnRows = Array.from(hsnMap.entries()).map(([hsn, agg]) => {
    const totalTax = agg.igst.add(agg.cgst).add(agg.sgst).add(agg.cess);
    const cells = isInter
      ? [hsn, numFmt(agg.taxable), numFmt(agg.igst), numFmt(agg.cess), numFmt(totalTax)]
      : [hsn, numFmt(agg.taxable), numFmt(agg.cgst), numFmt(agg.sgst), numFmt(agg.cess), numFmt(totalTax)];
    return { cells: cells.map((text, i) => ({ text, align: hsnAlign(i) })) };
  });

  let lineDiscount = new D(0);
  for (const it of invoice.items) lineDiscount = lineDiscount.add(new D(it.discount.toString()));
  const totalDiscount = new D(invoice.discount.toString()).add(lineDiscount);

  const totals: { label: string; value: string; bold?: boolean }[] = [
    { label: 'Subtotal', value: currencyFmt(invoice.subtotal) },
  ];
  if (totalDiscount.gt(0)) totals.push({ label: 'Total Discount', value: `- ${currencyFmt(totalDiscount)}` });
  if (showGst) {
    totals.push({ label: 'Taxable Value', value: currencyFmt(invoice.taxableValue) });
    if (isInter) {
      totals.push({ label: 'IGST', value: currencyFmt(invoice.igstAmount) });
    } else {
      totals.push({ label: 'CGST', value: currencyFmt(invoice.cgstAmount) });
      totals.push({ label: 'SGST', value: currencyFmt(invoice.sgstAmount) });
    }
    if (new D(invoice.cessAmount.toString()).gt(0)) {
      totals.push({ label: 'Cess', value: currencyFmt(invoice.cessAmount) });
    }
  }
  if (!new D(invoice.roundOff.toString()).eq(0)) totals.push({ label: 'Round-off', value: signedRoundOff(invoice.roundOff) });
  totals.push({ label: 'Grand Total', value: currencyFmt(invoice.total), bold: true });

  let declaration: string | undefined;
  if (invoice.documentType === 'BILL_OF_SUPPLY') {
    declaration =
      'Bill of Supply — the supplier is not registered to collect GST / is under the composition scheme. No tax is charged on this document.';
  } else if (invoice.documentType === 'TAX_INVOICE') {
    const reverseCharge = (invoice as { reverseCharge?: boolean | null }).reverseCharge === true;
    declaration = `Tax payable on reverse charge: ${reverseCharge ? 'Yes' : 'No'}`;
  }

  const shopName = owner?.shopName ?? owner?.name ?? 'Shop';
  const model = {
    kind: 'invoice' as const,
    title: documentTypeLabel(invoice.documentType),
    titleBadgeLines: ['Original for Recipient', 'Duplicate for Transporter', 'Triplicate for Supplier'],
    shop: {
      name: shopName,
      addressLine: composeAddress(owner?.shopAddress, owner?.shopCity, owner?.shopState, owner?.shopPinCode),
      gstin: owner?.shopGstin,
      pan: owner?.shopPan,
    },
    counterpartyLabel: cpLabel,
    counterparty: { name: cpName, addressLine: cpAddress, gstin: cpGstin, pan: cpPan },
    meta: [
      { label: 'Invoice No', value: invoice.invoiceNo },
      { label: 'Date', value: formatDDMMYYYY(invoice.invoiceDate) },
      ...(showGst && invoice.placeOfSupplyStateCode
        ? [{ label: 'Place of Supply', value: placeOfSupply }]
        : []),
      { label: 'FY', value: invoice.financialYear },
    ],
    metaSecondRow: originalRef
      ? [
          { label: 'Original Invoice No', value: originalRef.invoiceNo },
          { label: 'Original Invoice Date', value: formatDDMMYYYY(originalRef.invoiceDate) },
        ]
      : undefined,
    items: {
      headers: itemCols.headers.map((text, i) => ({ text, align: align(i) })),
      widths: itemWidths,
      rows: itemRows,
    },
    hsnSummary: showGst && hsnMap.size > 0
      ? { headers: hsnHeaders.map((text, i) => ({ text, align: hsnAlign(i) })), widths: hsnWidths, rows: hsnRows }
      : undefined,
    totals,
    amountInWords: invoice.amountInWords ?? undefined,
    declaration,
    upiQr: upiQr
      ? {
          buffer: upiQr.buffer,
          caption: 'Scan to pay with any UPI app',
          vpaLine: owner?.upiVpa ? `UPI: ${owner.upiVpa}` : undefined,
        }
      : undefined,
    signatureName: `For ${shopName}`,
    note: invoice.note ?? undefined,
    traditionalMeta: {
      documentNo: invoice.invoiceNo,
      documentDate: formatDDMMYYYY(invoice.invoiceDate),
    },
  };

  const engine = await loadPdfEngine();
  if (out) {
    await engine.renderPdfToStream(model, shopRow?.pdfTemplateId, out, onReady);
    return null;
  }
  return engine.renderPdfToBuffer(model, shopRow?.pdfTemplateId);
}
