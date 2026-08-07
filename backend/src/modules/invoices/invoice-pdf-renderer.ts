import PDFDocument from 'pdfkit';
import { Prisma, type RegistrationType } from '@prisma/client';
import { Writable } from 'stream';
import QRCode from 'qrcode';
import prisma from '../../infra/db/prisma.js';
import { stateNameFromCode } from '../../shared/validation/indian.js';
import { loadPdfEngine } from '../../shared/pdfEngineLoader.js';
import { buildPdfColumns } from '../../shared/pdfColumns.js';
import { isOutputGstRegistered } from './gst-registration-gate.js';

/// Render one invoice as a PDF — to a stream when `out` is set, or to a
/// Buffer otherwise. Returns `{ error }` if the invoice can't be found or
/// doesn't belong to `shopId`.
///
/// Dispatches to the react-pdf engine (which honors the shop's chosen
/// `pdfTemplateId`) by default; set `PDF_ENGINE=pdfkit` to roll back to the
/// original hand-drawn PDFKit layout below — a one-line env change, not a
/// redeploy, if the new engine ever misbehaves in production.
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

/// The original hand-drawn PDFKit layout — kept verbatim as the rollback
/// path (see `PDF_ENGINE=pdfkit` above).
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

    // Shop owner row — drives header block + UPI QR. Looked up via the
    // owning Shop, not the global "first OWNER" — that pre-migration
    // path printed Merchant A's UPI on Merchant B's invoice.
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
            // Drives whether the GST columns print at all — see
            // `invoiceGstVisibility`.
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

    // GST-2 (Rule 53) — a credit/debit note MUST carry the serial number and
    // date of the original tax invoice it adjusts. Look it up (scoped to the
    // same shop) so it can be printed in the meta strip. Null when the link
    // is missing (legacy rows) — the strip then simply omits the reference.
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

    // Generate the UPI QR up-front so the awaitable lives outside the
    // PDFKit promise. Only applicable to SALE invoices with a non-zero
    // total and a configured VPA.
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
        // QR generation should never block the invoice — degrade gracefully.
        upiQr = null;
      }
    }

    return new Promise<Buffer | null>((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] | null = out ? null : [];
      let settled = false;
      const cleanup = () => {
        // PDFKit exposes `destroy` on newer versions; fall back to `end`
        // so we never leak the underlying writable.
        const anyDoc = doc as unknown as { destroy?: () => void };
        try {
          if (typeof anyDoc.destroy === 'function') anyDoc.destroy();
          else doc.end();
        } catch {
          // best-effort — already torn down
        }
      };
      if (out) {
        // Invoice loaded successfully and we're about to write bytes —
        // let the caller flip the response headers from default JSON
        // into application/pdf right before the body begins.
        if (onReady) {
          try {
            onReady();
          } catch (err) {
            settled = true;
            reject(err);
            return;
          }
        }
        // Pipe straight into the response. The `finish` event on the
        // destination fires after the last chunk is flushed.
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

      const W = 515; // usable width
      const PAGE_W = 595;
      const LEFT = 40;
      const RIGHT = 555;
      const invoiceDate = formatDDMMYYYY(invoice.invoiceDate);
      // Use Prisma.Decimal for fixed-point currency formatting — invoice
      // amounts come back from Postgres as Decimal, and Number(...) for
      // values > 2^53 silently loses precision.
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
        // Unicode minus for visual parity with the spec.
        return `−${d.abs().toFixed(2)}`;
      };

      try {

      // ---------- Header: centred document title ----------
      const docTitle = documentTypeLabel(invoice.documentType);
      doc
        .fillColor('#111827')
        .font('Helvetica-Bold')
        .fontSize(18)
        .text(docTitle, LEFT, 40, { width: W, align: 'center' });

      // Triplet on the right, small grey.
      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#6B7280')
        .text('Original for Recipient', LEFT, 40, { width: W, align: 'right' })
        .text('Duplicate for Transporter', LEFT, 50, { width: W, align: 'right' })
        .text('Triplicate for Supplier', LEFT, 60, { width: W, align: 'right' });

      doc.fillColor('#111827');
      doc.moveTo(LEFT, 78).lineTo(RIGHT, 78).strokeColor('#9CA3AF').lineWidth(1).stroke();

      // ---------- Shop block (left) + Counterparty block (right) ----------
      const blocksY = 88;
      const colW = (W - 20) / 2; // 20px gutter
      const leftX = LEFT;
      const rightX = LEFT + colW + 20;

      // Shop block.
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

      // Counterparty block.
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

      // ---------- Meta strip ----------
      let y = Math.max(shopBlockBottom, cpBlockBottom) + 12;
      doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor('#E5E7EB').lineWidth(0.7).stroke();
      y += 6;

      const posStateName = stateNameFromCode(invoice.placeOfSupplyStateCode);
      const placeOfSupply = invoice.placeOfSupplyStateCode
        ? `${invoice.placeOfSupplyStateCode}${posStateName ? ` - ${posStateName}` : ''}`
        : '-';

      doc.fillColor('#111827').font('Helvetica').fontSize(9);
      // Place of supply only means something under GST, and it printed a bare
      // "-" whenever the state was unknown — omit it in both cases. The strip
      // divides by the fields it actually has, so it stays evenly spread.
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

      // GST-2 (Rule 53) — second meta row carrying the original tax invoice's
      // number + date that this credit/debit note adjusts.
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

      // ---------- Items table ----------
      const isInter = invoice.isInterstate;
      // Column layout — Sr | Item/SKU | HSN | Qty | Rate | Disc | Taxable |
      // GST% | <tax cols...> | Total, with the HSN and GST groups dropped
      // outright when they don't apply. Widths are tuned so the kept columns
      // always re-sum to W=515; the item column absorbs whatever is freed.
      // Without GST the per-line "Taxable" column is just the line total
      // again, so it travels with the tax columns.
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
      // Build cumulative x positions.
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }

      const align = itemCols.align;

      // Header row.
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
          // Repaint header on continuation pages.
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

      // ---------- HSN summary (skip rows with null hsn) ----------
      // The summary exists for GSTR-1, so it is skipped entirely on a
      // document that charges no tax.
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
        // Columns: HSN | Taxable | (IGST | CGST | SGST) | Cess | Total Tax
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

      // ---------- Totals block (right side) ----------
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

      // Total discount = header discount + sum of line discounts.
      let lineDiscount = new D(0);
      for (const it of invoice.items) lineDiscount = lineDiscount.add(new D(it.discount.toString()));
      const totalDiscount = new D(invoice.discount.toString()).add(lineDiscount);

      totRow('Subtotal', currencyFmt(invoice.subtotal));
      if (totalDiscount.gt(0)) totRow('Total Discount', `- ${currencyFmt(totalDiscount)}`);
      // "Taxable Value" is a GST term of art, and without tax it just repeats
      // the discounted subtotal — so it travels with the tax rows.
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

      // ---------- Statutory declarations ----------
      // Rule 46(p): a tax invoice must state whether tax is payable on
      // reverse charge. Rule 49 / Rule 5(g): a Bill of Supply must declare
      // that the supplier is not authorised to collect tax (unregistered or
      // composition). These are mandatory document elements.
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
          // GST-8 / Rule 46(p): a tax invoice MUST state whether tax is payable
          // on reverse charge — a wrong "No" on an actual RCM supply is a false
          // statutory declaration. Source it from the invoice's `reverseCharge`
          // flag rather than hard-coding "No". The column is read defensively
          // (it is added by a follow-up migration; until then it is undefined
          // and we render the safe default "No" for the forward-charge case,
          // which is correct for every invoice this engine currently mints).
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

      // ---------- Payment QR + Supplier signature band ----------
      // GST-3 — the supplier signature block and the UPI *payment* QR share a
      // horizontal band but are visually and semantically separate: the QR on
      // the LEFT is a UPI pay-link (explicitly labelled "Scan to pay"), and the
      // signature block on the RIGHT is the Rule 46(q) authorised-signatory
      // attestation. The UPI QR is NEVER presented as an e-invoice IRN/QR — IRP
      // e-invoice (IRN + signed QR) integration is a separate, documented TODO.
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

      // Supplier signature block — right-aligned, on the same band as the QR
      // when one is present, otherwise starting fresh. "For <Shop>" + a signing
      // line + "Authorised Signatory". An uploaded signature image is rendered
      // above the line when the owner has one configured (hook below); until
      // that field exists the block degrades to the line + label only.
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

        // Optional uploaded signature image hook. `signatureUrl` is not yet a
        // column on the owner row; when added (a Buffer/data-URI fetched into
        // `signatureImage`) it can be drawn here. Left intentionally inert so
        // the block renders cleanly today.
        const signatureImage: Buffer | null = null;
        const lineY = sigY + 46;
        if (signatureImage) {
          try {
            doc.image(signatureImage, sigX + sigW - 120, sigY + 12, { width: 120, height: 32 });
          } catch {
            // never let a bad signature image break the document
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

      // ---------- Footer with page numbers ----------
      // PDFKit exposes `bufferedPageRange` so we can iterate after all
      // content is laid down.
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
      // PDFKit doesn't expose PAGE_W on the doc directly; use the constant
      // so type-checking stays happy without dipping into private fields.
      void PAGE_W;

        doc.end();
      } catch (err) {
        // Synchronous throw inside the PDFKit pipeline — clean up the
        // writable, otherwise it sits open waiting for `end`.
        if (!settled) {
          settled = true;
          cleanup();
          reject(err);
        }
      }
    });
}

