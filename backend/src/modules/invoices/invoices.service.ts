import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { enqueueOutbox } from '../../infra/outbox/outbox.js';
import { Writable } from 'stream';
import { ledgerService } from '../ledger/ledger.service.js';
import { nextInvoiceNo } from '../../shared/numbering/sequences.js';
import { isInterstateSupply, isValidStateCode, GSTIN_REGEX } from '../../shared/validation/indian.js';
import { amountInWords } from '../../shared/numbering/amount_in_words.js';
import { renderInvoicePdf } from './invoice-pdf-renderer.js';
import {
  resolveActiveProductPromos,
  lineDiscount,
} from '../banners/promo-pricing.js';
import { resolveProductPricing } from '../products/pricing.js';
import { isOutputGstRegistered } from './gst-registration-gate.js';

type InvoiceType = 'SALE' | 'PURCHASE';
type InvoiceStatus = 'DRAFT' | 'CONFIRMED' | 'CANCELLED';

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
  variantId?: number | null;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  cessRate?: number;
  discount?: number;
  isPriceInclusive?: boolean;
}

interface ResolveInvoiceInput {
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
  isPriceInclusive?: boolean;
  isInterstateOverride?: boolean;
  skipRecipientDetailGuard?: boolean;
  acknowledgeMissingRecipientDetails?: boolean;
  customerAddress?: string;
  customerCity?: string;
  customerState?: string;
  customerStateCode?: string;
  customerPinCode?: string;
}

