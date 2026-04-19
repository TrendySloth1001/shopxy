import prisma from '../../infra/db/prisma.js';
import PDFDocument from 'pdfkit';

type InvoiceType = 'SALE' | 'PURCHASE';
type InvoiceStatus = 'DRAFT' | 'CONFIRMED' | 'CANCELLED';

interface InvoiceItemInput {
  productId: number;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  discount?: number;
}

export class InvoicesService {
  async createInvoice(data: {
    type: InvoiceType;
    vendorId?: number;
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

    // Compute totals
    let subtotal = 0;
    let taxAmount = 0;
    const headerDiscount = data.discount ?? 0;

    const itemsData = data.items.map((item) => {
      const product = productMap.get(item.productId)!;
      const taxPct = item.taxPercent ?? 0;
      const itemDiscount = item.discount ?? 0;
      const base = item.quantity * item.unitPrice - itemDiscount;
      const tax = (base * taxPct) / 100;
      const total = base + tax;
      subtotal += base;
      taxAmount += tax;
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
        total: this.round2(total),
      };
    });

    const total = this.round2(subtotal + taxAmount - headerDiscount);
    const invoiceNo = await this.nextInvoiceNo(data.type);

    const invoice = await prisma.invoice.create({
      data: {
        invoiceNo,
        type: data.type,
        vendorId: data.vendorId ?? null,
        customerName: data.customerName ?? null,
        customerPhone: data.customerPhone ?? null,
        customerGstin: data.customerGstin ?? null,
        subtotal: this.round2(subtotal),
        taxAmount: this.round2(taxAmount),
        discount: headerDiscount,
        total,
        note: data.note ?? null,
        invoiceDate: data.invoiceDate ? new Date(data.invoiceDate) : new Date(),
        items: { create: itemsData },
      },
      include: { items: true, vendor: true },
    });

    return { invoice };
  }

