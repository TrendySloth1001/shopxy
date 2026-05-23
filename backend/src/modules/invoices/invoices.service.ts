import prisma from '../../infra/db/prisma.js';
import PDFDocument from 'pdfkit';
import { Prisma } from '@prisma/client';
import QRCode from 'qrcode';
import { ledgerService } from '../ledger/ledger.service.js';
import { nextInvoiceNo } from '../../shared/numbering/sequences.js';
import { isInterstateSupply, stateNameFromCode } from '../../shared/validation/indian.js';
import { amountInWords } from '../../shared/numbering/amount_in_words.js';

type InvoiceType = 'SALE' | 'PURCHASE';
type InvoiceStatus = 'DRAFT' | 'CONFIRMED' | 'CANCELLED';

type DocumentType =
  | 'TAX_INVOICE'
  | 'BILL_OF_SUPPLY'
  | 'ESTIMATE'
  | 'PROFORMA'
  | 'CREDIT_NOTE'
  | 'DEBIT_NOTE';

interface InvoiceItemInput {
  productId: number;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  cessRate?: number;
  discount?: number;
}

export class InvoicesService {
  async createInvoice(data: {
    type: InvoiceType;
    documentType?: DocumentType;
    placeOfSupplyStateCode?: string;
    vendorId?: number;
    partyId?: number;
    customerName?: string;
    customerPhone?: string;
    customerGstin?: string;
    discount?: number;
    note?: string;
    invoiceDate?: string;
    items: InvoiceItemInput[];
  }) {
    if (data.items.length === 0) {
      return { error: 'Invoice must have at least one item' as const };
    }

    const documentType: DocumentType = data.documentType ?? 'TAX_INVOICE';

    let partyId: number | null = null;
    let customerName = data.customerName ?? null;
    let customerPhone = data.customerPhone ?? null;
    let customerGstin = data.customerGstin ?? null;
    // Address snapshot. Filled from the party row below; left null when an
    // ad-hoc walk-in is invoiced without a party.
    let customerAddress: string | null = null;
    let customerCity: string | null = null;
    let customerState: string | null = null;
    let customerStateCode: string | null = null;
    let customerPinCode: string | null = null;
    let customerPanNumber: string | null = null;

    let vendorName: string | null = null;
    let vendorPhone: string | null = null;
    let vendorGstin: string | null = null;
    let vendorAddress: string | null = null;
    let vendorCity: string | null = null;
    let vendorState: string | null = null;
    let vendorStateCode: string | null = null;
    let vendorPinCode: string | null = null;
    let vendorPanNumber: string | null = null;

    if (data.partyId) {
      const party = await prisma.party.findUnique({
        where: { id: data.partyId },
        select: {
          id: true, name: true, phone: true, gstin: true, isActive: true,
          address: true, city: true, state: true, stateCode: true,
          pinCode: true, panNumber: true,
        },
      });
      if (!party) return { error: 'Party not found' as const };
      if (!party.isActive) return { error: 'Party is inactive' as const };
      partyId = party.id;
      customerName = customerName ?? party.name;
      customerPhone = customerPhone ?? party.phone ?? null;
      customerGstin = customerGstin ?? party.gstin ?? null;
      customerAddress = party.address ?? null;
      customerCity = party.city ?? null;
      customerState = party.state ?? null;
      customerStateCode = party.stateCode ?? null;
      customerPinCode = party.pinCode ?? null;
      customerPanNumber = party.panNumber ?? null;
    }

    if (data.vendorId) {
      const vendor = await prisma.vendor.findUnique({
        where: { id: data.vendorId },
        select: {
          id: true, name: true, phone: true, gstin: true, isActive: true,
          address: true, city: true, state: true, stateCode: true,
          pinCode: true, panNumber: true,
        },
      });
      if (!vendor) return { error: 'Vendor not found' as const };
      if (!vendor.isActive) return { error: 'Vendor is inactive' as const };
      vendorName = vendor.name;
      vendorPhone = vendor.phone ?? null;
      vendorGstin = vendor.gstin ?? null;
      vendorAddress = vendor.address ?? null;
      vendorCity = vendor.city ?? null;
      vendorState = vendor.state ?? null;
      vendorStateCode = vendor.stateCode ?? null;
      vendorPinCode = vendor.pinCode ?? null;
      vendorPanNumber = vendor.panNumber ?? null;
    }

    // Shop owner identity drives IGST vs CGST+SGST. Cached once per call so
    // we don't re-query inside the per-line loop.
    const shopOwner = await prisma.user.findFirst({
      where: { role: 'OWNER', isActive: true },
      select: { shopStateCode: true },
    });
    const shopStateCode = shopOwner?.shopStateCode ?? null;

    // For SALE: place of supply defaults to the customer's state code. For
    // PURCHASE: it defaults to the shop owner's state code (we are the
    // recipient). Either way: when shop and place-of-supply state codes
    // disagree we charge IGST; otherwise CGST+SGST.
    const placeOfSupplyStateCode =
      data.placeOfSupplyStateCode ??
      (data.type === 'SALE' ? customerStateCode : shopStateCode) ??
      null;
    const isInterstate = isInterstateSupply(shopStateCode, placeOfSupplyStateCode);

    // Resolve products for snapshots
    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, name: true, sku: true, hsnCode: true, unit: true, stockQuantity: true },
    });

    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    // Per-line GST split — IGST or (CGST+SGST), plus optional cess.
    // We round per-component to two decimals so the values stored agree
    // with what would be re-computed by the printed PDF.
    let subtotal = 0;
    let taxableValueTotal = 0;
    let igstTotal = 0;
    let cgstTotal = 0;
    let sgstTotal = 0;
    let cessTotal = 0;
    const headerDiscount = data.discount ?? 0;

    const itemsData = data.items.map((item) => {
      const product = productMap.get(item.productId)!;
      const taxPct = item.taxPercent ?? 0;
      const cessRate = item.cessRate ?? 0;
      const itemDiscount = item.discount ?? 0;
      const taxableValue = this.round2(item.quantity * item.unitPrice - itemDiscount);

      let igstAmount = 0;
      let cgstAmount = 0;
      let sgstAmount = 0;
      if (isInterstate) {
        igstAmount = this.round2((taxableValue * taxPct) / 100);
      } else {
        // Compute the GST total first, then split, so CGST+SGST always
        // re-sum to that total (avoids one-paisa drift from independent
        // rounding of each half).
        const gstTotal = this.round2((taxableValue * taxPct) / 100);
        cgstAmount = this.round2(gstTotal / 2);
        sgstAmount = this.round2(gstTotal - cgstAmount);
      }
      const cessAmount = this.round2((taxableValue * cessRate) / 100);
      const lineTotal = this.round2(
        taxableValue + igstAmount + cgstAmount + sgstAmount + cessAmount,
      );

      subtotal += taxableValue;
      taxableValueTotal += taxableValue;
      igstTotal += igstAmount;
      cgstTotal += cgstAmount;
      sgstTotal += sgstAmount;
      cessTotal += cessAmount;

      return {
        productId: item.productId,
        productName: product.name,
        productSku: product.sku,
        hsn: product.hsnCode ?? undefined,
        unit: product.unit,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        taxPercent: taxPct,
        discount: itemDiscount,
        taxableValue,
        igstAmount,
        cgstAmount,
        sgstAmount,
        cessRate,
        cessAmount,
        total: lineTotal,
      };
    });

    const taxAmount = this.round2(igstTotal + cgstTotal + sgstTotal + cessTotal);
    // Apply the header-level discount against the taxable value before
    // computing the round-off so we still finish on a whole rupee.
    const grandTotalRaw = this.round2(
      taxableValueTotal + taxAmount - headerDiscount,
    );
    const roundOff = this.round2(Math.round(grandTotalRaw) - grandTotalRaw);
    const total = this.round2(grandTotalRaw + roundOff);
    const words = amountInWords(total);
    const invoiceDate = data.invoiceDate ? new Date(data.invoiceDate) : new Date();
    const { invoiceNo, financialYear } = await nextInvoiceNo(
      data.type,
      documentType,
      invoiceDate,
    );

    // Header + line items must materialise together. Even though Prisma's
    // nested create is already atomic at the row level, wrapping the
    // whole flow in $transaction makes the boundary explicit and gives
    // us a place to hang future per-create ledger posts (e.g. auto-
    // confirm) without re-architecting.
    const invoice = await prisma.$transaction(async (tx) => {
      return tx.invoice.create({
        data: {
          invoiceNo,
          financialYear,
          documentType,
          type: data.type,
          vendorId: data.vendorId ?? null,
          partyId,
          customerName,
          customerPhone,
          customerGstin,
          customerAddress,
          customerCity,
          customerState,
          customerStateCode,
          customerPinCode,
          customerPanNumber,
          vendorName,
          vendorPhone,
          vendorGstin,
          vendorAddress,
          vendorCity,
          vendorState,
          vendorStateCode,
          vendorPinCode,
          vendorPanNumber,
          placeOfSupplyStateCode,
          isInterstate,
          subtotal: this.round2(subtotal),
          taxableValue: this.round2(taxableValueTotal),
          taxAmount,
          igstAmount: this.round2(igstTotal),
          cgstAmount: this.round2(cgstTotal),
          sgstAmount: this.round2(sgstTotal),
          cessAmount: this.round2(cessTotal),
          discount: headerDiscount,
          roundOff,
          total,
          amountInWords: words,
          note: data.note ?? null,
          invoiceDate,
          items: { create: itemsData },
        },
        include: { items: true, vendor: true, party: true },
      });
    });

    return { invoice };
  }

  async listInvoices(options: {
    type?: string;
    status?: string;
    documentType?: string;
    vendorId?: number;
    partyId?: number;
    search: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
    if (options.type) where.type = options.type;
    if (options.status) where.status = options.status;
    if (options.documentType) where.documentType = options.documentType;
    if (options.vendorId) where.vendorId = options.vendorId;
    if (options.partyId) where.partyId = options.partyId;
    if (options.search) {
      where.OR = [
        { invoiceNo: { contains: options.search, mode: 'insensitive' } },
        { customerName: { contains: options.search, mode: 'insensitive' } },
        { customerPhone: { contains: options.search, mode: 'insensitive' } },
      ];
    }

    const [invoices, total] = await Promise.all([
      prisma.invoice.findMany({
        where,
        orderBy: { invoiceDate: 'desc' },
        skip: options.skip,
        take: options.limit,
        select: {
          id: true,
          invoiceNo: true,
          documentType: true,
          financialYear: true,
          type: true,
          status: true,
          customerName: true,
          customerPhone: true,
          customerGstin: true,
          customerAddress: true,
          customerCity: true,
          customerState: true,
          customerStateCode: true,
          customerPinCode: true,
          customerPanNumber: true,
          vendorName: true,
          vendorPhone: true,
          vendorGstin: true,
          vendorAddress: true,
          vendorCity: true,
          vendorState: true,
          vendorStateCode: true,
          vendorPinCode: true,
          vendorPanNumber: true,
          placeOfSupplyStateCode: true,
          isInterstate: true,
          subtotal: true,
          taxableValue: true,
          taxAmount: true,
          igstAmount: true,
          cgstAmount: true,
          sgstAmount: true,
          cessAmount: true,
          discount: true,
          roundOff: true,
          total: true,
          amountInWords: true,
          note: true,
          invoiceDate: true,
          createdAt: true,
          updatedAt: true,
          vendor: { select: { id: true, name: true } },
          party: { select: { id: true, name: true } },
          _count: { select: { items: true } },
        },
      }),
      prisma.invoice.count({ where }),
    ]);

    return { invoices, total };
  }

  async getInvoiceById(id: number) {
    return prisma.invoice.findUnique({
      where: { id },
      include: {
        vendor: true,
        party: true,
        items: {
          orderBy: { id: 'asc' },
        },
      },
    });
  }

  async updateStatus(id: number, status: InvoiceStatus, createdById?: number) {
    // Wrap header read + ledger work + status update in one transaction
    // so a half-confirm (stock moved, status not flipped) or half-cancel
    // (status flipped, reversal not posted) is impossible.
    return prisma.$transaction(async (tx) => {
      const invoice = await tx.invoice.findUnique({
        where: { id },
        include: { items: true, vendor: true, party: true, challan: { select: { id: true } } },
      });
      if (!invoice) return { error: 'Invoice not found' as const };

      // Cannot re-confirm or un-cancel
      if (invoice.status === 'CANCELLED') {
        return { error: 'Cannot update a cancelled invoice' as const };
      }
      if (invoice.status === status) {
        return { invoice };
      }

      // If this invoice was converted from a challan, the challan already
      // posted the stock movement at create time. The invoice should not
      // re-post on confirm or reverse on its own cancel — the challan is
      // the source of truth for those rows.
      const ledgerOwnedByChallan = invoice.challan !== null;

      // Refuse to cancel a challan-sourced invoice — the inventory effect
      // sits on the challan, so cancelling the invoice in isolation leaves
      // a "cancelled" invoice attached to a "converted" challan with goods
      // still considered shipped. Force the user to cancel the challan
      // instead, which will reverse the ledger correctly.
      if (ledgerOwnedByChallan && status === 'CANCELLED' && invoice.status === 'CONFIRMED') {
        return {
          error: 'Cancel the linked challan instead — this invoice is its bill.' as const,
        };
      }

      // ── DRAFT → CONFIRMED: post stock movements ────────────────────
      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && !ledgerOwnedByChallan) {
        const direction = invoice.type === 'SALE' ? 'OUT' : 'IN';
        const reasonCode = invoice.type === 'SALE' ? 'SALE' : 'PURCHASE';
        const counterpartyName =
          invoice.type === 'SALE'
            ? invoice.customerName ?? invoice.party?.name ?? null
            : invoice.vendorName ?? invoice.vendor?.name ?? null;
        const counterpartyGstin =
          invoice.type === 'SALE'
            ? invoice.customerGstin ?? invoice.party?.gstin ?? null
            : invoice.vendorGstin ?? invoice.vendor?.gstin ?? null;
        const result = await ledgerService.post({
          direction,
          reasonCode,
          sourceType: 'INVOICE',
          sourceId: invoice.id,
          idempotencyKey: `INVOICE:${invoice.id}:CONFIRM`,
          vendorId: invoice.vendorId ?? undefined,
          counterpartyName: counterpartyName ?? undefined,
          counterpartyGstin: counterpartyGstin ?? undefined,
          createdById,
          note: `Invoice ${invoice.invoiceNo}`,
          lines: invoice.items.map((it) => ({
            productId: it.productId,
            quantity: Number(it.quantity),
            unitPrice: direction === 'IN' ? Number(it.unitPrice) : undefined,
            sourceLineId: it.id,
          })),
        }, tx);
        if ('error' in result) {
          if (result.error === 'Insufficient stock') {
            return {
              error: 'Insufficient stock for one or more items' as const,
              productId: result.productId,
              available: result.available,
              requested: result.requested,
            };
          }
          return { error: result.error as string };
        }
      }

      // ── CONFIRMED → CANCELLED: reverse ledger rows ─────────────────
      if (invoice.status === 'CONFIRMED' && status === 'CANCELLED' && !ledgerOwnedByChallan) {
        const entries = await tx.stockTransaction.findMany({
          where: { sourceType: 'INVOICE', sourceId: invoice.id, reversesId: null },
          select: { id: true },
        });
        for (const entry of entries) {
          const result = await ledgerService.reverse(entry.id, {
            reasonCode: invoice.type === 'SALE' ? 'RETURN_IN' : 'RETURN_OUT',
            sourceType: 'INVOICE',
            sourceId: invoice.id,
            createdById,
            note: `Cancellation of ${invoice.invoiceNo}`,
          }, tx);
          if ('error' in result) {
            return { error: `Reversal failed: ${result.error}` as const };
          }
        }
      }

      const updated = await tx.invoice.update({
        where: { id },
        data: { status },
        include: { vendor: true, party: true, items: true },
      });
      return { invoice: updated };
    });
  }

  /// Convert an ESTIMATE / PROFORMA quotation into a real TAX_INVOICE.
  /// Reuses createInvoice so numbering, GST split and ledger semantics
  /// all stay funnelled through one code path — the new invoice gets its
  /// own INV-prefixed number while the source row remains untouched as
  /// historical reference.
  async convertEstimate(invoiceId: number) {
    const source = await prisma.invoice.findUnique({
      where: { id: invoiceId },
      include: { items: true },
    });
    if (!source) return { error: 'Invoice not found' as const };
    if (source.documentType !== 'ESTIMATE' && source.documentType !== 'PROFORMA') {
      return { error: 'Only estimates or proforma invoices can be converted' as const };
    }
    if (source.status === 'CANCELLED') {
      return { error: 'Cannot convert a cancelled estimate' as const };
    }

    return this.createInvoice({
      type: source.type as InvoiceType,
      documentType: 'TAX_INVOICE',
      placeOfSupplyStateCode: source.placeOfSupplyStateCode ?? undefined,
      vendorId: source.vendorId ?? undefined,
      partyId: source.partyId ?? undefined,
      customerName: source.customerName ?? undefined,
      customerPhone: source.customerPhone ?? undefined,
      customerGstin: source.customerGstin ?? undefined,
      discount: Number(source.discount),
      note: source.note ?? undefined,
      items: source.items.map((it) => ({
        productId: it.productId,
        quantity: Number(it.quantity),
        unitPrice: Number(it.unitPrice),
        taxPercent: Number(it.taxPercent),
        cessRate: Number(it.cessRate),
        discount: Number(it.discount),
      })),
    });
  }

  async deleteInvoice(id: number) {
    const invoice = await prisma.invoice.findUnique({ where: { id }, select: { status: true } });
    if (!invoice) return { error: 'Invoice not found' as const };
    if (invoice.status === 'CONFIRMED') {
      return { error: 'Cannot delete a confirmed invoice. Cancel it first.' as const };
    }
    await prisma.invoice.delete({ where: { id } });
    return { ok: true };
  }

  async generatePdf(id: number): Promise<Buffer | { error: string }> {
    const invoice = await prisma.invoice.findUnique({
      where: { id },
      include: { vendor: true, party: true, items: { orderBy: { id: 'asc' } } },
    });

    if (!invoice) return { error: 'Invoice not found' };

    // Shop owner row — drives header block + UPI QR.
    const owner = await prisma.user.findFirst({
      where: { role: 'OWNER', isActive: true },
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
    });

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

    return new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
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
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => {
        if (settled) return;
        settled = true;
        resolve(Buffer.concat(chunks));
      });
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

      // ---------- UPI QR (if applicable) ----------
      if (upiQr) {
        if (y + 140 > 770) { doc.addPage(); y = 40; }
        doc.image(upiQr.buffer, LEFT, y, { width: 110 });
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#374151')
          .text('Scan to pay with any UPI app', LEFT, y + 114, { width: 140 });
        if (owner?.upiVpa) {
          doc.fontSize(8).fillColor('#6B7280').text(`UPI: ${owner.upiVpa}`, LEFT, y + 126, { width: 200 });
        }
        y += 140;
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

  private round2(v: number): number {
    return Math.round((v + Number.EPSILON) * 100) / 100;
  }
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

export const invoicesService = new InvoicesService();
