import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { Writable } from 'stream';
import { nextQuotationNo } from '../../shared/numbering/sequences.js';
import { toNumber, round2 } from '../../shared/numbering/decimal.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import { invoicesService } from '../invoices/invoices.service.js';
import { renderQuotationPdf } from './quotation-pdf-renderer.js';
import { resolveProductPricing } from '../products/pricing.js';
import { chargesOutputGstForSale, isOutputGstRegistered } from '../invoices/gst-registration-gate.js';

export type QuotationStatus =
  | 'REQUESTED'
  | 'PENDING'
  | 'ACCEPTED'
  | 'DECLINED'
  | 'CANCELLED'
  | 'EXPIRED';

export interface QuotationItemInput {
  productId: number;
  name: string;
  sku?: string | null;
  quantity: number;
  unitPrice: number;
  taxPercent?: number | null;
  cessRate?: number | null;
  isPriceInclusive?: boolean | null;
  discount?: number | null;
  imageUrl?: string | null;
}

const quotationSelect = {
  id: true,
  shopId: true,
  partyId: true,
  quotationNo: true,
  status: true,
  items: true,
  subtotal: true,
  taxAmount: true,
  total: true,
  note: true,
  placeOfSupplyStateCode: true,
  declineNote: true,
  requestedById: true,
  respondedAt: true,
  invoiceId: true,
  archivedAt: true,
  createdAt: true,
  updatedAt: true,
  party: { select: { id: true, name: true } },
  invoice: { select: { id: true, invoiceNo: true } },
} satisfies Prisma.QuotationSelect;

type QuotationRow = Prisma.QuotationGetPayload<{ select: typeof quotationSelect }>;

function toDTO(r: QuotationRow) {
  return {
    ...r,
    subtotal: toNumber(r.subtotal),
    taxAmount: toNumber(r.taxAmount),
    total: toNumber(r.total),
  };
}

function priceItems(items: QuotationItemInput[], chargesGst: boolean) {
  let subtotal = 0;
  let taxAmount = 0;
  const lines = items.map((it) => {
    const qty = it.quantity;
    const gross = round2(qty * it.unitPrice);
    const discount = Math.min(Math.max(0, it.discount ?? 0), gross);
    const lineAmount = round2(gross - discount);
    const taxPercent = chargesGst ? it.taxPercent ?? 0 : 0;
    const cessRate = chargesGst ? it.cessRate ?? 0 : 0;
    let taxable: number;
    if (it.isPriceInclusive) {
      const divisor = 100 + taxPercent + cessRate;
      taxable = divisor > 0 ? round2((lineAmount * 100) / divisor) : lineAmount;
    } else {
      taxable = lineAmount;
    }
    const tax = round2((taxable * taxPercent) / 100);
    const cess = round2((taxable * cessRate) / 100);
    subtotal += taxable;
    taxAmount += tax + cess;
    return {
      productId: it.productId,
      name: it.name,
      sku: it.sku ?? null,
      quantity: qty,
      unitPrice: it.unitPrice,
      taxPercent,
      cessRate,
      isPriceInclusive: !!it.isPriceInclusive,
      discount,
      imageUrl: it.imageUrl ?? null,
      lineTotal: round2(taxable + tax + cess),
    };
  });
  const netSubtotal = round2(subtotal);
  const netTax = round2(taxAmount);
  const total = round2(netSubtotal + netTax);
  return {
    lines,
    subtotal: netSubtotal,
    taxAmount: netTax,
    total,
  };
}

async function repriceFromMaster(
  shopId: number,
  items: QuotationItemInput[],
): Promise<QuotationItemInput[]> {
  const ids = [...new Set(items.map((i) => i.productId))];
  const products = await prisma.product.findMany({
    where: { id: { in: ids }, shopId },
    select: {
      id: true,
      name: true,
      sku: true,
      sellingPrice: true,
      taxPercent: true,
      cessRate: true,
      pricingMode: true,
    },
  });
  const byId = new Map(products.map((p) => [p.id, p]));
  const out: QuotationItemInput[] = [];
  for (const it of items) {
    const p = byId.get(it.productId);
    if (!p) continue;
    const resolved = resolveProductPricing({
      taxPercent: toNumber(p.taxPercent),
      cessRate: toNumber(p.cessRate),
      pricingMode: p.pricingMode,
    });
    out.push({
      productId: it.productId,
      name: p.name,
      sku: p.sku,
      quantity: it.quantity,
      unitPrice: toNumber(p.sellingPrice),
      taxPercent: resolved.taxPercent,
      cessRate: resolved.cessRate,
      isPriceInclusive: resolved.isPriceInclusive,
      discount: 0,
      imageUrl: it.imageUrl ?? null,
    });
  }
  return out;
}

