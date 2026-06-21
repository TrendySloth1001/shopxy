import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import QRCode from 'qrcode';
import prisma from '../../infra/db/prisma.js';
import { stateNameFromCode } from '../../shared/validation/indian.js';

/// Render one invoice as a PDF — to a stream when `out` is set, or to a
/// Buffer otherwise. Returns `{ error }` if the invoice can't be found
/// or doesn't belong to `shopId`. Lives in its own file because PDFKit
/// rendering is 480 lines of layout code that don't benefit from sharing
/// space with the rest of the invoice service.
export async function renderInvoicePdf(
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
            upiVpa: true,
            name: true,
            email: true,
          },
        },
      },
    });
    const owner = shopRow?.owner ?? null;

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
      total.gt(0)
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
      const metaW = W / 4;
      const metaRowY = y;
      const drawMeta = (label: string, value: string, idx: number) => {
        const x = LEFT + idx * metaW;
        doc.font('Helvetica').fontSize(7).fillColor('#6B7280').text(label.toUpperCase(), x, metaRowY, { width: metaW - 6 });
        doc.font('Helvetica-Bold').fontSize(9).fillColor('#111827').text(value, x, metaRowY + 9, { width: metaW - 6 });
      };
      drawMeta('Invoice No', invoice.invoiceNo, 0);
      drawMeta('Date', invoiceDate, 1);
      drawMeta('Place of Supply', placeOfSupply, 2);
      drawMeta('FY', invoice.financialYear, 3);
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
      // Column layout. With IGST we get 10 columns; with CGST/SGST split, 11.
      // Sr | Item/SKU | HSN | Qty | Rate | Disc | Taxable | GST% | <tax cols...> | Total
      const taxCols = isInter ? ['IGST'] : ['CGST', 'SGST'];
      const headers = ['Sr', 'Item / SKU', 'HSN', 'Qty', 'Rate', 'Disc', 'Taxable', 'GST%', ...taxCols, 'Total'];

      // Tuned widths so the row sums to W=515.
      // Sr=22, Item=120, HSN=42, Qty=38, Rate=46, Disc=38, Taxable=52, GST%=32,
      // then tax cols share remaining 65 (IGST) or 65 (CGST+SGST=64+1 padding).
      const widths: number[] = isInter
        ? [22, 120, 42, 38, 46, 38, 52, 32, 65, 60]
        : [22, 116, 40, 34, 42, 34, 50, 30, 45, 45, 57];
      // Build cumulative x positions.
      const xs: number[] = [];
      let cx = LEFT;
      for (const w of widths) { xs.push(cx); cx += w; }

      const align = (i: number): 'left' | 'right' => i <= 2 ? 'left' : 'right';

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
        const taxValues: string[] = isInter
          ? [numFmt(item.igstAmount)]
          : [numFmt(item.cgstAmount), numFmt(item.sgstAmount)];
        const row = [
          String(sr),
          `${item.productName}\n${item.productSku}`,
          item.hsn ?? '-',
          `${new D(item.quantity.toString()).toString()} ${item.unit}`,
          numFmt(item.unitPrice),
          numFmt(item.discount),
          numFmt(item.taxableValue),
          `${new D(item.taxPercent.toString()).toString()}%`,
          ...taxValues,
          numFmt(item.total),
        ];
        row.forEach((c, i) => {
          doc.text(c, xs[i] + 2, y + 4, { width: widths[i] - 4, align: align(i) });
        });
        doc.moveTo(LEFT, y + rowH).lineTo(RIGHT, y + rowH).strokeColor('#E5E7EB').stroke();
        y += rowH;
        sr += 1;
      }

      // ---------- HSN summary (skip rows with null hsn) ----------
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
      totRow('Taxable Value', currencyFmt(invoice.taxableValue));
      if (isInter) {
        totRow('IGST', currencyFmt(invoice.igstAmount));
      } else {
        totRow('CGST', currencyFmt(invoice.cgstAmount));
        totRow('SGST', currencyFmt(invoice.sgstAmount));
      }
      if (new D(invoice.cessAmount.toString()).gt(0)) totRow('Cess', currencyFmt(invoice.cessAmount));
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
          doc
            .font('Helvetica')
            .fontSize(8)
            .fillColor('#6B7280')
            .text('Tax payable on reverse charge: No', LEFT, y, { width: W });
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
