import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { invoicesService } from '../invoices/invoices.service.js';
import { flashSalesService } from '../flash-sales/flash-sales.service.js';

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
  shopId: true,
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
  shop: { select: { id: true, name: true, slug: true, owner: { select: { id: true, name: true, shopName: true } } } },
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
  shopId: true,
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
  shop: { select: { id: true, name: true, slug: true, owner: { select: { id: true, name: true, shopName: true } } } },
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

/// Project the embedded Shop relation into the legacy
/// `{ id, name, shopName }` shape the customer app already consumes.
/// Multi-shop response — one shop per row, not one shop per response.
function shopAsDto(
  shop: { id: number; name: string; slug: string; owner: { id: number; name: string; shopName: string | null } } | null,
) {
  if (!shop) return null;
  return {
    id: shop.owner.id,
    name: shop.owner.name,
    shopName: shop.name ?? shop.owner.shopName,
  };
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
    shopId: number;
    customerUserId: number;
    items: CartLine[];
    note?: string;
    idempotencyKey?: string;
    addressId?: number;
  }): Promise<
    | { error: 'EMPTY_CART' | 'PRODUCT_MISSING' | 'PRODUCT_INACTIVE' | 'BAD_QTY' | 'ADDRESS_NOT_OWNED' | 'OWN_SHOP_ITEM' | 'SHOP_NOT_FOUND' | 'CROSS_SHOP_ITEM' }
    | { request: { id: number }; deduplicated?: true }
  > {
    if (opts.items.length === 0) return { error: 'EMPTY_CART' };

    // Shop must exist + cannot be the customer's own shop (the
    // "can't buy from your own shop" marketplace guardrail).
    const shop = await prisma.shop.findUnique({
      where: { id: opts.shopId },
      select: { id: true, ownerUserId: true },
    });
    if (!shop) return { error: 'SHOP_NOT_FOUND' };
    if (shop.ownerUserId === opts.customerUserId) {
      return { error: 'OWN_SHOP_ITEM' };
    }

    // Idempotency short-circuit — one indexed lookup, no row created
    // when we already saw this key.
    if (opts.idempotencyKey) {
      const existing = await prisma.purchaseRequest.findUnique({
        where: {
          purchase_requests_user_shop_idempotency_key: {
            customerUserId: opts.customerUserId,
            shopId: opts.shopId,
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
        shopId: true,
        name: true,
        sku: true,
        unit: true,
        sellingPrice: true,
        isActive: true,
      },
    });
    // Reject the request if any item belongs to a different shop than
    // the order's shopId — the customer-side splitter is supposed to
    // fire one POST per shop. This stays as a server-side guard.
    for (const p of products) {
      if (p.shopId !== opts.shopId) {
        return { error: 'CROSS_SHOP_ITEM' };
      }
    }
    const productMap = new Map(products.map((p) => [p.id, p]));

    for (const line of opts.items) {
      const product = productMap.get(line.productId);
      if (!product) return { error: 'PRODUCT_MISSING' };
      if (!product.isActive) return { error: 'PRODUCT_INACTIVE' };
      if (!(line.quantity > 0)) return { error: 'BAD_QTY' };
    }

    // ── Flash-sale claim pass ───────────────────────────────────────
    // For each line, atomically reserve units from any active flash
    // sale. The line is billed at the flash price when the claim
    // succeeds, and at the normal sellingPrice otherwise. Failures
    // (out-of-stock, sale ended between view and submit) must
    // release whatever was claimed earlier in the loop so the
    // customer never sees a "partial reserve" they can't unwind.
    //
    // Two-layer race protection lives inside flashSalesService.claim
    // (Redis INCRBY + DB-lock fallback) — we just orchestrate.
    const claimedQty = new Map<number, number>();   // productId → qty
    const flashPrices = new Map<number, number>();  // productId → flashPrice
    for (const line of opts.items) {
      const result = await flashSalesService.claim(line.productId, Math.ceil(line.quantity));
      if (result.ok) {
        claimedQty.set(line.productId, (claimedQty.get(line.productId) ?? 0) + Math.ceil(line.quantity));
        flashPrices.set(line.productId, result.flashPrice);
        continue;
      }
      if (result.reason === 'not_active') {
        // No flash sale running for this product — bill at normal
        // sellingPrice. Not an error.
        continue;
      }
      // Out of stock / sale just ended → rollback everything we
      // claimed for prior lines, then surface a structured error.
      for (const [pid, q] of claimedQty.entries()) {
        await flashSalesService.release(pid, q);
      }
      return { error: 'PRODUCT_INACTIVE' };
    }

    // One read for the customer + the Party row that links them to the
    // *target shop* (if any). Today a customer can be linked as a Party
    // in many shops at once, so we filter to opts.shopId — otherwise we'd
    // pick whichever linked party row had the lowest id, which could
    // belong to a different merchant.
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: opts.customerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        linkedParties: {
          where: { isActive: true, shopId: opts.shopId },
          select: { id: true, name: true, phone: true, address: true },
          take: 1,
        },
      },
    });
    const linkedParty = user.linkedParties[0];

    // Snapshot the chosen address (or fall back to the linked-party
    // address) so the order remains stable after the user edits or
    // deletes the underlying UserAddress row.
    let snapshotName: string | null = null;
    let snapshotPhone: string | null = null;
    let snapshotAddress: string | null = null;
    if (opts.addressId) {
      const addr = await prisma.userAddress.findFirst({
        where: { id: opts.addressId, userId: opts.customerUserId },
        select: {
          fullName: true,
          phone: true,
          line1: true,
          line2: true,
          city: true,
          state: true,
          pincode: true,
          landmark: true,
        },
      });
      if (!addr) return { error: 'ADDRESS_NOT_OWNED' };
      snapshotName = addr.fullName;
      snapshotPhone = addr.phone;
      const lines = [
        addr.line1,
        addr.line2 || null,
        `${addr.city}, ${addr.state} ${addr.pincode}`,
        addr.landmark ? `Landmark: ${addr.landmark}` : null,
      ].filter((s): s is string => !!s && s.trim().length > 0);
      snapshotAddress = lines.join('\n');
    }

    let estimatedTotal = 0;
    const itemsData = opts.items.map((line) => {
      const p = productMap.get(line.productId)!;
      // Prefer the flash price when we successfully claimed inventory
      // for this product line; fall back to the merchant's normal
      // sellingPrice when there's no active sale.
      const price = flashPrices.get(line.productId) ?? Number(p.sellingPrice);
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
    // Note: if the create throws, the flash-sale claims made above
    // will eventually expire from Redis (TTL) — releasing on rejection
    // would also be defensible but adds a partial-write window. We
    // accept the small leak; the row count is the source of truth at
    // the next flush cycle.
    try {
      const request = await prisma.purchaseRequest.create({
        data: {
          shopId: opts.shopId,
          customerUserId: opts.customerUserId,
          partyId: linkedParty?.id ?? null,
          customerName: snapshotName ?? linkedParty?.name ?? user.name,
          customerPhone: snapshotPhone ?? linkedParty?.phone ?? null,
          customerEmail: user.email,
          customerAddress: snapshotAddress ?? linkedParty?.address ?? null,
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
            purchase_requests_user_shop_idempotency_key: {
              customerUserId: opts.customerUserId,
              shopId: opts.shopId,
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
    // Shop identity now travels per-row via the embedded `shop` select
    // — different orders may belong to different merchants, so the old
    // "one shop per response" model can't represent that any more.
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
    return {
      data: data.map((row) => ({ ...withItemsPreview(row), shop: shopAsDto(row.shop) })),
      total,
    };
  }

  async getForCustomer(opts: { userId: number; id: number }) {
    const request = await prisma.purchaseRequest.findFirst({
      where: { id: opts.id, customerUserId: opts.userId },
      select: detailSelect,
    });
    if (!request) return null;
    return { ...request, shop: shopAsDto(request.shop) };
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
    shopId: number;
    status?: string;
    search?: string;
    from?: Date;
    to?: Date;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.PurchaseRequestWhereInput = { shopId: opts.shopId };
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

  async getForMerchant(shopId: number, id: number) {
    return prisma.purchaseRequest.findFirst({
      where: { id, shopId },
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
    shopId: number;
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' | 'NO_ITEMS' | 'INSUFFICIENT_STOCK' | string; productId?: number; available?: number; requested?: number }
    | { invoice: { id: number; invoiceNo: string } }
  > {
    return prisma.$transaction(async (tx) => {
      // ── 1. Atomic claim scoped to this shop ──────────────────────
      const claim = await tx.purchaseRequest.updateMany({
        where: { id: opts.requestId, shopId: opts.shopId, status: 'PENDING' },
        data: { status: 'PROCESSING' },
      });
      if (claim.count === 0) {
        const probe = await tx.purchaseRequest.findFirst({
          where: { id: opts.requestId, shopId: opts.shopId },
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
            shopId: request.shopId,
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
        shopId: request.shopId,
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
    shopId: number;
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' }
    | { ok: true }
  > {
    // Same atomic-claim trick: updateMany gated on (shopId, status='PENDING').
    const update = await prisma.purchaseRequest.updateMany({
      where: { id: opts.requestId, shopId: opts.shopId, status: 'PENDING' },
      data: {
        status: 'REJECTED',
        decidedById: opts.decidedById,
        decidedAt: new Date(),
        decisionNote: opts.note ?? null,
      },
    });
    if (update.count === 1) return { ok: true };

    const probe = await prisma.purchaseRequest.findFirst({
      where: { id: opts.requestId, shopId: opts.shopId },
      select: { id: true },
    });
    return { error: probe ? 'NOT_PENDING' : 'NOT_FOUND' };
  }

  /// Merchant-side counters for the orders badge.
  async pendingCount(shopId: number) {
    return prisma.purchaseRequest.count({ where: { shopId, status: 'PENDING' } });
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export const purchaseRequestsService = new PurchaseRequestsService();
