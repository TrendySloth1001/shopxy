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
  /// CAT-H1 — when the sold line is a specific product variant, the GST
  /// source (HSN / taxPercent) is taken from THAT variant rather than the
  /// product row, since two variants of one product can legitimately sit in
  /// different HSN/GST slabs. A null hsnCode / 0% taxPercent on the variant
  /// falls back to the product's slab (see resolveInvoiceFields). The variant
  /// must belong to `productId` within the invoice's shop or it is ignored.
  variantId?: number | null;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  cessRate?: number;
  discount?: number;
  /// GST-5 — when true `unitPrice` already includes GST + cess (MRP /
  /// marketplace "inclusive of all taxes" path). The engine then BACKS the
  /// tax out of the price (taxable = price * 100 / (100 + rate)) instead of
  /// adding it on top. Default false preserves the legacy exclusive merchant
  /// manual-invoice behaviour. Recorded per line on InvoiceItem.
  isPriceInclusive?: boolean;
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
  /// GST-5 — invoice-wide default for `isPriceInclusive` when a line omits
  /// its own flag. The customer-order / checkout path sets this true so MRP
  /// prices have tax backed out; the merchant manual invoice leaves it false.
  isPriceInclusive?: boolean;
  /// GST-7 — when set, forces the interstate/IGST-vs-CGST/SGST split instead
  /// of re-deriving it from the (current) customer/shop state. Credit notes
  /// pass the ORIGINAL invoice's stored `isInterstate` so the reversal mirrors
  /// the original document's place-of-supply, not today's shop state.
  isInterstateOverride?: boolean;
  /// GST-6 — skip the ≥₹50k / GSTIN recipient-name+address hard block. Set by
  /// the live preview (display must never fail on recipient completeness) and by
  /// the POS counter-sale commit (an anonymous walk-in B2C consolidated bill is
  /// exempt from the named-recipient block). The merchant manual-invoice path
  /// leaves it unset so a high-value/B2B manual invoice still requires recipient
  /// details. NOTE: POS should still capture customer name+address for ≥₹50k
  /// sales per Rule 46(f) — deferred UI work, see FIX_REVIEW_AND_PLAN.md.
  skipRecipientDetailGuard?: boolean;
}

