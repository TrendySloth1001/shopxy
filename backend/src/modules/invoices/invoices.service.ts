import prisma from '../../infra/db/prisma.js';
import { Prisma } from '@prisma/client';
import { Writable } from 'stream';
import { ledgerService } from '../ledger/ledger.service.js';
import { nextInvoiceNo } from '../../shared/numbering/sequences.js';
import { isInterstateSupply } from '../../shared/validation/indian.js';
import { amountInWords } from '../../shared/numbering/amount_in_words.js';
import { renderInvoicePdf } from './invoice-pdf-renderer.js';
import {
  resolveActiveProductPromos,
  lineDiscount,
} from '../banners/promo-pricing.js';

type InvoiceType = 'SALE' | 'PURCHASE';
type InvoiceStatus = 'DRAFT' | 'CONFIRMED' | 'CANCELLED';

/// Upper bound on lines per invoice. Above this the PDF generator
/// becomes a memory cliff (buffered in RAM) and the ledger transaction
/// holds row locks long enough to cascade deadlocks. 200 covers every
/// realistic Indian-SMB invoice we've encountered.
const MAX_INVOICE_LINES = 200;

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

interface ResolveInvoiceInput {
  /// Owning shop — required for every read inside `resolveInvoiceFields`
  /// (party/vendor/product lookups all scope by it).
  shopId: number;
  type: InvoiceType;
  documentType?: DocumentType;
  placeOfSupplyStateCode?: string;
  vendorId?: number | null;
  partyId?: number | null;
  customerName?: string;
  customerPhone?: string;
  customerGstin?: string;
  discount?: number;
  note?: string;
  invoiceDate?: string;
  items: InvoiceItemInput[];
}

export class InvoicesService {
  async createInvoice(data: {
    shopId: number;
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
    /// When true, the freshly-created draft is immediately confirmed
    /// (stock posted via the ledger) in a follow-up transaction. Lets
    /// the create form offer a "Save & Confirm" CTA so the merchant
    /// doesn't have to land on the draft just to confirm it.
    confirm?: boolean;
    /// Audit trail for the auto-confirm path. Forwarded to updateStatus
    /// so the ledger rows carry the same createdById they would on the
    /// manual two-step flow.
    confirmedById?: number;
  }) {
    const resolved = await this.resolveInvoiceFields(data);
    if ('error' in resolved) return resolved;

    const { header, itemsData } = resolved;
    const { invoiceNo, financialYear } = await nextInvoiceNo(
      data.shopId,
      data.type,
      header.documentType,
      header.invoiceDate,
    );

    // Wrapping in $transaction keeps the create atomic and gives us a
    // boundary for future per-create side effects (e.g. auto-confirm).
    const invoice = await prisma.$transaction(async (tx) => {
      return tx.invoice.create({
        data: {
          ...header,
          shopId: data.shopId,
          invoiceNo,
          financialYear,
          items: { create: itemsData },
        },
        include: { items: true, vendor: true, party: true },
      });
    });

    if (!data.confirm) {
      return { invoice, confirmed: false as const };
    }

    // Auto-confirm path. Reuses updateStatus so numbering, ledger and
    // idempotency stay funnelled through one code path. On failure we
    // keep the draft (the merchant can fix and confirm later) and
    // surface the error so the client can decide how to surface it.
    const confirmResult = await this.updateStatus(
      data.shopId,
      invoice.id,
      'CONFIRMED',
      data.confirmedById,
    );
    if ('error' in confirmResult) {
      return {
        invoice,
        confirmed: false as const,
        confirmError: confirmResult,
      };
    }
    return { invoice: confirmResult.invoice, confirmed: true as const };
  }