export class PosInvoiceError extends Error {
  constructor(
    message: string,
    readonly detail?: { productId: number; available: number; requested: number },
  ) {
    super(message);
    this.name = 'PosInvoiceError';
  }
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
    isPriceInclusive?: boolean;
    confirm?: boolean;
    confirmedById?: number;
  }) {
    const resolved = await this.resolveInvoiceFields(data);
    if ('error' in resolved) return resolved;

    const { header, itemsData } = resolved;

    const invoice = await prisma.$transaction(async (tx) => {
      const { invoiceNo, financialYear } = await nextInvoiceNo(
        data.shopId,
        data.type,
        header.documentType,
        header.invoiceDate,
        tx,
      );
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

  async previewSaleTotals(data: ResolveInvoiceInput) {
    return this.resolveInvoiceFields({ ...data, skipRecipientDetailGuard: true });
  }

  async createConfirmedSaleInTx(
    tx: Prisma.TransactionClient,
    data: ResolveInvoiceInput,
    createdById?: number,
  ) {
    const resolved = await this.resolveInvoiceFields({ ...data, skipRecipientDetailGuard: true }, tx);
    if ('error' in resolved) {
      throw new PosInvoiceError(resolved.error);
    }
    const { header, itemsData } = resolved;
    const { invoiceNo, financialYear } = await nextInvoiceNo(
      data.shopId,
      data.type,
      header.documentType,
      header.invoiceDate,
      tx,
    );
    const invoice = await tx.invoice.create({
      data: {
        ...header,
        shopId: data.shopId,
        invoiceNo,
        financialYear,
        status: 'CONFIRMED',
        items: { create: itemsData },
      },
      include: { items: true },
    });

    const posted = await ledgerService.post(
      {
        shopId: data.shopId,
        direction: 'OUT',
        reasonCode: 'SALE',
        sourceType: 'INVOICE',
        sourceId: invoice.id,
        idempotencyKey: `INVOICE:${invoice.id}:CONFIRM`,
        counterpartyName: header.customerName ?? undefined,
        counterpartyGstin: header.customerGstin ?? undefined,
        createdById,
        note: `Invoice ${invoice.invoiceNo}`,
        lines: invoice.items.map((it) => ({
          productId: it.productId,
          quantity: Number(it.quantity),
          sourceLineId: it.id,
        })),
      },
      tx,
    );
    if ('error' in posted) {
      if (posted.error === 'Insufficient stock') {
        throw new PosInvoiceError('Insufficient stock for one or more items', {
          productId: posted.productId,
          available: posted.available,
          requested: posted.requested,
        });
      }
      throw new PosInvoiceError(posted.error);
    }

    await enqueueOutbox(
      {
        aggregateType: 'invoice',
        aggregateId: invoice.id,
        eventType: 'invoice.confirmed',
        shopId: data.shopId,
        payload: { invoiceId: invoice.id, occurredAt: invoice.invoiceDate.toISOString() },
      },
      tx,
    );
    return invoice;
  }

  async createSalesReturnInTx(
    tx: Prisma.TransactionClient,
    data: ResolveInvoiceInput & { originalInvoiceId: number },
    createdById?: number,
    shiftId?: number,
  ) {
    const original = await tx.invoice.findFirst({
      where: { id: data.originalInvoiceId, shopId: data.shopId },
      select: { isInterstate: true, placeOfSupplyStateCode: true },
    });
    if (!original) {
      throw new PosInvoiceError('Original invoice not found');
    }
    const resolved = await this.resolveInvoiceFields(
      {
        ...data,
        documentType: 'CREDIT_NOTE',
        placeOfSupplyStateCode:
          data.placeOfSupplyStateCode ?? original.placeOfSupplyStateCode ?? undefined,
        isInterstateOverride: original.isInterstate,
      },
      tx,
    );
    if ('error' in resolved) {
      throw new PosInvoiceError(resolved.error);
    }
    const { header, itemsData } = resolved;
    const { invoiceNo, financialYear } = await nextInvoiceNo(
      data.shopId,
      data.type,
      header.documentType,
      header.invoiceDate,
      tx,
    );
    const invoice = await tx.invoice.create({
      data: {
        ...header,
        shopId: data.shopId,
        invoiceNo,
        financialYear,
        status: 'CONFIRMED',
        originalInvoiceId: data.originalInvoiceId,
        createdById: createdById ?? null,
        shiftId: shiftId ?? null,
        items: { create: itemsData },
      },
      include: { items: true },
    });

    await enqueueOutbox(
      {
        aggregateType: 'invoice',
        aggregateId: invoice.id,
        eventType: 'invoice.confirmed',
        shopId: data.shopId,
        payload: { invoiceId: invoice.id, occurredAt: invoice.invoiceDate.toISOString() },
      },
      tx,
    );

    const restocked = await ledgerService.restockReturnAtCost(
      {
        shopId: data.shopId,
        originalInvoiceId: data.originalInvoiceId,
        sourceType: 'INVOICE',
        sourceId: invoice.id,
        idempotencyKey: `INVOICE:${invoice.id}:RETURN`,
        counterpartyName: header.customerName ?? undefined,
        counterpartyGstin: header.customerGstin ?? undefined,
        createdById,
        note: `Credit note ${invoice.invoiceNo}`,
        lines: invoice.items.map((it) => ({
          productId: it.productId,
          quantity: Number(it.quantity),
          sourceLineId: it.id,
        })),
      },
      tx,
    );
    if ('error' in restocked) {
      if (restocked.error === 'No original consumption') {
        const fallback = await ledgerService.post(
          {
            shopId: data.shopId,
            direction: 'IN',
            reasonCode: 'RETURN_IN',
            sourceType: 'INVOICE',
            sourceId: invoice.id,
            idempotencyKey: `INVOICE:${invoice.id}:RETURN`,
            counterpartyName: header.customerName ?? undefined,
            counterpartyGstin: header.customerGstin ?? undefined,
            createdById,
            note: `Credit note ${invoice.invoiceNo}`,
            lines: invoice.items.map((it) => ({
              productId: it.productId,
              quantity: Number(it.quantity),
              unitPrice: Number(it.unitPrice),
              sourceLineId: it.id,
            })),
          },
          tx,
        );
        if ('error' in fallback) {
          throw new PosInvoiceError(fallback.error);
        }
        return invoice;
      }
      throw new PosInvoiceError(restocked.error);
    }
    return invoice;
  }

  async createAdjustmentNoteFromInvoice(
    shopId: number,
    originalInvoiceId: number,
    input: {
      documentType: 'CREDIT_NOTE' | 'DEBIT_NOTE';
      reason?: string;
      restock?: boolean;
      lines: Array<{ productId: number; quantity: number; unitPrice?: number }>;
    },
    createdById?: number,
  ): Promise<{ invoice: { id: number; invoiceNo: string; total: Prisma.Decimal } } | { error: string }> {
    return prisma.$transaction(async (tx) => {
      const original = await tx.invoice.findFirst({
        where: { id: originalInvoiceId, shopId },
        include: { items: true },
      });
      if (!original) return { error: 'Original invoice not found' as const };
      if (original.type !== 'SALE') {
        return { error: 'Notes can only be issued against sale invoices' as const };
      }
      if (original.status !== 'CONFIRMED') {
        return { error: 'Notes can only be issued against a confirmed invoice' as const };
      }
      if (
        original.documentType !== 'TAX_INVOICE' &&
        original.documentType !== 'BILL_OF_SUPPLY'
      ) {
        return {
          error: 'Notes can only be issued against a tax invoice or bill of supply' as const,
        };
      }
      if (input.lines.length === 0) {
        return { error: 'A note needs at least one line' as const };
      }

      const origByProduct = new Map<number, (typeof original.items)[number]>();
      for (const it of original.items) origByProduct.set(it.productId, it);

      const items: InvoiceItemInput[] = [];
      for (const line of input.lines) {
        const orig = origByProduct.get(line.productId);
        if (!orig) {
          return {
            error: `Product ${line.productId} is not on the original invoice` as const,
          };
        }
        if (!(line.quantity > 0)) {
          return { error: 'Note line quantity must be positive' as const };
        }
        items.push({
          productId: line.productId,
          quantity: line.quantity,
          unitPrice:
            input.documentType === 'CREDIT_NOTE'
              ? Number(orig.unitPrice)
              : (line.unitPrice ?? 0),
          taxPercent: Number(orig.taxPercent),
          cessRate: Number(orig.cessRate),
          isPriceInclusive: orig.isPriceInclusive,
        });
      }

      if (input.documentType === 'CREDIT_NOTE') {
        const priorNotes = await tx.invoice.findMany({
          where: {
            shopId,
            originalInvoiceId,
            documentType: 'CREDIT_NOTE',
            status: 'CONFIRMED',
          },
          include: { items: true },
        });
        const creditedSoFar = new Map<number, number>();
        for (const n of priorNotes) {
          for (const it of n.items) {
            creditedSoFar.set(
              it.productId,
              (creditedSoFar.get(it.productId) ?? 0) + Number(it.quantity),
            );
          }
        }
        for (const line of input.lines) {
          const orig = origByProduct.get(line.productId)!;
          const already = creditedSoFar.get(line.productId) ?? 0;
          const remaining = Number(orig.quantity) - already;
          if (line.quantity > remaining) {
            return {
              error: `Cannot credit ${line.quantity} of that item — only ${remaining} of ${Number(orig.quantity)} remain uncredited` as const,
            };
          }
        }
      }

      const resolved = await this.resolveInvoiceFields(
        {
          shopId,
          type: 'SALE',
          documentType: input.documentType,
          partyId: original.partyId ?? undefined,
          customerName: original.customerName ?? undefined,
          customerPhone: original.customerPhone ?? undefined,
          customerGstin: original.customerGstin ?? undefined,
          placeOfSupplyStateCode: original.placeOfSupplyStateCode ?? undefined,
          isInterstateOverride: original.isInterstate,
          note: input.reason,
          items,
        },
        tx,
      );
      if ('error' in resolved) return { error: resolved.error };
      const { header, itemsData } = resolved;

      const { invoiceNo, financialYear } = await nextInvoiceNo(
        shopId,
        'SALE',
        header.documentType,
        header.invoiceDate,
        tx,
      );

      const invoice = await tx.invoice.create({
        data: {
          ...header,
          shopId,
          invoiceNo,
          financialYear,
          status: 'CONFIRMED',
          originalInvoiceId,
          createdById: createdById ?? null,
          items: { create: itemsData },
        },
        include: { items: true },
      });

      await enqueueOutbox(
        {
          aggregateType: 'invoice',
          aggregateId: invoice.id,
          eventType: 'invoice.confirmed',
          shopId,
          payload: {
            invoiceId: invoice.id,
            occurredAt: invoice.invoiceDate.toISOString(),
          },
        },
        tx,
      );

      const shouldRestock =
        input.documentType === 'CREDIT_NOTE' && (input.restock ?? true);
      if (shouldRestock) {
        const restocked = await ledgerService.restockReturnAtCost(
          {
            shopId,
            originalInvoiceId,
            sourceType: 'INVOICE',
            sourceId: invoice.id,
            idempotencyKey: `INVOICE:${invoice.id}:NOTE_RESTOCK`,
            counterpartyName: header.customerName ?? undefined,
            counterpartyGstin: header.customerGstin ?? undefined,
            createdById,
            note: `Credit note ${invoice.invoiceNo}`,
            lines: invoice.items.map((it) => ({
              productId: it.productId,
              quantity: Number(it.quantity),
              sourceLineId: it.id,
            })),
          },
          tx,
        );
        if ('error' in restocked) {
          if (restocked.error === 'No original consumption') {
            const fallback = await ledgerService.post(
              {
                shopId,
                direction: 'IN',
                reasonCode: 'RETURN_IN',
                sourceType: 'INVOICE',
                sourceId: invoice.id,
                idempotencyKey: `INVOICE:${invoice.id}:NOTE_RESTOCK`,
                counterpartyName: header.customerName ?? undefined,
                counterpartyGstin: header.customerGstin ?? undefined,
                createdById,
                note: `Credit note ${invoice.invoiceNo}`,
                lines: invoice.items.map((it) => ({
                  productId: it.productId,
                  quantity: Number(it.quantity),
                  unitPrice: Number(it.unitPrice),
                  sourceLineId: it.id,
                })),
              },
              tx,
            );
            if ('error' in fallback) {
              throw new PosInvoiceError(fallback.error);
            }
          } else {
            throw new PosInvoiceError(restocked.error);
          }
        }
      }

      return { invoice: { id: invoice.id, invoiceNo: invoice.invoiceNo, total: invoice.total } };
    });
  }

  private async resolveInvoiceFields(data: ResolveInvoiceInput, tx?: Prisma.TransactionClient): Promise<
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
          isPriceInclusive: boolean;
        }>;
      }
  > {
    if (data.items.length === 0) {
      return { error: 'Invoice must have at least one item' as const };
    }
    if (data.items.length > MAX_INVOICE_LINES) {
      return {
        error: `Invoice exceeds maximum ${MAX_INVOICE_LINES} lines` as const,
      };
    }
    let documentType: DocumentType = data.documentType ?? 'TAX_INVOICE';

    const db = tx ?? prisma;

    let partyId: number | null = null;
    let customerName = data.customerName ?? null;
    let customerPhone = data.customerPhone ?? null;
    let customerGstin = data.customerGstin ?? null;
    let customerAddress = data.customerAddress ?? null;
    let customerCity = data.customerCity ?? null;
    let customerState = data.customerState ?? null;
    let customerStateCode = data.customerStateCode ?? null;
    let customerPinCode = data.customerPinCode ?? null;
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
      const party = await db.party.findFirst({
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
      customerAddress = customerAddress ?? party.address ?? null;
      customerCity = customerCity ?? party.city ?? null;
      customerState = customerState ?? party.state ?? null;
      customerStateCode = customerStateCode ?? party.stateCode ?? null;
      customerPinCode = customerPinCode ?? party.pinCode ?? null;
      customerPanNumber = party.panNumber ?? null;
    }

    let resolvedVendorId: number | null = null;
    if (data.vendorId) {
      const vendor = await db.vendor.findFirst({
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

    const invoiceDate = data.invoiceDate ? new Date(data.invoiceDate) : new Date();

    const shop = await db.shop.findUnique({
      where: { id: data.shopId },
      select: {
        owner: {
          select: {
            shopStateCode: true,
            shopGstin: true,
            registrationType: true,
            gstEffectiveFrom: true,
          },
        },
      },
    });
    const shopGstin = shop?.owner.shopGstin ?? null;
    const shopStateCode =
      shop?.owner.shopStateCode ?? (shopGstin ? shopGstin.slice(0, 2) : null);

    const registrationType = shop?.owner.registrationType ?? 'UNREGISTERED';
    const gstEffectiveFrom = shop?.owner.gstEffectiveFrom ?? null;
    const isShopRegistered = isOutputGstRegistered(
      { shopGstin, registrationType, gstEffectiveFrom },
      invoiceDate,
    );
    const chargesOutputGst = data.type === 'SALE' ? isShopRegistered : true;

    if (data.type === 'SALE' && !isShopRegistered && documentType === 'TAX_INVOICE') {
      documentType = 'BILL_OF_SUPPLY';
    }

    if (data.type === 'SALE' && !customerStateCode && customerGstin) {
      const gstinStatePrefix = customerGstin.trim().slice(0, 2);
      if (isValidStateCode(gstinStatePrefix)) {
        customerStateCode = gstinStatePrefix;
      }
    }

    const placeOfSupplyStateCode =
      data.placeOfSupplyStateCode ??
      (data.type === 'SALE' ? (customerStateCode ?? shopStateCode) : shopStateCode) ??
      null;
    const isInterstate =
      data.isInterstateOverride ??
      isInterstateSupply(shopStateCode, placeOfSupplyStateCode);

    if (data.type === 'SALE' && customerGstin) {
      customerGstin = customerGstin.trim().toUpperCase();
      if (!GSTIN_REGEX.test(customerGstin)) {
        return { error: 'Invalid recipient GSTIN' as const };
      }
    }

    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await db.product.findMany({
      where: { id: { in: productIds }, shopId: data.shopId },
      select: { id: true, name: true, sku: true, hsnCode: true, unit: true, stockQuantity: true, taxPercent: true, cessRate: true, hsnRevision: true, pricingMode: true },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    const variantIds = [
      ...new Set(
        data.items
          .map((i) => i.variantId)
          .filter((v): v is number => typeof v === 'number'),
      ),
    ];
    const variantMap = new Map<
      number,
      { id: number; productId: number; hsnCode: string | null; taxPercent: Prisma.Decimal }
    >();
    if (variantIds.length > 0) {
      const variants = await db.productVariant.findMany({
        where: { id: { in: variantIds }, productId: { in: productIds } },
        select: { id: true, productId: true, hsnCode: true, taxPercent: true },
      });
      for (const v of variants) variantMap.set(v.id, v);
    }

    const promos = await resolveActiveProductPromos(data.shopId, productIds, tx);

    const D = Prisma.Decimal;
    const HUNDRED = new D(100);
    const TWO = new D(2);
    const dround2 = (v: Prisma.Decimal): Prisma.Decimal =>
      v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

    const inclusiveDefault = data.isPriceInclusive;

    const lines = data.items.map((item) => {
      const gross = dround2(new D(item.quantity).mul(new D(item.unitPrice)));
      let rawItemDiscount: Prisma.Decimal;
      if (item.discount !== undefined) {
        rawItemDiscount = new D(item.discount);
      } else {
        const promo = promos.get(item.productId);
        rawItemDiscount = new D(
          promo ? lineDiscount(promo.type, promo.value, item.unitPrice, item.quantity) : 0,
        );
      }
      const clamped = dround2(rawItemDiscount).clamp(new D(0), gross);
      return { item, gross, itemDiscount: clamped };
    });

    const baseTaxableTotal = dround2(
      lines.reduce((s, l) => s.add(l.gross.sub(l.itemDiscount)), new D(0)),
    );
    const headerDiscount = dround2(new D(data.discount ?? 0)).clamp(
      new D(0),
      baseTaxableTotal,
    );

    let subtotal = new D(0);
    let taxableValueTotal = new D(0);
    let igstTotal = new D(0);
    let cgstTotal = new D(0);
    let sgstTotal = new D(0);
    let cessTotal = new D(0);
    let headerAllocated = new D(0);

    const itemsData = lines.map((l, idx) => {
      const { item, gross, itemDiscount } = l;
      const product = productMap.get(item.productId)!;
      const lineBase = dround2(gross.sub(itemDiscount));

      let headerShare: Prisma.Decimal;
      if (headerDiscount.lte(0) || baseTaxableTotal.lte(0)) {
        headerShare = new D(0);
      } else if (idx === lines.length - 1) {
        headerShare = dround2(headerDiscount.sub(headerAllocated));
      } else {
        headerShare = dround2(headerDiscount.mul(lineBase).div(baseTaxableTotal));
      }
      headerAllocated = dround2(headerAllocated.add(headerShare));

      const lineDiscountTotal = dround2(itemDiscount.add(headerShare));

      const lineVariant =
        item.variantId != null ? variantMap.get(item.variantId) : undefined;
      const lineVariantForProduct =
        lineVariant && lineVariant.productId === item.productId ? lineVariant : undefined;
      const variantTaxPct = lineVariantForProduct
        ? new D(lineVariantForProduct.taxPercent ?? 0)
        : new D(0);
      const variantHsn = lineVariantForProduct?.hsnCode ?? null;

      const resolvedProductPricing = resolveProductPricing({
        taxPercent: Number(product.taxPercent ?? 0),
        cessRate: Number(product.cessRate ?? 0),
        pricingMode: product.pricingMode,
      });

      const effectiveTaxPct =
        product.pricingMode === 'NO_GST'
          ? new D(0)
          : variantTaxPct.gt(0)
            ? variantTaxPct
            : new D(resolvedProductPricing.taxPercent);
      const effectiveHsn = variantHsn ?? product.hsnCode ?? undefined;

      const productTaxPct = effectiveTaxPct;
      const productCessRate = new D(resolvedProductPricing.cessRate);
      const taxPct = chargesOutputGst
        ? (item.taxPercent !== undefined ? new D(item.taxPercent) : productTaxPct)
        : new D(0);
      const cessRate = chargesOutputGst
        ? (item.cessRate !== undefined ? new D(item.cessRate) : productCessRate)
        : new D(0);

      const isInclusive =
        item.isPriceInclusive ?? inclusiveDefault ?? resolvedProductPricing.isPriceInclusive;
      const lineAmount = dround2(gross.sub(lineDiscountTotal));
      let taxableValue: Prisma.Decimal;
      if (isInclusive) {
        const divisor = HUNDRED.add(taxPct).add(cessRate);
        taxableValue = divisor.gt(0)
          ? dround2(lineAmount.mul(HUNDRED).div(divisor))
          : lineAmount;
      } else {
        taxableValue = lineAmount;
      }

      let igstAmount = new D(0);
      let cgstAmount = new D(0);
      let sgstAmount = new D(0);
      if (isInterstate) {
        igstAmount = dround2(taxableValue.mul(taxPct).div(HUNDRED));
      } else {
        const gstTotal = dround2(taxableValue.mul(taxPct).div(HUNDRED));
        cgstAmount = dround2(gstTotal.div(TWO));
        sgstAmount = dround2(gstTotal.sub(cgstAmount));
      }
      const cessAmount = dround2(taxableValue.mul(cessRate).div(HUNDRED));
      const lineTotal = dround2(
        taxableValue.add(igstAmount).add(cgstAmount).add(sgstAmount).add(cessAmount),
      );

      subtotal = subtotal.add(gross);
      taxableValueTotal = taxableValueTotal.add(taxableValue);
      igstTotal = igstTotal.add(igstAmount);
      cgstTotal = cgstTotal.add(cgstAmount);
      sgstTotal = sgstTotal.add(sgstAmount);
      cessTotal = cessTotal.add(cessAmount);

      const billedProductRate =
        !variantTaxPct.gt(0) && taxPct.eq(new D(product.taxPercent ?? 0));

      return {
        productId: item.productId,
        productName: product.name,
        productSku: product.sku,
        hsn: effectiveHsn,
        hsnRevision: billedProductRate ? (product.hsnRevision ?? null) : null,
        unit: product.unit,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        taxPercent: taxPct.toNumber(),
        discount: lineDiscountTotal.toNumber(),
        taxableValue: taxableValue.toNumber(),
        igstAmount: igstAmount.toNumber(),
        cgstAmount: cgstAmount.toNumber(),
        sgstAmount: sgstAmount.toNumber(),
        cessRate: cessRate.toNumber(),
        cessAmount: cessAmount.toNumber(),
        total: lineTotal.toNumber(),
        isPriceInclusive: isInclusive,
      };
    });

    const igstHeader = dround2(igstTotal);
    const cgstHeader = dround2(cgstTotal);
    const sgstHeader = dround2(sgstTotal);
    const cessHeader = dround2(cessTotal);
    const taxAmount = dround2(
      igstHeader.add(cgstHeader).add(sgstHeader).add(cessHeader),
    );
    if (process.env.NODE_ENV !== 'production') {
      const expected = dround2(
        igstHeader.add(cgstHeader).add(sgstHeader).add(cessHeader),
      );
      if (!taxAmount.eq(expected)) {
        throw new Error(
          `taxAmount invariant broken: ${taxAmount.toString()} != igst+cgst+sgst+cess ${expected.toString()}`,
        );
      }
    }
    const grandTotalRaw = dround2(taxableValueTotal.add(taxAmount));
    const roundedTotal = grandTotalRaw.toDecimalPlaces(0, Prisma.Decimal.ROUND_HALF_UP);
    const roundOff = dround2(roundedTotal.sub(grandTotalRaw));
    const total = dround2(grandTotalRaw.add(roundOff));
    const words = amountInWords(total.toNumber());

    const isPrimarySupplyDoc =
      documentType === 'TAX_INVOICE' || documentType === 'BILL_OF_SUPPLY';
    const recipientGuardWaived =
      data.skipRecipientDetailGuard === true ||
      data.acknowledgeMissingRecipientDetails === true;
    if (data.type === 'SALE' && isPrimarySupplyDoc && !recipientGuardWaived) {
      const FIFTY_K = new D(50000);
      const needsRecipientDetails = !!customerGstin || total.gte(FIFTY_K);
      if (needsRecipientDetails) {
        if (!customerName || customerName.trim().length === 0) {
          return { error: 'Recipient name is required for this invoice' as const };
        }
        const hasAddress =
          (customerAddress && customerAddress.trim().length > 0) ||
          (customerCity && customerCity.trim().length > 0) ||
          (customerStateCode && customerStateCode.trim().length > 0) ||
          (customerPinCode && customerPinCode.trim().length > 0);
        if (!hasAddress) {
          return { error: 'Recipient address is required for this invoice' as const };
        }
      }
    }

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
        subtotal: dround2(subtotal).toNumber(),
        taxableValue: dround2(taxableValueTotal).toNumber(),
        taxAmount: taxAmount.toNumber(),
        igstAmount: igstHeader.toNumber(),
        cgstAmount: cgstHeader.toNumber(),
        sgstAmount: sgstHeader.toNumber(),
        cessAmount: cessHeader.toNumber(),
        discount: 0,
        roundOff: roundOff.toNumber(),
        total: total.toNumber(),
        amountInWords: words,
        note: data.note ?? null,
        invoiceDate,
      },
      itemsData,
    };
  }

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
      invoiceDate: existing.invoiceDate.toISOString(),
    });
    if ('error' in resolved) return resolved;

    const { header, itemsData } = resolved;

    const invoice = await prisma.$transaction(async (tx) => {
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
    dateFrom?: string;
    dateTo?: string;
    archived?: boolean;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = { shopId };
    where.archivedAt = options.archived ? { not: null } : null;
    if (options.type) where.type = options.type;
    if (options.status) where.status = options.status;
    if (options.documentType) where.documentType = options.documentType;
    if (options.vendorId) where.vendorId = options.vendorId;
    if (options.partyId) where.partyId = options.partyId;
    if (options.productId) {
      where.items = { some: { productId: options.productId } };
    }
    if (options.dateFrom || options.dateTo) {
      where.invoiceDate = {
        ...(options.dateFrom && { gte: new Date(options.dateFrom) }),
        ...(options.dateTo && { lte: new Date(options.dateTo) }),
      };
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
    return prisma.$transaction(async (tx) => {
      const invoice = await tx.invoice.findFirst({
        where: { id, shopId },
        include: { items: true, vendor: true, party: true, challan: { select: { id: true } } },
      });
      if (!invoice) return { error: 'Invoice not found' as const };

      if (invoice.status === 'CANCELLED') {
        return { error: 'Cannot update a cancelled invoice' as const };
      }
      if (invoice.status === status) {
        return { invoice };
      }

      const ledgerOwnedByChallan = invoice.challan !== null;

      const movesStock =
        invoice.documentType === 'TAX_INVOICE' ||
        invoice.documentType === 'BILL_OF_SUPPLY';

      if (ledgerOwnedByChallan && status === 'CANCELLED' && invoice.status === 'CONFIRMED') {
        return {
          error: 'Cancel the linked challan instead — this invoice is its bill.' as const,
        };
      }

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
          snapshotRefresh.customerAddress = party.address ?? null;
          snapshotRefresh.customerCity = party.city ?? null;
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
          snapshotRefresh.vendorAddress = vendor.address ?? null;
          snapshotRefresh.vendorCity = vendor.city ?? null;
          snapshotRefresh.vendorPinCode = vendor.pinCode ?? null;
          snapshotRefresh.vendorPanNumber = vendor.panNumber ?? null;
        }
      }

      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && !ledgerOwnedByChallan && movesStock) {
        const direction = invoice.type === 'SALE' ? 'OUT' : 'IN';
        const reasonCode = invoice.type === 'SALE' ? 'SALE' : 'PURCHASE';
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

      const eventType =
        invoice.status === 'DRAFT' && status === 'CONFIRMED'
          ? 'invoice.confirmed'
          : invoice.status === 'CONFIRMED' && status === 'CANCELLED'
            ? 'invoice.cancelled'
            : null;
      if (eventType) {
        await enqueueOutbox(
          {
            aggregateType: 'invoice',
            aggregateId: updated.id,
            eventType,
            shopId,
            payload: { invoiceId: updated.id, occurredAt: updated.invoiceDate.toISOString() },
          },
          tx,
        );
      }
      return { invoice: updated };
    });
  }

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
    if (source.convertedToInvoiceId) {
      const existing = await prisma.invoice.findFirst({
        where: { id: source.convertedToInvoiceId, shopId },
        include: { items: true, vendor: true, party: true },
      });
      if (existing) return { invoice: existing, confirmed: existing.status === 'CONFIRMED' };
    }

    const result = await this.createInvoice({
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
    if ('error' in result) return result;

    const claim = await prisma.invoice.updateMany({
      where: { id: source.id, shopId, convertedToInvoiceId: null },
      data: { convertedToInvoiceId: result.invoice.id },
    });
    if (claim.count === 0) {
      await prisma.invoice.delete({ where: { id: result.invoice.id } }).catch(() => {});
      const winner = await prisma.invoice.findFirst({
        where: { id: invoiceId, shopId },
        select: { convertedToInvoiceId: true },
      });
      const existing = winner?.convertedToInvoiceId
        ? await prisma.invoice.findFirst({
            where: { id: winner.convertedToInvoiceId, shopId },
            include: { items: true, vendor: true, party: true },
          })
        : null;
      if (existing) return { invoice: existing, confirmed: existing.status === 'CONFIRMED' };
      return { error: 'Conversion already in progress' as const };
    }
    return result;
  }

  async setArchived(shopId: number, id: number, archived: boolean) {
    const invoice = await prisma.invoice.findFirst({
      where: { id, shopId },
      select: { status: true, archivedAt: true },
    });
    if (!invoice) return { error: 'Invoice not found' as const };

    if (archived && invoice.status === 'CONFIRMED') {
      return {
        error:
          'Cannot archive a confirmed invoice — cancel it first, then archive it.' as const,
      };
    }

    const alreadyInState = archived === (invoice.archivedAt !== null);
    const updated = alreadyInState
      ? await prisma.invoice.findFirstOrThrow({
          where: { id, shopId },
          include: { items: { orderBy: { id: 'asc' } }, vendor: true, party: true },
        })
      : await prisma.invoice.update({
          where: { id },
          data: { archivedAt: archived ? new Date() : null },
          include: { items: { orderBy: { id: 'asc' } }, vendor: true, party: true },
        });

    return { invoice: updated };
  }

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