/// Thrown by `createConfirmedSaleInTx` so a failed POS checkout rolls the whole
/// transaction back with a structured reason (surfaced to the till).
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
    /// GST-5 — invoice-wide default tax-inclusive flag (see ResolveInvoiceInput).
    /// The checkout / customer-order unit passes true so MRP-style prices have
    /// GST backed out; omitted (false) keeps the merchant manual exclusive path.
    isPriceInclusive?: boolean;
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

    // Number allocation runs INSIDE the same transaction as the insert —
    // previously it ran on the bare client before this block even opened,
    // so a failed create still burned a sequence number (a permanent gap
    // with no document to explain it). Enrolling it here means a rollback
    // rolls back the counter bump too.
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

  /// POS support: compute the GST split + totals for a set of lines WITHOUT
  /// writing anything. Lets the POS cart show live, server-authoritative totals
  /// using the exact same math the bill will use. Returns the same
  /// `{ header, itemsData }` shape as the internal resolver, or `{ error }`.
  async previewSaleTotals(data: ResolveInvoiceInput) {
    // Preview is display-only — never fail it on recipient completeness (the POS
    // bill / live invoice preview must render a ≥₹50k cart total). The hard block
    // applies only when the document is actually persisted (merchant manual path).
    return this.resolveInvoiceFields({ ...data, skipRecipientDetailGuard: true });
  }

  /// POS support: create an already-CONFIRMED sale invoice (with stock posted
  /// via the ledger) inside a caller-provided transaction. This is the invoice
  /// half of the single-transaction POS checkout (the payment is recorded in
  /// the same `tx` by the POS service), so a sale is fully all-or-nothing.
  ///
  /// Reuses `resolveInvoiceFields` (identical tax math), `nextInvoiceNo` and
  /// `ledgerService.post` — no duplicated billing logic. Throws on a resolver
  /// error or insufficient stock so the surrounding transaction rolls back.
  async createConfirmedSaleInTx(
    tx: Prisma.TransactionClient,
    data: ResolveInvoiceInput,
    createdById?: number,
  ) {
    // POS counter sale: an anonymous walk-in B2C consolidated bill is exempt from
    // the GST-6 named-recipient hard block (the 269ST cash ceiling + other guards
    // still apply upstream). High-value POS recipient capture is deferred UI work.
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

    // Stock OUT — same posting shape as the DRAFT→CONFIRMED path in
    // updateStatus, with the same idempotency key, so it dedupes identically.
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

    // Outbox (same tx): a POS sale is born CONFIRMED, so its roll-up event fires
    // the moment the checkout commits. occurredAt = invoiceDate so the handler
    // buckets into the same IST day the changefeed would.
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

  /// Create a CONFIRMED **credit note** (sales return) inside a tx: mirrors
  /// `createConfirmedSaleInTx` but restocks the goods (stock IN, reason
  /// RETURN_IN) and links the original SALE invoice. The returned items carry
  /// the original unit price + frozen tax so the credit note reverses GST
  /// proportionally. Idempotency key namespaced per credit-note invoice.
  ///
  /// LAW: CGST Act 2017, Sec 34 — a registered supplier must issue a CREDIT
  /// NOTE for goods returned (or a downward revision), reversing the output tax
  /// originally charged. We reverse on the SAME side the sale charged it (IGST
  /// vs CGST+SGST) using the original invoice's frozen place-of-supply, and the
  /// note is a sequentially-numbered, retained document (CGST Sec 36 / Rule 56),
  /// never a silent edit of the original. The MONEY leg (returning what the
  /// buyer paid) is separate — see returns.service → refundToSource.
  async createSalesReturnInTx(
    tx: Prisma.TransactionClient,
    data: ResolveInvoiceInput & { originalInvoiceId: number },
    createdById?: number,
    /// CASH-1 — the cashier till session this credit note is issued from, so a
    /// cash refund reconciles against the right shift's Z-report drawer.
    shiftId?: number,
  ) {
    // GST-7 — derive the IGST-vs-CGST/SGST split from the ORIGINAL invoice's
    // STORED place-of-supply, not the shop's current state. A shop that
    // re-registered in another state since the sale must still reverse tax on
    // the same side the original invoice charged it. We read the original's
    // cached `isInterstate` + place-of-supply within the same tx and force them.
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
        // CASH-1 — tie the credit note to the issuing cashier + shift so the
        // Z-report's returns aggregation can scope by shiftId, not a window.
        createdById: createdById ?? null,
        shiftId: shiftId ?? null,
        items: { create: itemsData },
      },
      include: { items: true },
    });

    // Outbox (same tx): a credit note is a CONFIRMED sale document that reduces
    // the day's net sales / reverses GST, so it feeds the roll-up exactly like a
    // sale confirm. Emitting right after creation means a later stock-restock
    // failure rolls the event back with the whole transaction.
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

    // Stock IN — the returned goods come back to the shelf. PR-H1: restock at
    // the ORIGINAL sale's cost basis by restoring the layers the sale consumed,
    // not by minting a fresh averaged layer at the sale price. `ledgerService
    // .post(direction:'IN')` always creates a new cost layer, which inflates
    // on-hand value and drifts the moving-average after every sale+return
    // round-trip. `restockReturnAtCost` mirrors the OUT-reversal branch of
    // `reverse()` and supports partial returns. For any legacy line whose
    // original FIFO consumptions can't be located it returns
    // 'No original consumption'; we then fall back to the averaged restock for
    // just those lines (still creates a layer, but only where no history exists).
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
        // Legacy sale with no cost-layer history — fall back to the averaged
        // restock (creates a layer at the sale's unit price) so the goods still
        // come back to the shelf. Same idempotency key namespace.
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

  /// Merchant-issued credit / debit note raised from an existing invoice's
  /// detail screen — the manual Sec 34 path, distinct from the POS / order
  /// refund path (which stays on `createSalesReturnInTx` because it also
  /// settles money). A CREDIT_NOTE reduces the buyer's liability (signed
  /// negative in every roll-up) and, when the goods physically come back,
  /// restocks at the original cost basis; a DEBIT_NOTE raises the liability
  /// (undercharge / supplementary supply) and never touches stock. Both are
  /// CONFIRMED, sequentially numbered (CRN / DBN), retained documents that
  /// reference the original invoice and inherit its GST place-of-supply so
  /// the adjustment mirrors the source document, not today's shop state.
  async createAdjustmentNoteFromInvoice(
    shopId: number,
    originalInvoiceId: number,
    input: {
      documentType: 'CREDIT_NOTE' | 'DEBIT_NOTE';
      reason?: string;
      /// Credit notes only. Default true — the returned goods go back on the
      /// shelf. Set false for a value-only credit note (post-sale discount /
      /// price correction) where nothing physically comes back.
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

      // Each note line must reference a product that was actually on the
      // original invoice — you cannot credit/debit goods that were never sold
      // on this document. GST slab / cess / inclusive flag are inherited from
      // the ORIGINAL line so the reversal mirrors the source tax exactly.
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
          // Credit note reverses what was charged → original unit price.
          // Debit note bills a supplementary amount → merchant-entered price.
          unitPrice:
            input.documentType === 'CREDIT_NOTE'
              ? Number(orig.unitPrice)
              : (line.unitPrice ?? 0),
          taxPercent: Number(orig.taxPercent),
          cessRate: Number(orig.cessRate),
          isPriceInclusive: orig.isPriceInclusive,
        });
      }

      // CREDIT_NOTE over-credit guard: the cumulative credited quantity per
      // product across ALL confirmed credit notes on this invoice (this manual
      // path AND the refund path both set originalInvoiceId) can't exceed what
      // was sold — otherwise a merchant could refund/restock more units than
      // they billed. Debit notes have no upper bound (they add value).
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
          // GST-7 — force the original's stored interstate split so the note
          // reverses/adds tax on the same side (IGST vs CGST/SGST) as the source.
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

      // Feed the roll-ups in the SAME tx as the document (a later restock
      // failure rolls the event back too). The aggregation's document_type
      // CASE signs a CREDIT_NOTE negative and a DEBIT_NOTE positive.
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

      // Goods physically returned → restock at the ORIGINAL sale's cost basis
      // (mirrors createSalesReturnInTx). On-hand quantity is always restored
      // exactly; the over-credit guard above bounds the total to what was sold.
      // Debit notes and value-only credit notes never move stock.
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
            // Legacy sale with no cost-layer history — averaged restock so the
            // goods still return to the shelf (same idempotency namespace).
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

  /// Pure resolution step shared by create + update: party/vendor look-ups,
  /// product snapshots, GST split and total calculation. Returns either an
  /// `error` or the ready-to-write header + items payload.
  ///
  /// Query budget: ≤ 4 statements (party + vendor + shop owner + products),
  /// each one bounded — no per-item round trips.
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
    let documentType: DocumentType = data.documentType ?? 'TAX_INVOICE';

    // When called inside a transaction (POS checkout), read on the SAME
    // connection so price/tax/party are resolved within the serializable
    // boundary that locks stock — not a separate, possibly-stale snapshot.
    const db = tx ?? prisma;

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
      customerAddress = party.address ?? null;
      customerCity = party.city ?? null;
      customerState = party.state ?? null;
      customerStateCode = party.stateCode ?? null;
      customerPinCode = party.pinCode ?? null;
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

    // Hoisted above the GST registration gate below, which must compare
    // against this document's OWN date (a merchant can backdate an invoice)
    // rather than wall-clock "now" — a backdated invoice must be billed
    // under whatever registration state applied on its own date.
    const invoiceDate = data.invoiceDate ? new Date(data.invoiceDate) : new Date();

    // Shop owner identity drives IGST vs CGST+SGST. Looked up from the
    // owning Shop's owner User row, not the global "first OWNER" — that
    // pre-multi-tenant query went to whichever merchant was alphabetically
    // first and was the cause of cross-tenant invoice corruption.
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
    // A registered shop's GSTIN encodes its state in the first two digits.
    // Use it as the authoritative fallback when shopStateCode wasn't filled
    // in, so IGST-vs-CGST/SGST is never mis-determined on a tax invoice just
    // because the state field was left blank.
    const shopStateCode =
      shop?.owner.shopStateCode ?? (shopGstin ? shopGstin.slice(0, 2) : null);

    // ── GST registration gate ────────────────────────────────────────
    // Only a regular GST-registered person may collect output tax (CGST
    // Sec 32). REGULAR charges GST and issues tax invoices. COMPOSITION
    // holds a GSTIN but (Sec 10) cannot charge GST, and UNREGISTERED has no
    // GSTIN — both must issue a Bill of Supply with zero tax (Rule 49).
    // We therefore charge output GST on a SALE only for a REGULAR shop that
    // actually holds a GSTIN (belt-and-suspenders against a misconfigured row).
    //
    // PURCHASE documents record the *input* tax a vendor charged us, so
    // their tax is kept regardless of our own registration (an
    // unregistered buyer still pays the vendor's GST — it just isn't
    // claimable as ITC, which is a reporting concern, not a document one).
    const registrationType = shop?.owner.registrationType ?? 'UNREGISTERED';
    const gstEffectiveFrom = shop?.owner.gstEffectiveFrom ?? null;
    const isShopRegistered = isOutputGstRegistered(
      { shopGstin, registrationType, gstEffectiveFrom },
      invoiceDate,
    );
    const chargesOutputGst = data.type === 'SALE' ? isShopRegistered : true;

    // An unregistered shop can't issue a tax invoice — downgrade it to a
    // Bill of Supply so the document type matches the (zero) tax charged.
    if (data.type === 'SALE' && !isShopRegistered && documentType === 'TAX_INVOICE') {
      documentType = 'BILL_OF_SUPPLY';
    }

    // GST-10 — a B2B recipient's GSTIN encodes its state in the first two
    // digits. When the party row carries a GSTIN but no explicit `stateCode`
    // (a common gap on hand-entered parties), fall back to the GSTIN prefix so
    // an interstate B2B supply isn't silently mis-charged as CGST/SGST. The
    // shop side already derives its state from its own GSTIN the same way
    // (shopStateCode above); the recipient side must mirror it, otherwise the
    // place-of-supply defaults to the shop's state and IGST is never applied.
    if (data.type === 'SALE' && !customerStateCode && customerGstin) {
      const gstinStatePrefix = customerGstin.trim().slice(0, 2);
      if (isValidStateCode(gstinStatePrefix)) {
        customerStateCode = gstinStatePrefix;
      }
    }

    // Place of supply. For a sale it follows the customer's state; when the
    // customer's state is unknown (walk-in / B2C with no address) it defaults
    // to the shop's own state — a local intra-state supply (CGST+SGST), which
    // is the correct GST default rather than leaving POS null. For a purchase
    // it's the shop's state (where goods are received).
    const placeOfSupplyStateCode =
      data.placeOfSupplyStateCode ??
      (data.type === 'SALE' ? (customerStateCode ?? shopStateCode) : shopStateCode) ??
      null;
    // GST-7 — a credit note must reverse tax on the SAME side (IGST vs
    // CGST/SGST) as the original invoice, regardless of where the shop is
    // registered today. The caller (sales-return flow) passes the original's
    // stored `isInterstate` here so a shop that re-registered in another state
    // can't flip an old interstate sale's reversal to CGST/SGST. Falls back to
    // re-deriving from place-of-supply for all the non-credit-note paths.
    const isInterstate =
      data.isInterstateOverride ??
      isInterstateSupply(shopStateCode, placeOfSupplyStateCode);

    // GST-6 (Rule 46) — recipient identity validation. Only meaningful on a
    // SALE (the customer fields). Normalise a typed GSTIN to upper-case so the
    // regex (which expects A-Z) matches lower-cased input, then reject a
    // malformed value outright rather than printing an invalid GSTIN on a tax
    // invoice. A blank/absent GSTIN is allowed (B2C / unregistered recipient).
    if (data.type === 'SALE' && customerGstin) {
      customerGstin = customerGstin.trim().toUpperCase();
      if (!GSTIN_REGEX.test(customerGstin)) {
        return { error: 'Invalid recipient GSTIN' as const };
      }
    }

    // One findMany regardless of item count — no per-line lookups.
    const productIds = [...new Set(data.items.map((i) => i.productId))];
    const products = await db.product.findMany({
      where: { id: { in: productIds }, shopId: data.shopId },
      // `hsnRevision` rides along so each line can record which revision of the
      // rate master its frozen rate came from — see the stamp below.
      // `pricingMode` feeds resolveProductPricing() below — the product-driven
      // fallback for a line/invoice that omits its own isPriceInclusive/taxPercent.
      select: { id: true, name: true, sku: true, hsnCode: true, unit: true, stockQuantity: true, taxPercent: true, cessRate: true, hsnRevision: true, pricingMode: true },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of data.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    // CAT-H1 — variant-level GST source. When a line names a variantId, the
    // line's HSN/taxPercent must come from that variant (variants of one
    // product can differ in slab). Load only the variants referenced by the
    // lines, scoped to this shop's products (the parent product is already
    // shop-filtered above, so the productId IN guard inherits tenant scope).
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

    // Banner-promo auto-fill: a line where the merchant didn't type a
    // discount inherits the best currently-active banner promo for that
    // product (own shop only). An explicit value (including 0) always wins.
    const promos = await resolveActiveProductPromos(data.shopId, productIds, tx);

    // ── GST-4 — all per-line money math is Prisma.Decimal end-to-end ──
    // Float64 + Math.round drifts at the paisa on long invoices and on
    // tax-inclusive back-out; Decimal keeps every intermediate exact. We
    // round (HALF_UP, to 2dp) only at the points the law fixes a printed
    // figure: each line's discount, taxable value and per-component tax.
    const D = Prisma.Decimal;
    const HUNDRED = new D(100);
    const TWO = new D(2);
    const dround2 = (v: Prisma.Decimal): Prisma.Decimal =>
      v.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

    // GST-5 — invoice-wide inclusive default; a per-line flag still wins.
    // Deliberately NOT collapsed to `false` here (unlike before) — an omitted
    // invoice-wide flag must fall through to each line's own product's
    // pricingMode below, not silently become "exclusive" before the product
    // ever gets a say. See the isInclusive resolution further down.
    const inclusiveDefault = data.isPriceInclusive;

    // First pass: each line's gross value (qty * unitPrice) and its own
    // discount, clamped so a single line can never exceed its gross value.
    // An unbounded line discount would otherwise mint a negative taxable
    // value and negative output GST (a document invalid for GSTR-1). The
    // promo branch is already clamped via lineDiscount(); we clamp the
    // explicit branch the same way (defense in depth).
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
      // 0..gross inclusive — a 100% "free" line is legitimate; negative is not.
      const clamped = dround2(rawItemDiscount).clamp(new D(0), gross);
      return { item, gross, itemDiscount: clamped };
    });

    // Invoice-level (header) discount, clamped so the document total can
    // never go negative, then apportioned across lines BEFORE GST. Under
    // CGST Sec 15(3)(a) a discount recorded on the invoice reduces the
    // taxable value, so tax must be charged on the post-discount net — not
    // subtracted after tax (which would over-collect GST and leave the
    // stored taxable/tax irreconcilable with the billed amount).
    const baseTaxableTotal = dround2(
      lines.reduce((s, l) => s.add(l.gross.sub(l.itemDiscount)), new D(0)),
    );
    const headerDiscount = dround2(new D(data.discount ?? 0)).clamp(
      new D(0),
      baseTaxableTotal,
    );

    let subtotal = new D(0); // gross of all discounts (sum of qty * unitPrice)
    let taxableValueTotal = new D(0); // net taxable after every discount
    let igstTotal = new D(0);
    let cgstTotal = new D(0);
    let sgstTotal = new D(0);
    let cessTotal = new D(0);
    let headerAllocated = new D(0); // running sum so the last line absorbs drift

    const itemsData = lines.map((l, idx) => {
      const { item, gross, itemDiscount } = l;
      const product = productMap.get(item.productId)!;
      const lineBase = dround2(gross.sub(itemDiscount));

      // Proportional share of the header discount. The last line takes the
      // remainder so the apportioned shares re-sum to headerDiscount
      // exactly — no paisa lost or created.
      let headerShare: Prisma.Decimal;
      if (headerDiscount.lte(0) || baseTaxableTotal.lte(0)) {
        headerShare = new D(0);
      } else if (idx === lines.length - 1) {
        headerShare = dround2(headerDiscount.sub(headerAllocated));
      } else {
        headerShare = dround2(headerDiscount.mul(lineBase).div(baseTaxableTotal));
      }
      headerAllocated = dround2(headerAllocated.add(headerShare));

      // Full discount on this line = its own + its share of the header
      // discount, folded in so the per-line invariant holds:
      // taxableValue = qty * unitPrice - discount.
      const lineDiscountTotal = dround2(itemDiscount.add(headerShare));

      // GST registration gate: an unregistered seller charges no output
      // tax, so the effective rate is forced to 0 (the line then stores 0%,
      // matching the Bill of Supply it is issued under).
      //
      // When the caller omits taxPercent (the customer-order, challan and
      // quotation spawn paths all do), fall back to the product's own GST
      // rate rather than silently charging 0% — that omission was the C1
      // "every customer invoice carries ₹0 GST" bug. An explicit 0 from the
      // merchant create form still wins (exempt/nil-rated lines).
      // CAT-H1 — resolve the GST source for this line. A variant in a
      // different HSN/GST slab overrides the product's rate; a variant whose
      // taxPercent is 0 (the schema default = "not set, inherit") or whose
      // hsnCode is null falls back to the product. The variant must belong to
      // this line's product (else it's a stale/cross-product id → ignore it).
      const lineVariant =
        item.variantId != null ? variantMap.get(item.variantId) : undefined;
      const lineVariantForProduct =
        lineVariant && lineVariant.productId === item.productId ? lineVariant : undefined;
      const variantTaxPct = lineVariantForProduct
        ? new D(lineVariantForProduct.taxPercent ?? 0)
        : new D(0);
      const variantHsn = lineVariantForProduct?.hsnCode ?? null;

      // Product-driven defaults — the single source of truth for "does this
      // product's stored price already include GST, and what rate/cess apply
      // when a caller doesn't override them." NO_GST forces 0 here regardless
      // of what's still sitting on the row (belt-and-suspenders alongside the
      // write-time normalization in products.service.ts).
      const resolvedProductPricing = resolveProductPricing({
        taxPercent: Number(product.taxPercent ?? 0),
        cessRate: Number(product.cessRate ?? 0),
        pricingMode: product.pricingMode,
      });

      // Effective slab: variant's own rate when set (> 0), else the product's
      // resolved default. NO_GST is a product-level legal declaration a
      // variant can't opt out of, so it wins over a variant's own rate too.
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
      // Same fallback for compensation cess: omitting cessRate means "use
      // the product's statutory rate", not "cess-free" — an explicit 0
      // still wins (exempt categories).
      const cessRate = chargesOutputGst
        ? (item.cessRate !== undefined ? new D(item.cessRate) : productCessRate)
        : new D(0);

      // GST-5 — inclusive vs exclusive taxable value.
      //   exclusive (default): taxable = gross - discount, tax added on top.
      //   inclusive (MRP path): the discounted line amount ALREADY contains
      //     GST + cess, so back it out — taxable = amount * 100 / (100+rate+cess)
      //     and tax = amount - taxable. The combined divisor uses BOTH the GST
      //     rate and the cess rate because both are embedded in the MRP.
      //
      // Three-level fallback: an explicit per-line flag wins; else an
      // explicit invoice-wide flag; else the product's own pricingMode. Only
      // when NEITHER the line nor the invoice states a convention does the
      // product get a say — this is what lets merchant-web/POS/stock/challan-
      // conversion/quotation-accept (which all omit both) bill correctly per
      // product without every call site having to say so explicitly.
      const isInclusive =
        item.isPriceInclusive ?? inclusiveDefault ?? resolvedProductPricing.isPriceInclusive;
      const lineAmount = dround2(gross.sub(lineDiscountTotal)); // discounted line money
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
        // Compute the GST total first, then split, so CGST+SGST always
        // re-sum to that total (avoids one-paisa drift from independent
        // rounding of each half).
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

      // Which revision of the rate master this line's frozen rate came from.
      // Stamped ONLY when the line actually billed at the product's derived
      // rate: a per-line override or a variant's own slab has no master
      // provenance, and claiming one would corrupt the exact query this column
      // exists to answer ("which documents used the rate that turned out to be
      // wrong"). A wrong answer there is worse than a null.
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

    // GST-9 — `taxAmount` is a denormalised convenience column equal to
    // igst+cgst+sgst+cess. It is the ONLY write path that touches the four
    // component columns, so they can never silently desync here; but the column
    // is a footgun for any future write that updates a component without
    // re-deriving the total. We compute it from the SAME rounded header figures
    // we persist (not the raw running sums) and assert the invariant so a future
    // divergence trips loudly in dev/test rather than shipping a stale total.
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
    // The header discount is already baked into each line's taxable value,
    // so the grand total is simply net taxable + tax — never a post-tax
    // subtraction (which is what broke Sec 15(3) before).
    const grandTotalRaw = dround2(taxableValueTotal.add(taxAmount));
    // Round-off to the nearest whole rupee (CGST Sec 170) on Decimal.
    const roundedTotal = grandTotalRaw.toDecimalPlaces(0, Prisma.Decimal.ROUND_HALF_UP);
    const roundOff = dround2(roundedTotal.sub(grandTotalRaw));
    const total = dround2(grandTotalRaw.add(roundOff));
    const words = amountInWords(total.toNumber());

    // GST-6 (Rule 46(e)/(f)) — for a SALE tax invoice / bill of supply, the
    // recipient's name AND address are mandatory once the document is a B2B
    // invoice (a GSTIN is present) or the value reaches the ₹50,000
    // named-recipient threshold. Below that, a B2C consolidated/walk-in bill
    // may omit them. The customer-order path always carries a linked party so
    // this never blocks legitimate checkout; it guards the merchant
    // manual-invoice path against issuing a high-value or B2B invoice with an
    // unnamed/addressless recipient.
    //
    // Scoped to primary supply documents: CREDIT/DEBIT notes derive their
    // recipient from an already-validated original invoice (the returns flow
    // may not re-supply the address), and ESTIMATE/PROFORMA are pre-supply
    // offers not governed by Rule 46(e)/(f).
    const isPrimarySupplyDoc =
      documentType === 'TAX_INVOICE' || documentType === 'BILL_OF_SUPPLY';
    if (data.type === 'SALE' && isPrimarySupplyDoc && !data.skipRecipientDetailGuard) {
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
        // Header discount is distributed into the line-level `discount`
        // fields above, so the invoice-level field is 0 to avoid the PDF
        // (which sums header + line discounts) double-counting it.
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
    dateFrom?: string;
    dateTo?: string;
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
    // invoiceDate — when the document was issued, not createdAt.
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

      // Only goods documents move inventory. An ESTIMATE/PROFORMA is an
      // offer (confirming one used to decrement stock and then the
      // converted TAX_INVOICE decremented it AGAIN), and CREDIT/DEBIT
      // notes are value adjustments under Sec 34 — the physical goods
      // movement of a return is owned by the returns/stock-adjustment
      // flows, and posting a STOCK_OUT for a sale credit note was plainly
      // inverted anyway.
      const movesStock =
        invoice.documentType === 'TAX_INVOICE' ||
        invoice.documentType === 'BILL_OF_SUPPLY';

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
          // Refresh pure-contact fields only. The tax-determinant fields
          // (state / stateCode / gstin) are FROZEN at draft time: the
          // per-line IGST-vs-CGST/SGST split and isInterstate flag were
          // computed against the draft's place-of-supply, so refreshing
          // the printed state here without recomputing the split would
          // emit an internally inconsistent GST document (INV-1).
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
          // Tax-determinant fields (state / stateCode / gstin) frozen at
          // draft — see the party block above (INV-1).
          snapshotRefresh.vendorName = vendor.name;
          snapshotRefresh.vendorPhone = vendor.phone ?? null;
          snapshotRefresh.vendorAddress = vendor.address ?? null;
          snapshotRefresh.vendorCity = vendor.city ?? null;
          snapshotRefresh.vendorPinCode = vendor.pinCode ?? null;
          snapshotRefresh.vendorPanNumber = vendor.panNumber ?? null;
        }
      }

      // ── DRAFT → CONFIRMED: post stock movements ────────────────────
      if (invoice.status === 'DRAFT' && status === 'CONFIRMED' && !ledgerOwnedByChallan && movesStock) {
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
      // (movesStock isn't re-checked here: a document that never posted
      // has no entries to reverse, and historical confirmed estimates
      // that DID post under the old behavior should still reverse.)
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

      // Outbox (same tx): emit on the money-affecting transitions so derived
      // read models (roll-ups today) update reactively. occurredAt = the
      // invoice's date so the handler buckets into the right IST day. We only
      // emit on DRAFT→CONFIRMED and CONFIRMED→CANCELLED — a DRAFT cancel never
      // hit the books, so there is nothing to recompute.
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
    // Idempotency (INV-2): if this estimate was already converted, return
    // the existing invoice rather than minting a second one.
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

    // Claim the conversion atomically. If another concurrent convert won
    // the race (count===0), discard our just-created draft and return the
    // invoice they created instead — so one estimate yields exactly one
    // converted invoice.
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

  async deleteInvoice(shopId: number, id: number) {
    const invoice = await prisma.invoice.findFirst({
      where: { id, shopId },
      select: { status: true },
    });
    if (!invoice) return { error: 'Invoice not found' as const };
    // GST-1 / Rule 46(b): the legal invoice serial is allocated at create time
    // (the per-shop FY counter is bumped in `nextInvoiceNo`), so even a DRAFT
    // already owns a consecutive number. Hard-deleting it would leave a
    // permanent hole in the issued sequence — which Rule 46(b) (consecutive
    // serial numbers, not exceeding 16 chars) forbids. We therefore never
    // hard-delete: a DRAFT the merchant wants to discard must be CANCELLED
    // instead (the number is retained against the cancelled row, keeping the
    // run consecutive). Supersedes the earlier INV-3 "DRAFT may be deleted".
    return {
      error: invoice.status === 'DRAFT'
        ? ('Cannot delete a draft — its invoice number is already allocated. Cancel it instead so the serial stays consecutive.' as const)
        : invoice.status === 'CONFIRMED'
          ? ('Cannot delete a confirmed invoice. Cancel it first.' as const)
          : ('Cannot delete an issued invoice — cancelled invoice numbers must be retained.' as const),
    };
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