  /// Pure resolution step shared by create + update: party/vendor look-ups,
  /// product snapshots, GST split and total calculation. Returns either an
  /// `error` or the ready-to-write header + items payload.
  ///
  /// Query budget: ≤ 4 statements (party + vendor + shop owner + products),
  /// each one bounded — no per-item round trips.
  private async resolveInvoiceFields(data: ResolveInvoiceInput): Promise<
    | { error: string }
    | {
        header: {
          documentType: DocumentType;
          type: InvoiceType;
          vendorId: number | null;
          partyId: number | null;
          customerName: string | null;
          customerPhone: string | null;
          customerGstin: string | null;
          customerAddress: string | null;
          customerCity: string | null;
          customerState: string | null;
          customerStateCode: string | null;
          customerPinCode: string | null;
          customerPanNumber: string | null;
          vendorName: string | null;
          vendorPhone: string | null;
          vendorGstin: string | null;
          vendorAddress: string | null;
          vendorCity: string | null;
          vendorState: string | null;
          vendorStateCode: string | null;
          vendorPinCode: string | null;
          vendorPanNumber: string | null;
          placeOfSupplyStateCode: string | null;
          isInterstate: boolean;
          subtotal: number;
          taxableValue: number;
          taxAmount: number;
          igstAmount: number;
          cgstAmount: number;
          sgstAmount: number;
          cessAmount: number;
          discount: number;
          roundOff: number;
          total: number;
          amountInWords: string;
          note: string | null;
          invoiceDate: Date;
        };
        itemsData: Array<{
          productId: number;
          productName: string;
          productSku: string;
          hsn: string | undefined;
          unit: string;
          quantity: number;
          unitPrice: number;
          taxPercent: number;
          discount: number;
          taxableValue: number;
          igstAmount: number;
          cgstAmount: number;
          sgstAmount: number;
          cessRate: number;
          cessAmount: number;
          total: number;
        }>;
      }
  > {
    if (data.items.length === 0) {
      return { error: 'Invoice must have at least one item' as const };
    }
    // Hard cap on line count. The PDF generator buffers the whole
    // document in memory; an attacker submitting a 5000-line invoice
    // could OOM the worker on PDF generation. 200 lines covers any
    // realistic invoice (the longest legitimate documents we see in
    // the wild are < 150 lines).
    if (data.items.length > MAX_INVOICE_LINES) {
      return {
        error: `Invoice exceeds maximum ${MAX_INVOICE_LINES} lines` as const,
      };
    }
    const documentType: DocumentType = data.documentType ?? 'TAX_INVOICE';

    let partyId: number | null = null;
    let customerName = data.customerName ?? null;
    let customerPhone = data.customerPhone ?? null;
    let customerGstin = data.customerGstin ?? null;
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
      const party = await prisma.party.findFirst({
        where: { id: data.partyId, shopId: data.shopId },
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

    let resolvedVendorId: number | null = null;
    if (data.vendorId) {
      const vendor = await prisma.vendor.findFirst({
        where: { id: data.vendorId, shopId: data.shopId },
        select: {
          id: true, name: true, phone: true, gstin: true, isActive: true,
          address: true, city: true, state: true, stateCode: true,
          pinCode: true, panNumber: true,
        },
      });
      if (!vendor) return { error: 'Vendor not found' as const };
      if (!vendor.isActive) return { error: 'Vendor is inactive' as const };
      resolvedVendorId = vendor.id;
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

    // Shop owner identity drives IGST vs CGST+SGST. Looked up from the
    // owning Shop's owner User row, not the global "first OWNER" — that
    // pre-multi-tenant query went to whichever merchant was alphabetically
    // first and was the cause of cross-tenant invoice corruption.
    const shop = await prisma.shop.findUnique({
      where: { id: data.shopId },
      select: { owner: { select: { shopStateCode: true } } },
    });
    const shopStateCode = shop?.owner.shopStateCode ?? null;

    const placeOfSupplyStateCode =
      data.placeOfSupplyStateCode ??
      (data.type === 'SALE' ? customerStateCode : shopStateCode) ??
      null;
    const isInterstate = isInterstateSupply(shopStateCode, placeOfSupplyStateCode);

    // One findMany regardless of item count — no per-line lookups.
    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds }, shopId: data.shopId },
      select: { id: true, name: true, sku: true, hsnCode: true, unit: true, stockQuantity: true },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    // Carousel-promo auto-fill: any line where the merchant didn't type
    // a discount inherits the best currently-active promo for that
    // product. Explicit values (including 0) always win — typing zero is
    // a clear "no discount" intent that should not be overridden.
    const promos = await resolveActiveProductPromos(data.shopId, productIds);

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
      let itemDiscount: number;
      if (item.discount !== undefined) {
        itemDiscount = item.discount;
      } else {
        const promo = promos.get(item.productId);
        itemDiscount = promo
          ? lineDiscount(promo.type, promo.value, item.unitPrice, item.quantity)
          : 0;
      }
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
    const grandTotalRaw = this.round2(
      taxableValueTotal + taxAmount - headerDiscount,
    );
    const roundOff = this.round2(Math.round(grandTotalRaw) - grandTotalRaw);
    const total = this.round2(grandTotalRaw + roundOff);
    const words = amountInWords(total);
    const invoiceDate = data.invoiceDate ? new Date(data.invoiceDate) : new Date();

    return {
      header: {
        documentType,
        type: data.type,
        vendorId: resolvedVendorId,
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
      },
      itemsData,
    };
  }

  /// Replace a DRAFT invoice's contents in a single transaction. The
  /// invoice number and creation date are preserved; everything else
  /// (party/vendor snapshot, line items, totals) is recomputed from the
  /// payload, so cancelling-and-recreating is no longer the only way to
  /// fix a wrong line item.
  ///
  /// Query budget (steady state):
  ///   - 1 SELECT to read status + invoiceDate
  ///   - ≤ 4 from [resolveInvoiceFields]
  ///   - 1 deleteMany (items)
  ///   - 1 createMany (items)
  ///   - 1 update (header) + final include re-read
  /// Independent of item count — no N+1 fan-out.
  async updateInvoice(shopId: number, id: number, data: {
    type: InvoiceType;
    documentType?: DocumentType;
    placeOfSupplyStateCode?: string;
    vendorId?: number | null;
    partyId?: number | null;
    customerName?: string;
    customerPhone?: string;
    customerGstin?: string;
    discount?: number;
    note?: string;
    items: InvoiceItemInput[];
  }) {
    const existing = await prisma.invoice.findFirst({
      where: { id, shopId },
      select: { id: true, status: true, invoiceDate: true, type: true },
    });
    if (!existing) return { error: 'Invoice not found' as const };
    if (existing.status !== 'DRAFT') {
      return { error: 'Only draft invoices can be edited' as const };
    }
    if (existing.type !== data.type) {
      // Type drives stock direction and number prefix — switching mid-flight
      // would corrupt both. Force cancel-and-create instead.
      return { error: 'Cannot change invoice type — cancel and create a new one' as const };
    }
    if (data.items.length > MAX_INVOICE_LINES) {
      return {
        error: `Invoice exceeds maximum ${MAX_INVOICE_LINES} lines` as const,
      };
    }

    const resolved = await this.resolveInvoiceFields({
      ...data,
      shopId,
      // Preserve the original creation date so the invoice number ↔ date
      // alignment from when it was minted stays consistent.
      invoiceDate: existing.invoiceDate.toISOString(),
    });
    if ('error' in resolved) return resolved;

    const { header, itemsData } = resolved;

    const invoice = await prisma.$transaction(async (tx) => {
      // Wipe and re-write items in two bulk calls. Diff-and-patch was
      // considered but adds complexity for no real gain — a draft is
      // usually edited end-to-end and item rows have no FKs pointing
      // into them yet (no ledger entries exist for drafts).
      await tx.invoiceItem.deleteMany({ where: { invoiceId: id } });
      await tx.invoiceItem.createMany({
        data: itemsData.map((it) => ({ ...it, invoiceId: id })),
      });
      return tx.invoice.update({
        where: { id },
        data: header,
        include: { items: { orderBy: { id: 'asc' } }, vendor: true, party: true },
      });
    });

    return { invoice };
  }

  async listInvoices(shopId: number, options: {
    type?: string;
    status?: string;
    documentType?: string;
    vendorId?: number;
    partyId?: number;
    productId?: number;
    search: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = { shopId };
    if (options.type) where.type = options.type;
    if (options.status) where.status = options.status;
    if (options.documentType) where.documentType = options.documentType;
    if (options.vendorId) where.vendorId = options.vendorId;
    if (options.partyId) where.partyId = options.partyId;
    if (options.productId) {
      where.items = { some: { productId: options.productId } };
    }
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

  async getInvoiceById(shopId: number, id: number) {
    return prisma.invoice.findFirst({
      where: { id, shopId },
      include: {
        vendor: true,
        party: true,
        items: {
          orderBy: { id: 'asc' },
        },
      },
    });
  }

  async updateStatus(shopId: number, id: number, status: InvoiceStatus, createdById?: number) {
    // Wrap header read + ledger work + status update in one transaction
    // so a half-confirm (stock moved, status not flipped) or half-cancel
    // (status flipped, reversal not posted) is impossible.
    return prisma.$transaction(async (tx) => {
      const invoice = await tx.invoice.findFirst({
        where: { id, shopId },
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

      // ── DRAFT → CONFIRMED: refresh contact snapshot, then post ─────
      // A draft is not yet a legally-issued document; if the merchant
      // edited the party/vendor while the draft was open, the about-
      // to-be-issued invoice should carry the *current* contact
      // details. Once status flips to CONFIRMED these columns are
      // frozen forever (we don't re-write them on subsequent edits to
      // the party/vendor — that would mutate an issued tax document).
      const snapshotRefresh: Record<string, string | null | boolean> = {};
      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && invoice.partyId) {
        const party = await tx.party.findUnique({
          where: { id: invoice.partyId },
          select: {
            name: true, phone: true, gstin: true, address: true,
            city: true, state: true, stateCode: true, pinCode: true,
            panNumber: true,
          },
        });
        if (party) {
          snapshotRefresh.customerName = party.name;
          snapshotRefresh.customerPhone = party.phone ?? null;
          snapshotRefresh.customerGstin = party.gstin ?? null;
          snapshotRefresh.customerAddress = party.address ?? null;
          snapshotRefresh.customerCity = party.city ?? null;
          snapshotRefresh.customerState = party.state ?? null;
          snapshotRefresh.customerStateCode = party.stateCode ?? null;
          snapshotRefresh.customerPinCode = party.pinCode ?? null;
          snapshotRefresh.customerPanNumber = party.panNumber ?? null;
        }
      }
      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && invoice.vendorId) {
        const vendor = await tx.vendor.findUnique({
          where: { id: invoice.vendorId },
          select: {
            name: true, phone: true, gstin: true, address: true,
            city: true, state: true, stateCode: true, pinCode: true,
            panNumber: true,
          },
        });
        if (vendor) {
          snapshotRefresh.vendorName = vendor.name;
          snapshotRefresh.vendorPhone = vendor.phone ?? null;
          snapshotRefresh.vendorGstin = vendor.gstin ?? null;
          snapshotRefresh.vendorAddress = vendor.address ?? null;
          snapshotRefresh.vendorCity = vendor.city ?? null;
          snapshotRefresh.vendorState = vendor.state ?? null;
          snapshotRefresh.vendorStateCode = vendor.stateCode ?? null;
          snapshotRefresh.vendorPinCode = vendor.pinCode ?? null;
          snapshotRefresh.vendorPanNumber = vendor.panNumber ?? null;
        }
      }

      // ── DRAFT → CONFIRMED: post stock movements ────────────────────
      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && !ledgerOwnedByChallan) {
        const direction = invoice.type === 'SALE' ? 'OUT' : 'IN';
        const reasonCode = invoice.type === 'SALE' ? 'SALE' : 'PURCHASE';
        // Prefer the just-refreshed values over the stale draft
        // snapshot so the ledger row matches what the issued invoice
        // will print.
        const counterpartyName =
          invoice.type === 'SALE'
            ? (snapshotRefresh.customerName as string | undefined)
              ?? invoice.customerName ?? invoice.party?.name ?? null
            : (snapshotRefresh.vendorName as string | undefined)
              ?? invoice.vendorName ?? invoice.vendor?.name ?? null;
        const counterpartyGstin =
          invoice.type === 'SALE'
            ? (snapshotRefresh.customerGstin as string | null | undefined)
              ?? invoice.customerGstin ?? invoice.party?.gstin ?? null
            : (snapshotRefresh.vendorGstin as string | null | undefined)
              ?? invoice.vendorGstin ?? invoice.vendor?.gstin ?? null;
        const result = await ledgerService.post({
          shopId,
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
          where: { sourceType: 'INVOICE', sourceId: invoice.id, reversesId: null, shopId },
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
        data: { status, ...snapshotRefresh },
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
  async convertEstimate(shopId: number, invoiceId: number) {
    const source = await prisma.invoice.findFirst({
      where: { id: invoiceId, shopId },
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
      shopId,
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

  async deleteInvoice(shopId: number, id: number) {
    const invoice = await prisma.invoice.findFirst({
      where: { id, shopId },
      select: { status: true },
    });
    if (!invoice) return { error: 'Invoice not found' as const };
    if (invoice.status === 'CONFIRMED') {
      return { error: 'Cannot delete a confirmed invoice. Cancel it first.' as const };
    }
    await prisma.invoice.delete({ where: { id } });
    return { ok: true };
  }

  /// Stream the rendered PDF directly to an arbitrary writable (the
  /// HTTP response in production). Avoids buffering the entire document
  /// in node memory — a 200-line invoice can otherwise hit tens of MB.
  /// Returns `null` on success (output was streamed), or the same
  /// `{ error }` shape that [generatePdf] does on failure.
  /// Stream the rendered PDF to `out`. Calls [onReady] AFTER the
  /// invoice has been verified to exist (so the controller can set the
  /// PDF Content-Type / Disposition headers safely) but BEFORE any
  /// bytes are written. Returns `null` on success, `{error}` if the
  /// invoice can't be loaded — in which case [onReady] has not been
  /// invoked, so the controller is free to respond with JSON instead.
  async streamPdf(
    shopId: number,
    id: number,
    out: Writable,
    onReady?: () => void,
  ): Promise<null | { error: string }> {
    const result = await renderInvoicePdf(shopId, id, out, onReady);
    if (Buffer.isBuffer(result)) return null;
    if (result === null) return null;
    return result;
  }

  async generatePdf(shopId: number, id: number): Promise<Buffer | { error: string }> {
    const result = await renderInvoicePdf(shopId, id, null);
    return result as Buffer | { error: string };
  }


  private round2(v: number): number {
    return Math.round((v + Number.EPSILON) * 100) / 100;
  }
}

export const invoicesService = new InvoicesService();