  async listInvoices(options: {
    type?: string;
    status?: string;
    vendorId?: number;
    search: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};
    if (options.type) where.type = options.type;
    if (options.status) where.status = options.status;
    if (options.vendorId) where.vendorId = options.vendorId;
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
          type: true,
          status: true,
          customerName: true,
          customerPhone: true,
          subtotal: true,
          taxAmount: true,
          discount: true,
          total: true,
          invoiceDate: true,
          createdAt: true,
          vendor: { select: { id: true, name: true } },
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
        items: {
          orderBy: { id: 'asc' },
        },
      },
    });
  }

  async updateStatus(id: number, status: InvoiceStatus) {
    const invoice = await prisma.invoice.findUnique({ where: { id }, select: { status: true } });
    if (!invoice) return { error: 'Invoice not found' as const };

    // Cannot re-confirm or un-cancel
    if (invoice.status === 'CANCELLED') {
      return { error: 'Cannot update a cancelled invoice' as const };
    }

    const updated = await prisma.invoice.update({
      where: { id },
      data: { status },
      include: { vendor: true, items: true },
    });
    return { invoice: updated };
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
      include: { vendor: true, items: { orderBy: { id: 'asc' } } },
    });

    if (!invoice) return { error: 'Invoice not found' };

    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 515; // usable width
      const invoiceDate = new Date(invoice.invoiceDate).toLocaleDateString('en-IN');
      const currencyFmt = (n: unknown) => `Rs. ${Number(n).toFixed(2)}`;

      // Header
      doc
        .fontSize(20)
        .font('Helvetica-Bold')
        .text('SHOPXY', 40, 40)
        .fontSize(9)
        .font('Helvetica')
        .text('Smart Inventory Management', 40, 65);

      const typeLabel = invoice.type === 'SALE' ? 'TAX INVOICE' : 'PURCHASE INVOICE';
      doc
        .fontSize(14)
        .font('Helvetica-Bold')
        .text(typeLabel, 40, 40, { align: 'right' })
        .fontSize(9)
        .font('Helvetica')
        .text(`Invoice No: ${invoice.invoiceNo}`, 40, 60, { align: 'right' })
        .text(`Date: ${invoiceDate}`, 40, 75, { align: 'right' })
        .text(`Status: ${invoice.status}`, 40, 90, { align: 'right' });

      doc.moveTo(40, 110).lineTo(555, 110).strokeColor('#E5E7EB').lineWidth(1).stroke();

      // Party info
      let y = 125;
      if (invoice.type === 'SALE') {
        if (invoice.customerName) {
          doc.fontSize(9).font('Helvetica-Bold').text('Bill To:', 40, y);
          doc.font('Helvetica').text(invoice.customerName, 40, y + 12);
          if (invoice.customerPhone) doc.text(`Phone: ${invoice.customerPhone}`, 40, y + 24);
          if (invoice.customerGstin) doc.text(`GSTIN: ${invoice.customerGstin}`, 40, y + 36);
        }
      } else {
        if (invoice.vendor) {
          doc.fontSize(9).font('Helvetica-Bold').text('Vendor:', 40, y);
          doc.font('Helvetica').text(invoice.vendor.name, 40, y + 12);
          if (invoice.vendor.phone) doc.text(`Phone: ${invoice.vendor.phone}`, 40, y + 24);
          if (invoice.vendor.gstin) doc.text(`GSTIN: ${invoice.vendor.gstin}`, 40, y + 36);
        }
      }

      // Items table
      y = 200;
      const colX = [40, 180, 305, 365, 410, 460];
      const headers = ['Item / SKU', 'HSN', 'Qty', 'Rate', 'Tax%', 'Amount'];

      doc.rect(40, y, W, 18).fill('#F3F4F6');
      doc.fillColor('#111827').fontSize(8).font('Helvetica-Bold');
      headers.forEach((h, i) => doc.text(h, colX[i], y + 5, { width: colX[i + 1] ? colX[i + 1] - colX[i] - 4 : 60, align: i > 1 ? 'right' : 'left' }));

      y += 18;
      doc.font('Helvetica').fontSize(8);

      for (const item of invoice.items) {
        const rowH = 28;
        if (y + rowH > 760) {
          doc.addPage();
          y = 40;
        }
        doc.fillColor('#111827');
        const cols = [
          `${item.productName}\n${item.productSku}`,
          item.hsn ?? '-',
          `${Number(item.quantity)} ${item.unit}`,
          currencyFmt(item.unitPrice),
          `${Number(item.taxPercent)}%`,
          currencyFmt(item.total),
        ];
        cols.forEach((c, i) => {
          doc.text(c, colX[i], y + 4, { width: colX[i + 1] ? colX[i + 1] - colX[i] - 4 : 60, align: i > 1 ? 'right' : 'left' });
        });
        doc.moveTo(40, y + rowH).lineTo(555, y + rowH).strokeColor('#E5E7EB').stroke();
        y += rowH;
      }

      // Totals
      y += 10;
      const totalsX = 380;
      const totalsW = 175;
      const row = (label: string, value: string, bold = false) => {
        doc.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(9);
        doc.text(label, totalsX, y, { width: 90 });
        doc.text(value, totalsX + 90, y, { width: 85, align: 'right' });
        y += 16;
      };

      row('Subtotal', currencyFmt(invoice.subtotal));
      row('Tax', currencyFmt(invoice.taxAmount));
      if (Number(invoice.discount) > 0) row('Discount', `- ${currencyFmt(invoice.discount)}`);
      doc.moveTo(totalsX, y).lineTo(totalsX + totalsW, y).strokeColor('#9CA3AF').stroke();
      y += 4;
      row('TOTAL', currencyFmt(invoice.total), true);

      if (invoice.note) {
        y += 20;
        doc.fontSize(8).font('Helvetica-Bold').text('Notes:', 40, y);
        doc.font('Helvetica').text(invoice.note, 40, y + 12, { width: 300 });
      }

      // Footer
      doc
        .fontSize(7)
        .fillColor('#6B7280')
        .font('Helvetica')
        .text('Generated by Shopxy • This is a computer-generated document', 40, 790, { align: 'center', width: W });

      doc.end();
    });
  }

  private async nextInvoiceNo(type: InvoiceType): Promise<string> {
    const prefix = type === 'SALE' ? 'INV' : 'PUR';
    const count = await prisma.invoice.count({ where: { type } });
    const seq = String(count + 1).padStart(5, '0');
    const ym = new Date().toISOString().slice(0, 7).replace('-', '');
    return `${prefix}-${ym}-${seq}`;
  }

  private round2(v: number): number {
    return Math.round((v + Number.EPSILON) * 100) / 100;
  }
}

export const invoicesService = new InvoicesService();
