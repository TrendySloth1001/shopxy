import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { invoicesService } from '../invoices/invoices.service.js';

const itemSelect = {
  id: true,
  productId: true,
  productName: true,
  productSku: true,
  unit: true,
  quantity: true,
  unitPrice: true,
  total: true,
} satisfies Prisma.PurchaseRequestItemSelect;

/// Compact preview for list rows: just enough for the merchant to
/// recognise the order at a glance ("3 × Solder Wire Roll, …") without
/// loading the whole items array. Take 2 — anything past that becomes
/// "+N more" on the client side.
const previewItemSelect = {
  productName: true,
  quantity: true,
  unit: true,
} satisfies Prisma.PurchaseRequestItemSelect;

const listSelect = {
  id: true,
  status: true,
  customerName: true,
  customerPhone: true,
  customerEmail: true,
  estimatedTotal: true,
  note: true,
  invoiceId: true,
  createdAt: true,
  decidedAt: true,
  party: { select: { id: true, name: true, linkedUserId: true } },
  _count: { select: { items: true } },
  /// Two-line preview so the inbox row can show product names without
  /// a follow-up fetch. Ordered by id for stable rendering.
  items: {
    select: previewItemSelect,
    orderBy: { id: 'asc' as const },
    take: 2,
  },
} satisfies Prisma.PurchaseRequestSelect;

function withItemsPreview<T extends { items: unknown }>(row: T) {
  const { items, ...rest } = row;
  return { ...rest, itemsPreview: items };
}

const detailSelect = {
  id: true,
  status: true,
  customerName: true,
  customerPhone: true,
  customerEmail: true,
  estimatedTotal: true,
  note: true,
  invoiceId: true,
  createdAt: true,
  decidedAt: true,
  party: { select: { id: true, name: true, linkedUserId: true } },
  _count: { select: { items: true } },
  customerAddress: true,
  customerUserId: true,
  decisionNote: true,
  decidedBy: { select: { id: true, name: true } },
  invoice: {
    select: {
      id: true,
      invoiceNo: true,
      type: true,
      status: true,
      total: true,
      invoiceDate: true,
    },
  },
  items: {
    select: {
      ...itemSelect,
      /// Live stock of the linked product. Per-row join via Prisma's
      /// nested select — one query for the whole detail page. Lets the
      /// merchant see "we have 4 in stock, customer wants 5" before
      /// they tap Confirm.
      ///
      /// Pulling the primary image too so the order detail can render a
      /// thumbnail per line without a follow-up fetch.
      product: {
        select: {
          stockQuantity: true,
          isActive: true,
          images: {
            select: { url: true },
            orderBy: { sortOrder: 'asc' as const },
            take: 1,
          },
        },
      },
    },
    orderBy: { id: 'asc' as const },
  },
} satisfies Prisma.PurchaseRequestSelect;

interface CartLine {
  productId: number;
  quantity: number;
}

/// Looks up the singleton shop owner. Cached per call site so the
/// /orders list response doesn't fan out one User read per row.
async function loadShopIdentity() {
  return prisma.user.findFirst({
    where: { role: 'OWNER', isActive: true },
    select: { id: true, name: true, shopName: true },
    orderBy: { id: 'asc' },
  });
}

