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

/// A line the merchant added to the quotation bucket.
export interface QuotationItemInput {
  productId: number;
  name: string;
  sku?: string | null;
  quantity: number;
  unitPrice: number;
  taxPercent?: number | null;
  /// GST compensation cess (tobacco / luxury / aerated). Carried through
  /// to the spawned invoice so a cess-bearing quote isn't under-billed.
  cessRate?: number | null;
  /// Whether unitPrice already contains GST. Frozen onto the line at
  /// hydrate time (same as taxPercent/cessRate) so a merchant changing a
  /// product's pricingMode after this quote was sent can't retroactively
  /// change what the customer already saw and is about to accept.
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
/// Estimate the quotation totals. This is a PREVIEW only — when a customer
/// accepts, accept() re-prices the same lines through invoicesService (the
/// authoritative GST engine), which additionally applies cess, the CGST/SGST
/// place-of-supply split and invoice-level round-off. Rounding here mirrors the
/// invoice engine's per-line round2 so the common (no-cess) estimate matches.
///
/// `chargesGst` is this shop's registration gate (see gst-registration-gate.ts)
/// — the SAME check the invoice engine applies at accept() time. Without it, a
/// COMPOSITION/UNREGISTERED shop's quotation preview showed a full GST
/// breakdown that the spawned invoice then silently zeroed out — the quoted
/// total and the accepted invoice's total disagreeing is exactly the bug this
/// gate closes. Mirrors resolveInvoiceFields's `chargesOutputGst ? … : 0`.
function priceItems(items: QuotationItemInput[], chargesGst: boolean) {
  let subtotal = 0;
  let taxAmount = 0;
  const lines = items.map((it) => {
    const qty = it.quantity;
    // Clamp the discount to the line's gross so a quote can never preview a
    // negative line (and so the spawned invoice — which also clamps — agrees).
    const gross = round2(qty * it.unitPrice);
    const discount = Math.min(Math.max(0, it.discount ?? 0), gross);
    const lineAmount = round2(gross - discount);
    const taxPercent = chargesGst ? it.taxPercent ?? 0 : 0;
    const cessRate = chargesGst ? it.cessRate ?? 0 : 0;
    // GST-5 — inclusive vs exclusive, mirroring resolveInvoiceFields: an
    // inclusive line's amount already contains GST + cess, so back it out;
    // an exclusive line adds tax on top of the full discounted amount.
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
  // CWQ-3: keep total === subtotal + taxAmount so the stored quotation row (and
  // every PDF/DTO derived from it) reconciles with its own breakup. The quote
  // has no roundOff field, so rounding the grand total to the nearest rupee
  // (the old `Math.round`) left `subtotal + taxAmount !== total` by up to ₹0.49.
  // The invoice engine reconciles via an explicit roundOff line; without that
  // column here we must not rupee-round, or the breakup stops adding up. accept()
  // re-prices through invoicesService anyway, so this stays a faithful estimate.
  const total = round2(netSubtotal + netTax);
  return {
    lines,
    subtotal: netSubtotal,
    taxAmount: netTax,
    total,
  };
}

/// CWQ-4: re-source unitPrice/discount (and rates) from the product master for
/// a CUSTOMER-originated request. A linked customer's basket carries advisory
/// prices the client typed; those must NEVER be persisted as the quotation
/// figures (defense-in-depth — if any future path lets a REQUESTED quote be
/// accepted without a merchant re-price, customer-controlled prices would flow
/// to the invoice). We overwrite unitPrice with the product's current
/// sellingPrice, zero the discount (a customer can't grant themselves one), and
/// drop any unknown product line. The merchant still re-prices on
/// respondToRequest before the quote becomes acceptable.
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
    // Silently skip a line whose product isn't in this shop — a customer
    // request must not seed an invoice line at a client-chosen price.
    if (!p) continue;
    // The customer's own request must not carry the pricing CONVENTION any
    // more than it carries the price itself — always the product's own
    // resolved mode, never something the client could imply.
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

/// Fill missing GST / cess rate / inclusive-flag from the product master
/// before pricing. A quote line that omits taxPercent/cessRate must inherit
/// the product's statutory rate — priceItems would otherwise snapshot 0, and
/// accept() then passes that stored 0 to the invoice engine as an EXPLICIT
/// rate, overriding the engine's own product fallback (the C1 "₹0 GST" bug
/// resurfacing via the quotation path). An explicit rate — including a
/// deliberate 0 for exempt/nil-rated lines — always wins. Same treatment for
/// isPriceInclusive: it's frozen onto the line HERE (creation/response time),
/// not left to resolve live at accept() — otherwise a merchant flipping a
/// product's pricingMode between sending the quote and the customer
/// accepting it would retroactively change what was already quoted.
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

/// Merchant-built quotations sent to a linked customer for acceptance. The
/// accept path is the single point that turns a quotation into a real invoice
/// (via invoicesService.createInvoice with confirm).
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

    const [hydrated, chargesGst] = await Promise.all([
      hydrateRates(shopId, input.items),
      chargesOutputGstForSale(prisma, shopId, new Date()),
    ]);
    const priced = priceItems(hydrated, chargesGst);

    const created = await prisma.$transaction(async (tx) => {
      // Allocate inside the txn so a rollback doesn't burn the QUO counter.
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
    // QUO-1 (defense-in-depth): re-assert the party-link ownership inside
    // the service rather than trusting the controller's `assertOwnsParty`.
    // If a second, unguarded caller is ever added this prevents an IDOR.
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
      cessRate?: number;
      isPriceInclusive?: boolean;
      discount?: number;
    }>);

    // Undo the PENDING→ACCEPTED claim so the customer can retry. Used on both
    // the returned-error path and the (infra) throw path below.
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
          // Frozen at quote-hydrate time (see hydrateRates) — passed through
          // explicitly so the invoice bills under the SAME convention the
          // customer was quoted, not whatever the product's live pricingMode
          // happens to be by the time they accept.
          isPriceInclusive: l.isPriceInclusive,
          discount: l.discount,
        })),
        confirm: true,
        confirmedById: userId,
      });
    } catch (err) {
      // createInvoice is documented not to throw on a domain problem, but an
      // infra failure (DB, numbering, serialization abort) must not leave the
      // quotation stuck ACCEPTED with no invoice — release the claim and
      // propagate so the customer can retry.
      await restorePending();
      throw err;
    }

    // On a returned domain error or a failed confirm, undo the claim too.
    if ('error' in result || !('confirmed' in result) || !result.confirmed) {
      await restorePending();
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
  /// re-prices on `respondToRequest`. Notifies the shop owner.
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

    // CWQ-4: re-source prices/discounts server-side from the product master —
    // never persist the customer-supplied unitPrice/discount as the figures.
    const repriced = await repriceFromMaster(shopId, input.items);
    if (repriced.length === 0) {
      return { error: 'NO_VALID_ITEMS' as const };
    }
    // Quotations have no backdating concept — always gated as of "now".
    const priced = priceItems(repriced, isOutputGstRegistered(shop.owner, new Date()));

    const created = await prisma.$transaction(async (tx) => {
      // Allocate inside the txn so a rollback doesn't burn the QUO counter.
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

    const [hydrated, chargesGst] = await Promise.all([
      hydrateRates(shopId, input.items),
      chargesOutputGstForSale(prisma, shopId, new Date()),
    ]);
    const priced = priceItems(hydrated, chargesGst);
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