async function hydrateRates(
  shopId: number,
  items: QuotationItemInput[],
): Promise<QuotationItemInput[]> {
  if (
    !items.some(
      (it) => it.taxPercent == null || it.cessRate == null || it.isPriceInclusive == null,
    )
  ) {
    return items;
  }
  const ids = [...new Set(items.map((i) => i.productId))];
  const products = await prisma.product.findMany({
    where: { id: { in: ids }, shopId },
    select: { id: true, taxPercent: true, cessRate: true, pricingMode: true },
  });
  const byId = new Map(products.map((p) => [p.id, p]));
  return items.map((it) => {
    const p = byId.get(it.productId);
    const resolved = p
      ? resolveProductPricing({
          taxPercent: toNumber(p.taxPercent),
          cessRate: toNumber(p.cessRate),
          pricingMode: p.pricingMode,
        })
      : { taxPercent: 0, cessRate: 0, isPriceInclusive: false };
    return {
      ...it,
      taxPercent: it.taxPercent ?? resolved.taxPercent,
      cessRate: it.cessRate ?? resolved.cessRate,
      isPriceInclusive: it.isPriceInclusive ?? resolved.isPriceInclusive,
    };
  });
}

export class QuotationsService {
  async create(
    shopId: number,
    partyId: number,
    createdById: number,
    input: {
      items: QuotationItemInput[];
      note?: string | null;
      placeOfSupplyStateCode?: string | null;
    },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { id: true, name: true, linkedUserId: true },
    });
    if (!party) return { error: 'PARTY_NOT_FOUND' as const };
    if (!party.linkedUserId) {
      return { error: 'PARTY_NOT_LINKED' as const };
    }

    const [hydrated, chargesGst] = await Promise.all([
      hydrateRates(shopId, input.items),
      chargesOutputGstForSale(prisma, shopId, new Date()),
    ]);
    const priced = priceItems(hydrated, chargesGst);

    const created = await prisma.$transaction(async (tx) => {
      const quotationNo = await nextQuotationNo(shopId, new Date(), tx);
      const row = await tx.quotation.create({
        data: {
          shopId,
          partyId,
          quotationNo,
          status: 'PENDING',
          items: priced.lines as unknown as Prisma.InputJsonValue,
          subtotal: new Prisma.Decimal(priced.subtotal),
          taxAmount: new Prisma.Decimal(priced.taxAmount),
          total: new Prisma.Decimal(priced.total),
          note: input.note ?? null,
          placeOfSupplyStateCode: input.placeOfSupplyStateCode ?? null,
          createdById,
        },
        select: quotationSelect,
      });

      await tx.notification.create({
        data: {
          userId: party.linkedUserId!,
          kind: 'QUOTATION_RECEIVED',
          title: 'You received a quotation',
          body: `${row.quotationNo} · ₹${priced.total.toFixed(2)} · ${priced.lines.length} item(s)`,
          data: { quotationId: row.id, partyId, total: priced.total },
        },
      });

      return row;
    });

    return { quotation: toDTO(created) };
  }

  async listForShop(
    shopId: number,
    opts: {
      status?: QuotationStatus;
      archived?: boolean;
      skip: number;
      take: number;
    },
  ) {
    const where: Prisma.QuotationWhereInput = { shopId };
    if (opts.status) where.status = opts.status;
    where.archivedAt = opts.archived ? { not: null } : null;
    const [rows, total] = await Promise.all([
      prisma.quotation.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: opts.skip,
        take: opts.take,
        select: quotationSelect,
      }),
      prisma.quotation.count({ where }),
    ]);
    return { data: rows.map(toDTO), total };
  }

  async listForParty(
    shopId: number,
    partyId: number,
    opts: { status?: QuotationStatus; skip: number; take: number },
  ) {
    const where: Prisma.QuotationWhereInput = { shopId, partyId };
    if (opts.status) where.status = opts.status;
    const [rows, total] = await Promise.all([
      prisma.quotation.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: opts.skip,
        take: opts.take,
        select: quotationSelect,
      }),
      prisma.quotation.count({ where }),
    ]);
    return { data: rows.map(toDTO), total };
  }

  async setArchived(shopId: number, id: number, archived: boolean) {
    const row = await prisma.quotation.findFirst({
      where: { id, shopId },
      select: { status: true, archivedAt: true },
    });
    if (!row) return { error: 'Quotation not found' as const };

    if (archived && (row.status === 'REQUESTED' || row.status === 'PENDING')) {
      return {
        error:
          'Cannot archive a quotation the customer can still act on — cancel it first, then archive it.' as const,
      };
    }

    const alreadyInState = archived === (row.archivedAt !== null);
    if (!alreadyInState) {
      await prisma.quotation.update({
        where: { id },
        data: { archivedAt: archived ? new Date() : null },
      });
    }
    return { quotation: await this.getForShop(shopId, id) };
  }

  async getForShop(shopId: number, id: number) {
    const row = await prisma.quotation.findFirst({
      where: { id, shopId },
      select: quotationSelect,
    });
    return row ? toDTO(row) : null;
  }

  async getForParty(shopId: number, partyId: number, id: number) {
    const row = await prisma.quotation.findFirst({
      where: { id, shopId, partyId },
      select: quotationSelect,
    });
    return row ? toDTO(row) : null;
  }

  async accept(shopId: number, partyId: number, id: number, userId: number) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { linkedUserId: true },
    });
    if (!party || party.linkedUserId !== userId) {
      throw new HttpError(403, 'FORBIDDEN', 'Not your party');
    }

    const quotation = await prisma.quotation.findFirst({
      where: { id, shopId, partyId },
      select: {
        id: true,
        items: true,
        note: true,
        placeOfSupplyStateCode: true,
        createdById: true,
        shop: { select: { ownerUserId: true } },
      },
    });
    if (!quotation) {
      throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
    }

    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, status: 'PENDING' },
      data: { status: 'ACCEPTED', respondedAt: new Date() },
    });
    if (claimed.count === 0) {
      throw new HttpError(
        409,
        'QUOTATION_NOT_PENDING',
        'This quotation is no longer open',
      );
    }

    const lines = (quotation.items as unknown as Array<{
      productId: number;
      quantity: number;
      unitPrice: number;
      taxPercent?: number;
      cessRate?: number;
      isPriceInclusive?: boolean;
      discount?: number;
    }>);

    const restorePending = () =>
      prisma.quotation.updateMany({
        where: { id, shopId, status: 'ACCEPTED' },
        data: { status: 'PENDING', respondedAt: null },
      });

    let result;
    try {
      result = await invoicesService.createInvoice({
        shopId,
        type: 'SALE',
        documentType: 'TAX_INVOICE',
        partyId,
        placeOfSupplyStateCode: quotation.placeOfSupplyStateCode ?? undefined,
        note: quotation.note ?? undefined,
        items: lines.map((l) => ({
          productId: l.productId,
          quantity: l.quantity,
          unitPrice: l.unitPrice,
          taxPercent: l.taxPercent,
          cessRate: l.cessRate,
          isPriceInclusive: l.isPriceInclusive,
          discount: l.discount,
        })),
        confirm: true,
        confirmedById: userId,
      });
    } catch (err) {
      await restorePending();
      throw err;
    }

    if ('error' in result || !('confirmed' in result) || !result.confirmed) {
      await restorePending();
      if (!('error' in result) && result.invoice?.id) {
        await invoicesService.setArchived(shopId, result.invoice.id, true).catch(() => {});
      }
      const reason =
        'error' in result
          ? result.error
          : result.confirmError?.error ?? 'Could not confirm the invoice';
      throw new HttpError(409, 'QUOTATION_ACCEPT_FAILED', String(reason));
    }

    const updated = await prisma.quotation.update({
      where: { id },
      data: { invoiceId: result.invoice.id },
      select: quotationSelect,
    });

    const merchantUserId = quotation.createdById ?? quotation.shop.ownerUserId;
    await prisma.notification.create({
      data: {
        userId: merchantUserId,
        kind: 'QUOTATION_ACCEPTED',
        title: 'Quotation accepted',
        body: `${updated.quotationNo} accepted → invoice ${result.invoice.invoiceNo}`,
        data: {
          quotationId: id,
          partyId,
          invoiceId: result.invoice.id,
        },
      },
    });

    return toDTO(updated);
  }

  async decline(
    shopId: number,
    partyId: number,
    id: number,
    declineNote?: string | null,
  ) {
    const quotation = await prisma.quotation.findFirst({
      where: { id, shopId, partyId },
      select: {
        id: true,
        quotationNo: true,
        createdById: true,
        shop: { select: { ownerUserId: true } },
      },
    });
    if (!quotation) {
      throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
    }
    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, status: 'PENDING' },
      data: {
        status: 'DECLINED',
        respondedAt: new Date(),
        declineNote: declineNote ?? null,
      },
    });
    if (claimed.count === 0) {
      throw new HttpError(
        409,
        'QUOTATION_NOT_PENDING',
        'This quotation is no longer open',
      );
    }

    const merchantUserId = quotation.createdById ?? quotation.shop.ownerUserId;
    await prisma.notification.create({
      data: {
        userId: merchantUserId,
        kind: 'QUOTATION_DECLINED',
        title: 'Quotation declined',
        body: declineNote
          ? `${quotation.quotationNo}: ${declineNote}`
          : `${quotation.quotationNo} was declined`,
        data: { quotationId: id, partyId },
      },
    });

    const updated = await prisma.quotation.findUniqueOrThrow({
      where: { id },
      select: quotationSelect,
    });
    return toDTO(updated);
  }

  async cancel(shopId: number, id: number) {
    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, status: 'PENDING' },
      data: { status: 'CANCELLED', respondedAt: new Date() },
    });
    if (claimed.count === 0) {
      const exists = await prisma.quotation.findFirst({
        where: { id, shopId },
        select: { id: true },
      });
      if (!exists) {
        throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
      }
      throw new HttpError(
        409,
        'QUOTATION_NOT_PENDING',
        'This quotation is no longer open',
      );
    }
    const updated = await prisma.quotation.findUniqueOrThrow({
      where: { id },
      select: quotationSelect,
    });
    return toDTO(updated);
  }

  async requestByCustomer(
    shopId: number,
    partyId: number,
    requestedById: number,
    input: { items: QuotationItemInput[]; note?: string | null },
  ) {
    const shop = await prisma.shop.findUnique({
      where: { id: shopId },
      select: {
        ownerUserId: true,
        owner: {
          select: { shopGstin: true, registrationType: true, gstEffectiveFrom: true },
        },
      },
    });
    if (!shop) return { error: 'PARTY_NOT_FOUND' as const };

    const repriced = await repriceFromMaster(shopId, input.items);
    if (repriced.length === 0) {
      return { error: 'NO_VALID_ITEMS' as const };
    }
    const priced = priceItems(repriced, isOutputGstRegistered(shop.owner, new Date()));

    const created = await prisma.$transaction(async (tx) => {
      const quotationNo = await nextQuotationNo(shopId, new Date(), tx);
      const row = await tx.quotation.create({
        data: {
          shopId,
          partyId,
          quotationNo,
          status: 'REQUESTED',
          items: priced.lines as unknown as Prisma.InputJsonValue,
          subtotal: new Prisma.Decimal(priced.subtotal),
          taxAmount: new Prisma.Decimal(priced.taxAmount),
          total: new Prisma.Decimal(priced.total),
          note: input.note ?? null,
          requestedById,
        },
        select: quotationSelect,
      });

      await tx.notification.create({
        data: {
          userId: shop.ownerUserId,
          kind: 'QUOTATION_REQUESTED',
          title: 'New quote request',
          body: `${row.party.name} requested a quote · ${priced.lines.length} item(s)`,
          data: { quotationId: row.id, partyId },
        },
      });

      return row;
    });

    return { quotation: toDTO(created) };
  }

  async respondToRequest(
    shopId: number,
    id: number,
    createdById: number,
    input: {
      items: QuotationItemInput[];
      note?: string | null;
      placeOfSupplyStateCode?: string | null;
    },
  ) {
    const existing = await prisma.quotation.findFirst({
      where: { id, shopId },
      select: { id: true, requestedById: true },
    });
    if (!existing) {
      throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
    }

    const [hydrated, chargesGst] = await Promise.all([
      hydrateRates(shopId, input.items),
      chargesOutputGstForSale(prisma, shopId, new Date()),
    ]);
    const priced = priceItems(hydrated, chargesGst);
    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, status: 'REQUESTED' },
      data: {
        status: 'PENDING',
        items: priced.lines as unknown as Prisma.InputJsonValue,
        subtotal: new Prisma.Decimal(priced.subtotal),
        taxAmount: new Prisma.Decimal(priced.taxAmount),
        total: new Prisma.Decimal(priced.total),
        note: input.note ?? null,
        placeOfSupplyStateCode: input.placeOfSupplyStateCode ?? null,
        createdById,
      },
    });
    if (claimed.count === 0) {
      throw new HttpError(
        409,
        'QUOTATION_NOT_REQUESTED',
        'This request has already been handled',
      );
    }

    const updated = await prisma.quotation.findUniqueOrThrow({
      where: { id },
      select: quotationSelect,
    });

    if (existing.requestedById) {
      await prisma.notification.create({
        data: {
          userId: existing.requestedById,
          kind: 'QUOTATION_RECEIVED',
          title: 'Your quote is ready',
          body: `${updated.quotationNo} · ₹${priced.total.toFixed(2)} · ${priced.lines.length} item(s)`,
          data: { quotationId: id, partyId: updated.partyId, total: priced.total },
        },
      });
    }

    return toDTO(updated);
  }

  async declineRequest(shopId: number, id: number, declineNote?: string | null) {
    const existing = await prisma.quotation.findFirst({
      where: { id, shopId },
      select: { id: true, quotationNo: true, requestedById: true },
    });
    if (!existing) {
      throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
    }
    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, status: 'REQUESTED' },
      data: {
        status: 'DECLINED',
        respondedAt: new Date(),
        declineNote: declineNote ?? null,
      },
    });
    if (claimed.count === 0) {
      throw new HttpError(
        409,
        'QUOTATION_NOT_REQUESTED',
        'This request has already been handled',
      );
    }

    if (existing.requestedById) {
      await prisma.notification.create({
        data: {
          userId: existing.requestedById,
          kind: 'QUOTATION_REQUEST_DECLINED',
          title: 'Quote request declined',
          body: declineNote
            ? `${existing.quotationNo}: ${declineNote}`
            : `${existing.quotationNo} was declined`,
          data: { quotationId: id },
        },
      });
    }

    const updated = await prisma.quotation.findUniqueOrThrow({
      where: { id },
      select: quotationSelect,
    });
    return toDTO(updated);
  }

  async cancelRequest(shopId: number, partyId: number, id: number) {
    const claimed = await prisma.quotation.updateMany({
      where: { id, shopId, partyId, status: 'REQUESTED' },
      data: { status: 'CANCELLED', respondedAt: new Date() },
    });
    if (claimed.count === 0) {
      const exists = await prisma.quotation.findFirst({
        where: { id, shopId, partyId },
        select: { id: true },
      });
      if (!exists) {
        throw new HttpError(404, 'QUOTATION_NOT_FOUND', 'Quotation not found');
      }
      throw new HttpError(
        409,
        'QUOTATION_NOT_REQUESTED',
        'This request can no longer be cancelled',
      );
    }
    const updated = await prisma.quotation.findUniqueOrThrow({
      where: { id },
      select: quotationSelect,
    });
    return toDTO(updated);
  }

  async streamPdf(
    shopId: number,
    id: number,
    out: Writable,
    onReady: () => void,
  ): Promise<{ error: string } | null> {
    const result = await renderQuotationPdf(shopId, id, out, onReady);
    if (result && typeof result === 'object' && 'error' in result) return result;
    return null;
  }
}

export const quotationsService = new QuotationsService();