export class PurchaseRequestsService {
  /// Customer submits a new order. Snapshots product identity + current
  /// price per line so the customer's order remains stable even if the
  /// merchant edits the product later.
  ///
  /// If [idempotencyKey] is supplied and a row already exists for the
  /// same (customerUserId, idempotencyKey), we return the original
  /// request id without creating a duplicate. Saves a duplicate-order
  /// nightmare when checkout retries on a flaky connection.
  async createForCustomer(opts: {
    customerUserId: number;
    items: CartLine[];
    note?: string;
    idempotencyKey?: string;
  }): Promise<
    | { error: 'EMPTY_CART' | 'PRODUCT_MISSING' | 'PRODUCT_INACTIVE' | 'BAD_QTY' }
    | { request: { id: number }; deduplicated?: true }
  > {
    if (opts.items.length === 0) return { error: 'EMPTY_CART' };

    // Idempotency short-circuit — one indexed lookup, no row created
    // when we already saw this key.
    if (opts.idempotencyKey) {
      const existing = await prisma.purchaseRequest.findUnique({
        where: {
          purchase_requests_user_idempotency_key: {
            customerUserId: opts.customerUserId,
            idempotencyKey: opts.idempotencyKey,
          },
        },
        select: { id: true },
      });
      if (existing) return { request: existing, deduplicated: true };
    }

    const productIds = [...new Set(opts.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: {
        id: true,
        name: true,
        sku: true,
        unit: true,
        sellingPrice: true,
        isActive: true,
      },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));

    for (const line of opts.items) {
      const product = productMap.get(line.productId);
      if (!product) return { error: 'PRODUCT_MISSING' };
      if (!product.isActive) return { error: 'PRODUCT_INACTIVE' };
      if (!(line.quantity > 0)) return { error: 'BAD_QTY' };
    }

    // One read for the customer + their first linked party. The Party
    // join is constrained to the smallest possible projection.
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: opts.customerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        linkedParties: {
          where: { isActive: true },
          select: { id: true, name: true, phone: true, address: true },
          take: 1,
        },
      },
    });
    const linkedParty = user.linkedParties[0];

    let estimatedTotal = 0;
    const itemsData = opts.items.map((line) => {
      const p = productMap.get(line.productId)!;
      const price = Number(p.sellingPrice);
      const lineTotal = round2(line.quantity * price);
      estimatedTotal += lineTotal;
      return {
        productId: p.id,
        productName: p.name,
        productSku: p.sku,
        unit: p.unit,
        quantity: line.quantity,
        unitPrice: price,
        total: lineTotal,
      };
    });

    // Two clients hitting submit at the same instant (both before either
    // INSERT lands) could race past the lookup above and both create a
    // row — catch the unique-violation on the way out and re-fetch.
    try {
      const request = await prisma.purchaseRequest.create({
        data: {
          customerUserId: opts.customerUserId,
          partyId: linkedParty?.id ?? null,
          customerName: linkedParty?.name ?? user.name,
          customerPhone: linkedParty?.phone ?? null,
          customerEmail: user.email,
          customerAddress: linkedParty?.address ?? null,
          note: opts.note ?? null,
          estimatedTotal: round2(estimatedTotal),
          idempotencyKey: opts.idempotencyKey ?? null,
          items: { create: itemsData },
        },
        select: { id: true },
      });
      return { request };
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code === 'P2002' && opts.idempotencyKey) {
        const existing = await prisma.purchaseRequest.findUnique({
          where: {
            purchase_requests_user_idempotency_key: {
              customerUserId: opts.customerUserId,
              idempotencyKey: opts.idempotencyKey,
            },
          },
          select: { id: true },
        });
        if (existing) return { request: existing, deduplicated: true };
      }
      throw e;
    }
  }

  async listForCustomer(opts: { userId: number; skip: number; limit: number }) {
    const where: Prisma.PurchaseRequestWhereInput = { customerUserId: opts.userId };
    // Pagination + count + the shop identity all fly in parallel — the
    // owner read is needed once per response, not per row.
    const [data, total, shop] = await Promise.all([
      prisma.purchaseRequest.findMany({
        where,
        select: listSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.purchaseRequest.count({ where }),
      loadShopIdentity(),
    ]);
    return { data: data.map((row) => ({ ...withItemsPreview(row), shop })), total };
  }

  async getForCustomer(opts: { userId: number; id: number }) {
    const [request, shop] = await Promise.all([
      prisma.purchaseRequest.findFirst({
        where: { id: opts.id, customerUserId: opts.userId },
        select: detailSelect,
      }),
      loadShopIdentity(),
    ]);
    if (!request) return null;
    return { ...request, shop };
  }

  /// Cancel with explicit reason codes so the API consumer can render
  /// targeted error copy. One round trip via a status-gated updateMany
  /// (PostgreSQL returns affected row count without an extra SELECT),
  /// plus an existence-check follow-up only on the unhappy path.
  async cancelForCustomer(opts: { userId: number; id: number }): Promise<
    | { ok: true }
    | { error: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_PENDING' }
  > {
    const update = await prisma.purchaseRequest.updateMany({
      where: {
        id: opts.id,
        customerUserId: opts.userId,
        status: 'PENDING',
      },
      data: { status: 'CANCELLED', decidedAt: new Date() },
    });
    if (update.count === 1) return { ok: true };

    // We didn't cancel — figure out why so the client can show
    // something more useful than "could not cancel". One indexed lookup.
    const existing = await prisma.purchaseRequest.findUnique({
      where: { id: opts.id },
      select: { customerUserId: true, status: true },
    });
    if (!existing) return { error: 'NOT_FOUND' };
    if (existing.customerUserId !== opts.userId) return { error: 'NOT_OWNED' };
    return { error: 'NOT_PENDING' };
  }

  /// Merchant-side: list the inbox with the same listSelect projection.
  /// Supports status / search (id, customer name/phone, product name) /
  /// from-to date filters. Search is intentionally a single `OR` so
  /// Postgres can pick the right index instead of stitching joins.
  async listForMerchant(opts: {
    status?: string;
    search?: string;
    from?: Date;
    to?: Date;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.PurchaseRequestWhereInput = {};
    if (opts.status) where.status = opts.status;

    if (opts.from || opts.to) {
      where.createdAt = {
        ...(opts.from ? { gte: opts.from } : {}),
        ...(opts.to ? { lte: opts.to } : {}),
      };
    }

    if (opts.search) {
      const q = opts.search.trim();
      if (q) {
        const numericId = /^\d+$/.test(q) ? Number(q) : undefined;
        where.OR = [
          { customerName: { contains: q, mode: 'insensitive' } },
          { customerPhone: { contains: q, mode: 'insensitive' } },
          { items: { some: { productName: { contains: q, mode: 'insensitive' } } } },
          ...(numericId ? [{ id: numericId }] : []),
        ];
      }
    }

    const [data, total] = await Promise.all([
      prisma.purchaseRequest.findMany({
        where,
        select: listSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.purchaseRequest.count({ where }),
    ]);
    return { data: data.map(withItemsPreview), total };
  }

  async getForMerchant(id: number) {
    return prisma.purchaseRequest.findUnique({
      where: { id },
      select: detailSelect,
    });
  }

  /// Confirm a request → materialise a SALE invoice.
  ///
  /// Concurrency model:
  ///   1. updateMany gated on status='PENDING' is our atomic claim.
  ///      Exactly one caller flips the row out of PENDING; later
  ///      attempts see count=0 and bail with NOT_PENDING.
  ///   2. The whole flow runs inside $transaction so a stock shortfall
  ///      / invoice failure rolls back the status flip too — no orphan
  ///      "CONFIRMED but no invoice" rows.
  ///   3. Stock is pre-checked in the same transaction using a single
  ///      findMany; we don't decrement here (the invoice ledger does
  ///      that on its own confirm), we just guarantee the merchant
  ///      isn't given a confirm that's bound to fail.
  async confirmRequest(opts: {
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' | 'NO_ITEMS' | 'INSUFFICIENT_STOCK' | string; productId?: number; available?: number; requested?: number }
    | { invoice: { id: number; invoiceNo: string } }
  > {
    return prisma.$transaction(async (tx) => {
      // ── 1. Atomic claim ──────────────────────────────────────────
      const claim = await tx.purchaseRequest.updateMany({
        where: { id: opts.requestId, status: 'PENDING' },
        data: { status: 'PROCESSING' },
      });
      if (claim.count === 0) {
        // Either it doesn't exist, isn't pending, or another merchant
        // beat us to it. One indexed read to disambiguate.
        const probe = await tx.purchaseRequest.findUnique({
          where: { id: opts.requestId },
          select: { id: true },
        });
        return { error: probe ? 'NOT_PENDING' : 'NOT_FOUND' as const };
      }

      // ── 2. Load full row (now safely ours to act on) ─────────────
      const request = await tx.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.requestId },
        include: { items: true },
      });
      if (request.items.length === 0) {
        // Revert the claim so the row goes back to PENDING for
        // whatever workflow the merchant adopts.
        await tx.purchaseRequest.updateMany({
          where: { id: opts.requestId, status: 'PROCESSING' },
          data: { status: 'PENDING' },
        });
        return { error: 'NO_ITEMS' as const };
      }

      // ── 3. Stock pre-check (single findMany, bounded by item count) ─
      const productIds = [...new Set(request.items.map((i) => i.productId))];
      const products = await tx.product.findMany({
        where: { id: { in: productIds } },
        select: { id: true, stockQuantity: true },
      });
      const stockMap = new Map(products.map((p) => [p.id, Number(p.stockQuantity)]));
      for (const it of request.items) {
        const available = stockMap.get(it.productId) ?? 0;
        const requested = Number(it.quantity);
        if (available < requested) {
          await tx.purchaseRequest.updateMany({
            where: { id: opts.requestId, status: 'PROCESSING' },
            data: { status: 'PENDING' },
          });
          return {
            error: 'INSUFFICIENT_STOCK' as const,
            productId: it.productId,
            available,
            requested,
          };
        }
      }

      // ── 4. Lazy-create Party if the customer wasn't linked yet ───
      let partyId = request.partyId;
      if (!partyId) {
        const created = await tx.party.create({
          data: {
            name: request.customerName,
            phone: request.customerPhone,
            email: request.customerEmail,
            address: request.customerAddress,
            linkedUserId: request.customerUserId,
          },
          select: { id: true },
        });
        partyId = created.id;
      }

      // ── 5. Mint the invoice ───────────────────────────────────────
      // invoicesService.createInvoice opens its own $transaction; nested
      // transactions in Prisma collapse into the outer one so the whole
      // operation remains atomic.
      const result = await invoicesService.createInvoice({
        type: 'SALE',
        partyId,
        customerName: request.customerName,
        customerPhone: request.customerPhone ?? undefined,
        note: opts.note ?? request.note ?? undefined,
        items: request.items.map((i) => ({
          productId: i.productId,
          quantity: Number(i.quantity),
          unitPrice: Number(i.unitPrice),
        })),
      });

      if ('error' in result) {
        // Roll the row back to PENDING so the merchant can retry — the
        // outer transaction would also rollback the status flip, but
        // being explicit here matches what callers expect.
        return { error: result.error ?? 'INVOICE_FAILED' as const };
      }

      // ── 6. Mark CONFIRMED + link the invoice ─────────────────────
      await tx.purchaseRequest.update({
        where: { id: request.id },
        data: {
          status: 'CONFIRMED',
          invoiceId: result.invoice.id,
          partyId,
          decidedById: opts.decidedById,
          decidedAt: new Date(),
          decisionNote: opts.note ?? null,
        },
      });

      return {
        invoice: { id: result.invoice.id, invoiceNo: result.invoice.invoiceNo },
      };
    });
  }

  async rejectRequest(opts: {
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' }
    | { ok: true }
  > {
    // Same atomic-claim trick: updateMany gated on status='PENDING'.
    const update = await prisma.purchaseRequest.updateMany({
      where: { id: opts.requestId, status: 'PENDING' },
      data: {
        status: 'REJECTED',
        decidedById: opts.decidedById,
        decidedAt: new Date(),
        decisionNote: opts.note ?? null,
      },
    });
    if (update.count === 1) return { ok: true };

    const probe = await prisma.purchaseRequest.findUnique({
      where: { id: opts.requestId },
      select: { id: true },
    });
    return { error: probe ? 'NOT_PENDING' : 'NOT_FOUND' };
  }

  /// Merchant-side counters for the orders badge.
  async pendingCount() {
    return prisma.purchaseRequest.count({ where: { status: 'PENDING' } });
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export const purchaseRequestsService = new PurchaseRequestsService();