/// Whether this invoice may print GST and HSN at all.
///
/// A merchant who isn't GST-registered (or whose registration starts after
/// this invoice's own date) charges nothing, so the GST%, tax and HSN-summary
/// blocks would print `0.00` down the page — and an empty tax column on a bill
/// reads as a claim that tax was accounted for. Same for HSN: a column of
/// dashes is worse than no column, so it is dropped unless at least one line
/// actually carries a code.
///
/// `hasTaxFigures` is the safety net, and it is load-bearing. A shop can set
/// or move `gstEffectiveFrom` *after* issuing invoices, and the registration
/// gate alone would then hide the tax columns on a document that genuinely
/// charged tax — leaving its totals visibly not adding up. What the invoice
/// actually recorded always wins over what the shop's profile says today.
///
/// PURCHASE documents record the *vendor's* output tax, so our own
/// registration is irrelevant there — only whether tax was charged to us.
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

/// "TAX_INVOICE" → "TAX INVOICE", etc. Defaults to the underscored value
/// upper-cased and spaced so future document types still render readably.
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

/// A "Scan to pay" QR only makes sense while money is still owed — once
/// receipts allocated against the invoice cover its total, showing a
/// payment QR on an already-settled invoice would prompt the customer to
/// pay twice. Mirrors the outstanding calc in `payments.service.ts`.
async function hasOutstandingBalance(shopId: number, invoiceId: number, total: Prisma.Decimal): Promise<boolean> {
  const allocated = await prisma.payment.aggregate({
    where: { invoiceId, shopId, voidedAt: null },
    _sum: { amount: true },
  });
  const applied = new Prisma.Decimal(allocated._sum.amount?.toString() ?? '0');
  return total.minus(applied).gt(0);
}

