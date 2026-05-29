import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { Writable } from 'stream';
import { nextQuotationNo } from '../../shared/numbering/sequences.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import { invoicesService } from '../invoices/invoices.service.js';
import { renderQuotationPdf } from './quotation-pdf-renderer.js';

export type QuotationStatus =
  | 'REQUESTED'
  | 'PENDING'
  | 'ACCEPTED'
  | 'DECLINED'
  | 'CANCELLED'
  | 'EXPIRED';

function toNumber(value: Prisma.Decimal | number | null | undefined): number {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  return Number(value.toString());
}

/// A line the merchant added to the quotation bucket.
export interface QuotationItemInput {
  productId: number;
  name: string;
  sku?: string | null;
  quantity: number;
  unitPrice: number;
  taxPercent?: number | null;
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

/// Compute a per-line total + the quotation roll-up. This drives the display
/// figures; the authoritative GST split is recomputed by invoicesService when
/// the customer accepts (so cess/place-of-supply nuances stay in one engine).
function priceItems(items: QuotationItemInput[]) {
  let subtotal = 0;
  let taxAmount = 0;
  const lines = items.map((it) => {
    const qty = it.quantity;
    const taxable = Math.max(0, qty * it.unitPrice - (it.discount ?? 0));
    const tax = (taxable * (it.taxPercent ?? 0)) / 100;
    subtotal += taxable;
    taxAmount += tax;
    return {
      productId: it.productId,
      name: it.name,
      sku: it.sku ?? null,
      quantity: qty,
      unitPrice: it.unitPrice,
      taxPercent: it.taxPercent ?? 0,
      discount: it.discount ?? 0,
      imageUrl: it.imageUrl ?? null,
      lineTotal: Math.round((taxable + tax) * 100) / 100,
    };
  });
  const round = (n: number) => Math.round(n * 100) / 100;
  return {
    lines,
    subtotal: round(subtotal),
    taxAmount: round(taxAmount),
    total: round(subtotal + taxAmount),
  };
}

/// Merchant-built quotations sent to a linked customer for acceptance. The
/// accept path is the single point that turns a quotation into a real invoice
/// (via invoicesService.createInvoice with confirm) — mirrors the caution
/// request→approve flow, just merchant→customer instead of customer→merchant.
export class QuotationsService {
  /// Merchant creates + sends a quotation to a LINKED party. Returns
  /// `{ error }` when the party isn't in this shop or isn't app-linked.
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

    const priced = priceItems(input.items);
    const quotationNo = await nextQuotationNo(shopId, new Date());

    const created = await prisma.$transaction(async (tx) => {
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
    opts: { status?: QuotationStatus; skip: number; take: number },
  ) {
    const where: Prisma.QuotationWhereInput = { shopId };
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

  /// Customer accepts a PENDING quotation → spawns a CONFIRMED sale invoice
  /// from the stored line items (authoritative GST via invoicesService), links
  /// it back, and notifies the merchant. The status claim is the race guard;
  /// if the invoice can't be confirmed (e.g. stock) the claim is rolled back.
  async accept(shopId: number, partyId: number, id: number, userId: number) {
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

    // Claim PENDING → ACCEPTED first so concurrent accepts can't both invoice.
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
      discount?: number;
    }>);

    const result = await invoicesService.createInvoice({
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
        discount: l.discount,
      })),
      confirm: true,
      confirmedById: userId,
    });

    // createInvoice never throws on a domain problem — it returns { error } or
    // a confirmError. Either way, undo the claim so the customer can retry.
    if ('error' in result || !('confirmed' in result) || !result.confirmed) {
      await prisma.quotation.updateMany({
        where: { id, shopId, status: 'ACCEPTED' },
        data: { status: 'PENDING', respondedAt: null },
      });
      // Best-effort cleanup of a left-over draft invoice.
      if (!('error' in result) && result.invoice?.id) {
        await invoicesService.deleteInvoice(shopId, result.invoice.id).catch(() => {});
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

  /// Customer declines a PENDING quotation; notifies the merchant.
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

  /// Merchant cancels a PENDING quotation they sent.
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

  /// A LINKED customer builds a basket and asks the shop for a quote. Lands as
  /// status REQUESTED (no `createdById` yet); prices are advisory — the merchant
  /// re-prices on `respondToRequest`. Notifies the shop owner. Mirror of the
  /// caution request→approve flow, customer→merchant.
  async requestByCustomer(
    shopId: number,
    partyId: number,
    requestedById: number,
    input: { items: QuotationItemInput[]; note?: string | null },
  ) {
    const shop = await prisma.shop.findUnique({
      where: { id: shopId },
      select: { ownerUserId: true },
    });
    if (!shop) return { error: 'PARTY_NOT_FOUND' as const };

    const priced = priceItems(input.items);
    const quotationNo = await nextQuotationNo(shopId, new Date());

    const created = await prisma.$transaction(async (tx) => {
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

  /// Merchant prices a REQUESTED quote (edits items/note/place-of-supply) and
  /// sends it → status PENDING, now an ordinary quotation the customer accepts.
  /// Stamps `createdById` and notifies the requesting customer.
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

    const priced = priceItems(input.items);
    // Claim REQUESTED → PENDING so two merchants can't both send it.
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

  /// Merchant declines a REQUESTED quote; notifies the requesting customer.
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

  /// Customer withdraws their own REQUESTED quote → CANCELLED. Guarded by
  /// partyId so a customer can only cancel their own shop's request.
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

  /// Stream the quotation as a PDF into `out`. `onReady` fires right before
  /// bytes flow (so the controller can flip response headers); returns
  /// `{ error }` if the quotation isn't found for this shop.
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