/// Compose a one-line address "addr, city, state - pin", skipping empties.
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

/// DD/MM/YYYY — Indian invoice convention. `toLocaleDateString('en-IN')`
/// is locale-sensitive across Node versions; we hand-format to keep it stable.
function formatDDMMYYYY(d: Date | string): string {
  const dt = d instanceof Date ? d : new Date(d);
  const dd = String(dt.getDate()).padStart(2, '0');
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const yy = dt.getFullYear();
  return `${dd}/${mm}/${yy}`;
}

/// Converts PDFKit-style absolute point widths into percentages summing to
/// 100 — the react-pdf engine's tables are percentage-based. A ~3-line pure
/// function, duplicated per-renderer rather than reached for across the
/// CJS/ESM boundary (same convention as `pctWidths` in `shared/pdf/model.ts`).
function pct(points: number[]): number[] {
  const total = points.reduce((a, b) => a + b, 0);
  return points.map((p) => (p / total) * 100);
}

/// Builds the doc-kind-agnostic `PdfDocumentModel` (see `shared/pdf/model.ts`)
/// from the same invoice query the PDFKit path uses, then renders it through
/// the shop's chosen template. This is the default path — see the
/// `PDF_ENGINE=pdfkit` dispatcher above for the rollback.
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
          // Drives whether the GST columns print at all — see
          // `invoiceGstVisibility`.
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

  // Without GST the per-line "Taxable" column is just the line total again —
  // drop it with the rest of the tax columns rather than printing the same
  // number twice.
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
  // "Taxable Value" is a GST term of art, and without tax it just repeats the
  // discounted subtotal — so it travels with the tax rows.
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
    // Place of supply only means something under GST, and it printed a bare
    // "-" whenever the state was unknown — omit it in both cases.
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
    // The HSN summary is a tax table (it exists for GSTR-1) — pointless on a
    // document that charges none.
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
