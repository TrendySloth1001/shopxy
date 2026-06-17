import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { round2 } from '../../shared/numbering/decimal.js';
import { resolveActiveProductPromos } from '../banners/promo-pricing.js';
import { invoicesService } from '../invoices/invoices.service.js';
import { paymentGatewayService } from '../payment-gateway/index.js';
import { ensureOrderInvoiceReceipts } from '../payment-gateway/order-receipts.js';
import {
  releaseTransfersForPurchaseRequest,
  reverseTransferForReturn,
} from '../payment-gateway/settlement/transfer-actions.js';
import { paymentsService } from '../payments/payments.service.js';

/// Sentinel for "reverse the whole transfer" — reverseTransferForReturn
/// caps the request at the transfer's remaining un-reversed amount, so an
/// oversized value simply means a full clawback.
const REVERSE_ALL = Number.MAX_SAFE_INTEGER / 100;

/// Local helper — invoices.service doesn't expose a payment summariser
/// (its own status flow is independent of paid-vs-total accounting), so
/// the purchase-request response derives the shape inline. Mirrors the
/// fields the customer/merchant apps already destructure off the invoice
/// blob: paidAmount, balanceDue, paymentStatus.
function derivePaymentSummary(
  total: number,
  paid: number,
  status: string,
): { paidAmount: number; balanceDue: number; paymentStatus: 'PAID' | 'PARTIAL' | 'UNPAID' } {
  const balanceDue = Math.max(0, total - paid);
  let paymentStatus: 'PAID' | 'PARTIAL' | 'UNPAID';
  if (status === 'CANCELLED' || status === 'DRAFT') {
    paymentStatus = 'UNPAID';
  } else if (total > 0 && paid >= total) {
    paymentStatus = 'PAID';
  } else if (paid > 0) {
    paymentStatus = 'PARTIAL';
  } else {
    paymentStatus = 'UNPAID';
  }
  return { paidAmount: paid, balanceDue, paymentStatus };
}
import { couponsService } from '../coupons/coupons.service.js';
import { walletService } from '../wallet/wallet.service.js';
import { notificationsService } from '../notifications/notifications.service.js';

/// Thrown inside the order-create transaction when coupon redemption
/// fails — caught above to surface a normal `{ error: 'COUPON_INVALID' }`
/// without dragging the transaction wrapper into the controller.
class CouponRedeemError extends Error {
  constructor(public readonly code: string) {
    super(code);
  }
}

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
  shop: {
    select: {
      id: true,
      name: true,
      slug: true,
      owner: { select: { id: true, name: true, shopName: true } },
      returnsEnabled: true,
      returnWindowDays: true,
      refundMode: true,
      returnPolicyNote: true,
      cancellationPolicy: true,
    },
  },
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
      /// Pull payment amounts so the per-vendor card on the customer's
      /// order detail can show "Paid" / "Partially paid (₹A of ₹B)"
      /// without a follow-up fetch. Bounded by the per-invoice
      /// payments count (small).
      payments: { select: { amount: true } },
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
  // Inline the event timeline so the customer detail page can render
  // the tracking strip without a second roundtrip. Bounded by the
  // per-order event count (single-digit in practice).
  events: {
    select: {
      id: true,
      type: true,
      occurredAt: true,
      courier: true,
      awb: true,
      eta: true,
      note: true,
    },
    orderBy: { occurredAt: 'asc' as const },
  },
} satisfies Prisma.PurchaseRequestSelect;

interface CartLine {
  productId: number;
  quantity: number;
  /// Per-line price the client believes is correct. When set, the
  /// server rejects (PRICE_DRIFT) if the live price disagrees.
  expectedUnitPrice?: number;
}

/// Project the embedded Shop relation into the legacy
/// `{ id, name, shopName }` shape the customer app already consumes.
/// Multi-shop response — one shop per row, not one shop per response.
function shopAsDto(
  shop:
    | {
        id: number;
        name: string;
        slug: string;
        owner: { id: number; name: string; shopName: string | null };
        returnsEnabled?: boolean;
        returnWindowDays?: number;
        refundMode?: string;
        returnPolicyNote?: string | null;
      }
    | null,
) {
  if (!shop) return null;
  return {
    id: shop.owner.id,
    name: shop.owner.name,
    shopName: shop.name ?? shop.owner.shopName,
    // Return policy is buyer-facing on the order detail page so the
    // customer can see "Returnable for 7 days · wallet refund" before
    // they tap the return button (which is hidden when disabled).
    returnsEnabled: shop.returnsEnabled,
    returnWindowDays: shop.returnWindowDays,
    refundMode: shop.refundMode,
    returnPolicyNote: shop.returnPolicyNote ?? null,
  };
}

/// Sum the embedded payments and attach derived paid/outstanding/status
/// so the customer's order detail can show a paid badge per vendor
/// card without an extra round trip. The raw `payments` array is
/// stripped from the response — the customer doesn't need (or want to
/// see) the merchant's per-payment ledger.
function attachInvoicePaymentSummary<
  T extends { total: Prisma.Decimal | number; status: string; payments: { amount: Prisma.Decimal | number }[] },
>(invoice: T) {
  const totalNum =
    typeof invoice.total === 'number' ? invoice.total : Number(invoice.total.toString());
  const paid = invoice.payments.reduce((sum, p) => {
    const v = typeof p.amount === 'number' ? p.amount : Number(p.amount.toString());
    return sum + v;
  }, 0);
  const summary = derivePaymentSummary(totalNum, paid, invoice.status);
  const { payments: _drop, ...rest } = invoice;
  return { ...rest, ...summary };
}

/// Reloads the shop row and verifies that the caller actually owns
/// it. Every merchant-facing endpoint passes `shopId` straight from
/// the JWT, but a stale or tampered token could carry someone else's
/// shopId — so we never act on it without a fresh DB-backed check.
/// Returns true on success; false (the controller maps to 403) when
/// the shop is gone or owned by a different user.
export async function assertShopOwnership(
  shopId: number,
  userId: number,
): Promise<boolean> {
  const shop = await prisma.shop.findUnique({
    where: { id: shopId },
    select: { ownerUserId: true },
  });
  return shop != null && shop.ownerUserId === userId;
}

/// Push a notification to the owner of `shopId`. Lives here (not in the
/// controller) so controllers stay free of direct Prisma access — the
/// service is the single layer that talks to the DB.
export async function notifyShopOwner(
  shopId: number,
  payload: {
    kind: string;
    title: string;
    body?: string;
    data?: Record<string, unknown>;
  },
): Promise<void> {
  const shop = await prisma.shop.findUnique({
    where: { id: shopId },
    select: { ownerUserId: true },
  });
  if (!shop) return;
  await notificationsService.create({
    userId: shop.ownerUserId,
    kind: payload.kind,
    title: payload.title,
    body: payload.body,
    data: payload.data,
  });
}

export class PurchaseRequestsService {
  /// Customer submits a *whole cart* — possibly spanning multiple
  /// shops. Server groups by shop and creates one [CustomerOrder]
  /// parent plus one [PurchaseRequest] child per shop, all in a single
  /// transaction. Snapshots product identity + price per line so the
  /// customer's order remains stable even if the merchant later edits
  /// the product.
  ///
  /// If [idempotencyKey] is supplied and a parent already exists for
  /// the same (customerUserId, idempotencyKey), we return the original
  /// parent without creating duplicates — saves a duplicate-order
  /// nightmare when checkout retries on a flaky connection.
  async createForCustomer(opts: {
    customerUserId: number;
    items: CartLine[];
    note?: string;
    idempotencyKey?: string;
    addressId?: number;
    /// Optional coupon code (case-insensitive). Validated + redeemed
    /// atomically with the order create — invalid codes return the
    /// matching CouponError instead of half-applying.
    couponCode?: string | null;
    /// When true, attempts to debit the user's wallet for as much of
    /// the order total as it covers (after any coupon discount).
    useWallet?: boolean;
  }): Promise<
    | {
        error:
          | 'EMPTY_CART'
          | 'PRODUCT_MISSING'
          | 'PRODUCT_INACTIVE'
          | 'BAD_QTY'
          | 'ADDRESS_NOT_OWNED'
          | 'OWN_SHOP_ITEM'
          | 'SHOP_NOT_FOUND'
          | 'CROSS_SHOP_ITEM'
          | 'COUPON_INVALID'
          | 'PRICE_DRIFT';
        priceDrift?: {
          productId: number;
          expectedUnitPrice: number;
          actualUnitPrice: number;
        }[];
      }
    | { order: { id: number; shopOrders: { id: number; shopId: number }[]; couponDiscount: number; walletPaid: number }; deduplicated?: true }
  > {
    if (opts.items.length === 0) return { error: 'EMPTY_CART' };

    // Idempotency short-circuit on the parent — returns the existing
    // order so a retried POST never double-creates.
    if (opts.idempotencyKey) {
      const replay = await this._replayIdempotentOrder(
        opts.customerUserId,
        opts.idempotencyKey,
      );
      if (replay) return replay;
    }

    // ── Load products + validate shop ownership / activity ──────────
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
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const line of opts.items) {
      const product = productMap.get(line.productId);
      if (!product) return { error: 'PRODUCT_MISSING' };
      if (!product.isActive) return { error: 'PRODUCT_INACTIVE' };
      if (!(line.quantity > 0)) return { error: 'BAD_QTY' };
    }

    // Group lines by owning shop. The cart may legitimately span 3+
    // shops; the server is the one place that knows the full split.
    const linesByShop = new Map<number, CartLine[]>();
    for (const line of opts.items) {
      const product = productMap.get(line.productId)!;
      const bucket = linesByShop.get(product.shopId);
      if (bucket) {
        bucket.push(line);
      } else {
        linesByShop.set(product.shopId, [line]);
      }
    }

    // Every shop bucket must point at a real Shop, and none can be
    // the customer's own. One findMany batches the validation.
    const shopIds = [...linesByShop.keys()];
    const shops = await prisma.shop.findMany({
      where: { id: { in: shopIds } },
      select: { id: true, ownerUserId: true },
    });
    if (shops.length !== shopIds.length) return { error: 'SHOP_NOT_FOUND' };
    for (const shop of shops) {
      if (shop.ownerUserId === opts.customerUserId) {
        return { error: 'OWN_SHOP_ITEM' };
      }
    }

    // ── Effective unit price ─────────────────────────────────────────
    // Carts span many shops, so resolve the best active banner promo per
    // product in one cross-shop lookup; lines bill at sellingPrice minus
    // that promo's per-unit discount (or sellingPrice when none applies).
    const bannerPromos = await resolveActiveProductPromos(null, productIds);
    const effectiveUnitPrice = (productId: number): number => {
      const product = productMap.get(productId)!;
      const selling = Number(product.sellingPrice);
      const promo = bannerPromos.get(productId);
      return promo ? Math.max(0, round2(selling - promo.perUnit)) : selling;
    };

    // ── Price-drift guard ────────────────────────────────────────────
    // Every line whose client sent `expectedUnitPrice` is compared
    // against the current sellingPrice. On any mismatch we surface the
    // corrected prices so the FE can show "₹X has changed to ₹Y" in one
    // toast.
    const priceDrift: {
      productId: number;
      expectedUnitPrice: number;
      actualUnitPrice: number;
    }[] = [];
    for (const line of opts.items) {
      if (line.expectedUnitPrice == null) continue;
      const effective = effectiveUnitPrice(line.productId);
      // 1 paisa tolerance: legit decimal jitter shouldn't trip the gate.
      if (Math.abs(effective - line.expectedUnitPrice) > 0.01) {
        priceDrift.push({
          productId: line.productId,
          expectedUnitPrice: line.expectedUnitPrice,
          actualUnitPrice: round2(effective),
        });
      }
    }
    if (priceDrift.length > 0) {
      return { error: 'PRICE_DRIFT', priceDrift };
    }

    // ── Customer identity + per-shop linked-party lookup ─────────────
    // One read fetches the user + every Party row that links them to
    // any of the shops in this cart. We then build a shopId → linked
    // party map so the per-shop child PRs each point at the right
    // Party row (different shops can link to the same user under
    // different B2B identities).
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: opts.customerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        linkedParties: {
          where: { isActive: true, shopId: { in: shopIds } },
          select: { id: true, shopId: true, name: true, phone: true, address: true },
        },
      },
    });
    const linkedByShop = new Map(user.linkedParties.map((p) => [p.shopId, p]));

    // ── Address snapshot (one for the parent, mirrored to children) ─
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

    // ── Build per-shop child payloads + parent total ────────────────
    let parentTotal = 0;
    const childPayloads: {
      shopId: number;
      estimatedTotal: number;
      partyId: number | null;
      customerName: string;
      customerPhone: string | null;
      customerAddress: string | null;
      items: {
        productId: number;
        productName: string;
        productSku: string;
        unit: string;
        quantity: number;
        unitPrice: number;
        total: number;
      }[];
    }[] = [];

    for (const [shopId, lines] of linesByShop) {
      const linkedParty = linkedByShop.get(shopId);
      let childTotal = 0;
      const items = lines.map((line) => {
        const p = productMap.get(line.productId)!;
        const price = effectiveUnitPrice(line.productId);
        const lineTotal = round2(line.quantity * price);
        childTotal += lineTotal;
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
      childPayloads.push({
        shopId,
        estimatedTotal: round2(childTotal),
        partyId: linkedParty?.id ?? null,
        customerName: snapshotName ?? linkedParty?.name ?? user.name,
        customerPhone: snapshotPhone ?? linkedParty?.phone ?? null,
        customerAddress: snapshotAddress ?? linkedParty?.address ?? null,
        items,
      });
      parentTotal += childTotal;
    }

    // ── Persist parent + children in one transaction ────────────────
    try {
      const order = await prisma.$transaction(async (tx) => {
        const parent = await tx.customerOrder.create({
          data: {
            customerUserId: opts.customerUserId,
            customerName: snapshotName ?? user.name,
            customerPhone: snapshotPhone,
            customerEmail: user.email,
            customerAddress: snapshotAddress,
            note: opts.note ?? null,
            estimatedTotal: round2(parentTotal),
            idempotencyKey: opts.idempotencyKey ?? null,
          },
          select: { id: true },
        });

        // ── Coupon redemption ─────────────────────────────────────────
        // Validated + recorded inside the same transaction so a failure
        // (cap reached, per-user limit hit) aborts the order create
        // entirely. The discount lands on parent.couponDiscount and is
        // surfaced back to the controller in the response payload.
        let couponDiscount = 0;
        if (opts.couponCode && opts.couponCode.trim().length > 0) {
          const result = await couponsService.redeem({
            tx,
            userId: opts.customerUserId,
            code: opts.couponCode,
            context: { subtotal: parentTotal, shopIds },
            customerOrderId: parent.id,
          });
          if ('error' in result) {
            throw new CouponRedeemError(result.error);
          }
          couponDiscount = result.discount;
        }

        // ── Wallet debit ──────────────────────────────────────────────
        // Pays from the user's wallet for up to (subtotal - coupon).
        // Atomically clamped to the live balance via an updateMany gated
        // on `wallet_balance >= debit` — that avoids the lost-update race
        // where two parallel checkouts both read the same balance and
        // both debit it. We claim the smaller of payable / current
        // balance, then post the matching ledger row.
        let walletPaid = 0;
        if (opts.useWallet) {
          const payable = Math.max(0, round2(parentTotal - couponDiscount));
          if (payable > 0) {
            const balanceRow = await tx.user.findUniqueOrThrow({
              where: { id: opts.customerUserId },
              select: { walletBalance: true },
            });
            const desired = Math.min(Number(balanceRow.walletBalance), payable);
            if (desired > 0) {
              // Gated decrement — only succeeds when the column is still
              // ≥ desired. If a sibling checkout drained the balance
              // between our read and write, claim.count is 0 and we
              // simply skip the wallet payment instead of overdrawing.
              const claim = await tx.user.updateMany({
                where: {
                  id: opts.customerUserId,
                  walletBalance: { gte: desired },
                },
                data: { walletBalance: { decrement: desired } },
              });
              if (claim.count === 1) {
                // Post the ledger row with the post-decrement balance
                // we just observed. Wallet service `credit` would
                // double-decrement (it also bumps the column); pass
                // the balanceAfter explicitly via a raw entry write.
                const refreshed = await tx.user.findUniqueOrThrow({
                  where: { id: opts.customerUserId },
                  select: { walletBalance: true },
                });
                await tx.walletEntry.create({
                  data: {
                    userId: opts.customerUserId,
                    amount: -desired,
                    balanceAfter: Number(refreshed.walletBalance),
                    source: 'CHECKOUT',
                    sourceId: parent.id,
                    description: `Order #${parent.id} (wallet)`,
                    idempotencyKey: opts.idempotencyKey
                      ? `wallet:checkout:${opts.idempotencyKey}`
                      : null,
                  },
                });
                walletPaid = desired;
              }
            }
          }
        }

        if (couponDiscount > 0 || walletPaid > 0) {
          await tx.customerOrder.update({
            where: { id: parent.id },
            data: {
              couponDiscount: round2(couponDiscount),
              walletPaid: round2(walletPaid),
            },
          });
        }

        // createMany doesn't return rows in Postgres for Prisma, so we
        // create children one-by-one with select — N small inserts in
        // exchange for the per-child id (used to fan out notifications
        // and surface per-shop slices in the response).
        const childRecords: { id: number; shopId: number }[] = [];
        for (const child of childPayloads) {
          const created = await tx.purchaseRequest.create({
            data: {
              customerOrderId: parent.id,
              shopId: child.shopId,
              customerUserId: opts.customerUserId,
              partyId: child.partyId,
              customerName: child.customerName,
              customerPhone: child.customerPhone,
              customerEmail: user.email,
              customerAddress: child.customerAddress,
              note: opts.note ?? null,
              estimatedTotal: child.estimatedTotal,
              items: { create: child.items },
              // Seed the timeline with a CREATED row so the customer
              // sees "Order placed" the moment they reach the detail
              // page (vs. waiting on the merchant to act first).
              events: {
                create: { type: 'CREATED', actorId: opts.customerUserId },
              },
            },
            select: { id: true, shopId: true },
          });
          childRecords.push(created);
        }

        return {
          id: parent.id,
          shopOrders: childRecords,
          couponDiscount: round2(couponDiscount),
          walletPaid: round2(walletPaid),
        };
      });
      return { order };
    } catch (e) {
      if (e instanceof CouponRedeemError) {
        return { error: 'COUPON_INVALID' };
      }
      // Race: two POSTs with the same key landed within microseconds
      // of each other. The first wins; the second hits P2002 on the
      // parent unique — re-fetch and return the original.
      const code = (e as { code?: string }).code;
      if (code === 'P2002' && opts.idempotencyKey) {
        const existing = await prisma.customerOrder.findUnique({
          where: {
            customer_orders_user_idempotency_key: {
              customerUserId: opts.customerUserId,
              idempotencyKey: opts.idempotencyKey,
            },
          },
          select: {
            id: true,
            couponDiscount: true,
            walletPaid: true,
            shopOrders: { select: { id: true, shopId: true } },
          },
        });
        if (existing) {
          return {
            order: {
              id: existing.id,
              shopOrders: existing.shopOrders,
              couponDiscount: Number(existing.couponDiscount),
              walletPaid: Number(existing.walletPaid),
            },
            deduplicated: true,
          };
        }
      }
      throw e;
    }
  }

  /// Customer's order list — one row per [CustomerOrder] parent with a
  /// compact per-shop breakdown ("3 shops · 5 items · ₹X"). Each child
  /// PR carries its own status pill so the row can render aggregate
  /// state without an extra fetch.
  async listForCustomer(opts: { userId: number; skip: number; limit: number }) {
    const where: Prisma.CustomerOrderWhereInput = { customerUserId: opts.userId };
    const [data, total] = await Promise.all([
      prisma.customerOrder.findMany({
        where,
        select: {
          id: true,
          customerName: true,
          customerPhone: true,
          customerAddress: true,
          estimatedTotal: true,
          couponDiscount: true,
          walletPaid: true,
          paymentStatus: true,
          createdAt: true,
          updatedAt: true,
          _count: { select: { shopOrders: true } },
          shopOrders: {
            select: {
              id: true,
              shopId: true,
              status: true,
              estimatedTotal: true,
              invoiceId: true,
              decidedAt: true,
              shop: { select: { id: true, name: true, slug: true, owner: { select: { id: true, name: true, shopName: true } } } },
              _count: { select: { items: true } },
              items: {
                select: previewItemSelect,
                orderBy: { id: 'asc' as const },
                take: 2,
              },
            },
            orderBy: { id: 'asc' as const },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.customerOrder.count({ where }),
    ]);
    return {
      data: data.map((row) => ({
        ...row,
        shopOrders: row.shopOrders.map((child) => ({
          ...withItemsPreview(child),
          shop: shopAsDto(child.shop),
        })),
      })),
      total,
    };
  }

  /// Customer's order detail — full parent with full child slices,
  /// each child's items materialised so the per-vendor section in the
  /// detail page can render without follow-up requests.
  async getForCustomer(opts: { userId: number; id: number }) {
    const order = await prisma.customerOrder.findFirst({
      where: { id: opts.id, customerUserId: opts.userId },
      select: {
        id: true,
        customerName: true,
        customerPhone: true,
        customerEmail: true,
        customerAddress: true,
        note: true,
        estimatedTotal: true,
        couponDiscount: true,
        walletPaid: true,
        paymentStatus: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { shopOrders: true } },
        shopOrders: {
          select: detailSelect,
          orderBy: { id: 'asc' as const },
        },
      },
    });
    if (!order) return null;
    return {
      ...order,
      shopOrders: order.shopOrders.map((child) => {
        // Server-computed action flags so every client renders the same
        // Cancel-vs-Return decision the backend will enforce: cancel
        // until the seller's policy cut-off, return only after a
        // DELIVERED event (within the shop's window). Clients must not
        // re-derive these.
        const eventTypes = child.events.map((e) => e.type);
        const delivered = [...child.events]
          .reverse()
          .find((e) => e.type === 'DELIVERED');
        const policy = child.shop?.cancellationPolicy ?? 'UNTIL_SHIPPED';
        const canCancel =
          child.status === 'PENDING' ||
          (child.status === 'CONFIRMED' &&
            this.isCancellableByPolicy(policy, eventTypes));
        const windowDays = child.shop?.returnWindowDays ?? 0;
        const withinWindow =
          delivered != null &&
          (windowDays <= 0 ||
            (Date.now() - delivered.occurredAt.getTime()) / 86_400_000 <=
              windowDays);
        const canReturn =
          child.status === 'CONFIRMED' &&
          delivered != null &&
          (child.shop?.returnsEnabled ?? false) &&
          withinWindow;
        return {
          ...child,
          shop: shopAsDto(child.shop),
          invoice: child.invoice
            ? attachInvoicePaymentSummary(child.invoice)
            : null,
          canCancel,
          canReturn,
          cancellationPolicy: policy,
          deliveredAt: delivered?.occurredAt ?? null,
        };
      }),
    };
  }

  /// Cancel one shop's slice of a customer's order. The whole parent
  /// is *not* cancelled — other shops in the same checkout proceed
  /// independently. Returns reason codes so the FE can render targeted
  /// copy.
  ///
  /// Eligibility is the SELLER's call (Shop.cancellationPolicy):
  ///   - a PENDING child is always cancellable (the merchant hasn't
  ///     acted yet — no invoice, no stock movement);
  ///   - a CONFIRMED child is cancellable until the policy's cut-off
  ///     milestone (PACKED / SHIPPED / DELIVERED event), after which the
  ///     customer's only path is the post-delivery returns flow.
  /// A confirmed cancel reverses the whole paper trail: the invoice is
  /// cancelled (which reverses its stock ledger rows), its receipts are
  /// voided, and the paid amount (wallet + captured gateway share — the
  /// gateway slice used to be silently kept) is credited back to the
  /// customer's wallet.
  async cancelChildForCustomer(opts: {
    userId: number;
    parentId: number;
    childId: number;
  }): Promise<
    | { ok: true }
    | { error: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_PENDING' | 'NOT_CANCELLABLE' }
  > {
    // Policy snapshot first — the claim below re-checks status
    // atomically, so a stale read here can't over-allow.
    const snap = await prisma.purchaseRequest.findFirst({
      where: {
        id: opts.childId,
        customerOrderId: opts.parentId,
        customerUserId: opts.userId,
      },
      select: {
        id: true,
        status: true,
        shopId: true,
        invoiceId: true,
        shop: { select: { cancellationPolicy: true } },
        events: { select: { type: true } },
      },
    });
    if (!snap) {
      const existing = await prisma.purchaseRequest.findUnique({
        where: { id: opts.childId },
        select: { customerUserId: true, customerOrderId: true },
      });
      if (!existing) return { error: 'NOT_FOUND' };
      if (existing.customerUserId !== opts.userId) return { error: 'NOT_OWNED' };
      return { error: 'NOT_FOUND' };
    }
    if (snap.status === 'CONFIRMED') {
      if (!this.isCancellableByPolicy(
        snap.shop?.cancellationPolicy ?? 'UNTIL_SHIPPED',
        snap.events.map((e) => e.type),
      )) {
        return { error: 'NOT_CANCELLABLE' };
      }
      return this.cancelConfirmedChild(opts, snap.shopId, snap.invoiceId);
    }
    if (snap.status !== 'PENDING') return { error: 'NOT_PENDING' };

    // ── PENDING path: nothing issued yet, single atomic transaction ──
    // Release reserved inventory + refund paid money + back out the
    // coupon usage, all atomically with the status flip, so a partial
    // failure can't leave a CANCELLED row with the customer still
    // debited.
    const result = await prisma.$transaction(async (tx) => {
      const claim = await tx.purchaseRequest.updateMany({
        where: {
          id: opts.childId,
          customerOrderId: opts.parentId,
          customerUserId: opts.userId,
          status: 'PENDING',
        },
        data: { status: 'CANCELLED', decidedAt: new Date() },
      });
      if (claim.count !== 1) {
        return { needsDiag: true as const };
      }

      // Snapshot the cancelled child so we can refund + release.
      const child = await tx.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.childId },
        select: {
          id: true,
          estimatedTotal: true,
          customerUserId: true,
          customerOrderId: true,
          items: { select: { productId: true, quantity: true } },
        },
      });

      // Refund the cancelled slice's share of everything the customer
      // has actually PAID so far: the parent's wallet payment plus, when
      // the order was captured online, its gateway payment. The gateway
      // slice used to be silently dropped here — a customer who paid
      // ₹1,000 via Razorpay and cancelled got only the wallet share
      // back. Refund lands in the wallet (instant, reusable money — the
      // same vehicle the returns flow uses). If this is the only/last
      // shop in the order, the full paid amount comes back; otherwise
      // the slice gets a proportional share keyed on the original split
      // (estimatedTotal share of parent.estimatedTotal at order create).
      const parent = await tx.customerOrder.findUnique({
        where: { id: opts.parentId },
        select: {
          id: true,
          walletPaid: true,
          estimatedTotal: true,
          couponDiscount: true,
          paymentStatus: true,
        },
      });
      if (parent) {
        const childTotal = Number(child.estimatedTotal);
        const parentTotal = Number(parent.estimatedTotal);
        const paidTotal = this.totalPaidOnOrder(parent);
        if (paidTotal > 0 && parentTotal > 0) {
          const share = Math.min(childTotal / parentTotal, 1);
          const refund = round2(paidTotal * share);
          if (refund > 0) {
            // Namespaced idempotency key so a cancel + return on the
            // same childId can't collide.
            await walletService.credit({
              userId: child.customerUserId,
              amount: refund,
              source: 'CANCEL',
              sourceId: child.id,
              description: `Cancel refund for order #${parent.id} (slice #${child.id})`,
              idempotencyKey: `wallet:cancel-${child.id}`,
              tx,
            });
          }
        }
      }

      // If THIS cancellation was the last live child, decrement the
      // parent's coupon redemption (so the customer's per-user cap +
      // the global totalRedemptions counter aren't permanently
      // consumed by an order that never happened).
      const liveSiblings = await tx.purchaseRequest.count({
        where: {
          customerOrderId: opts.parentId,
          status: { notIn: ['CANCELLED', 'REJECTED'] },
        },
      });
      if (liveSiblings === 0) {
        const redemption = await tx.couponRedemption.findUnique({
          where: { customerOrderId: opts.parentId },
          select: { id: true, couponId: true },
        });
        if (redemption) {
          await tx.coupon.update({
            where: { id: redemption.couponId },
            data: { totalRedemptions: { decrement: 1 } },
          });
          await tx.couponRedemption.delete({ where: { id: redemption.id } });
        }
      }

      await tx.purchaseRequestEvent.create({
        data: {
          requestId: opts.childId,
          type: 'CANCELLED',
          actorId: opts.userId,
        },
      });
      return { ok: true as const };
    });

    if ('ok' in result) {
      // Best-effort Route clawback: if the captured order already split
      // a HELD transfer to this child's seller, pull it back (no-op when
      // splits are disabled / nothing was transferred).
      await reverseTransferForReturn({
        purchaseRequestId: opts.childId,
        reverseAmount: REVERSE_ALL,
      }).catch(() => undefined);
      return { ok: true };
    }

    const existing = await prisma.purchaseRequest.findUnique({
      where: { id: opts.childId },
      select: { customerUserId: true, customerOrderId: true, status: true },
    });
    if (!existing) return { error: 'NOT_FOUND' };
    if (existing.customerUserId !== opts.userId) return { error: 'NOT_OWNED' };
    if (existing.customerOrderId !== opts.parentId) return { error: 'NOT_FOUND' };
    return { error: 'NOT_PENDING' };
  }

  /// Order milestones that close the customer-cancel window for each
  /// policy. UNTIL_CONFIRMED has no entry — confirmation itself is the
  /// cut-off, handled before this map is consulted.
  private static readonly CANCEL_BLOCKERS: Record<string, string[]> = {
    UNTIL_PACKED: ['PACKED', 'SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED'],
    UNTIL_SHIPPED: ['SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED'],
    UNTIL_DELIVERED: ['DELIVERED'],
  };

  /// Can a CONFIRMED child still be cancelled under `policy`, given the
  /// shipping milestones already posted?
  isCancellableByPolicy(policy: string, eventTypes: string[]): boolean {
    if (policy === 'UNTIL_CONFIRMED') return false;
    const blockers =
      PurchaseRequestsService.CANCEL_BLOCKERS[policy] ??
      PurchaseRequestsService.CANCEL_BLOCKERS.UNTIL_SHIPPED;
    return !eventTypes.some((t) => blockers.includes(t));
  }

  /// Everything the customer has actually paid on the parent order so
  /// far: wallet debit (synchronous at checkout) + the captured gateway
  /// remainder. COD / not-yet-captured orders have only the wallet part.
  private totalPaidOnOrder(parent: {
    walletPaid: unknown;
    estimatedTotal: unknown;
    couponDiscount: unknown;
    paymentStatus: string;
  }): number {
    const walletPaid = Number(parent.walletPaid);
    const gatewayPaid =
      parent.paymentStatus === 'PAID'
        ? Math.max(
            0,
            round2(
              Number(parent.estimatedTotal) -
                Number(parent.couponDiscount) -
                walletPaid,
            ),
          )
        : 0;
    return round2(walletPaid + gatewayPaid);
  }

  /// Cancel a CONFIRMED child (policy already verified by the caller).
  ///
  /// Sequencing: the status claim and the invoice cancellation cannot
  /// share one transaction (invoicesService.updateStatus opens its own —
  /// the same nesting constraint confirmRequest works around), so this
  /// runs claim → invoice-cancel → refund-tx with explicit compensation:
  /// if the invoice can't be cancelled the claim is reverted and the
  /// child stays CONFIRMED.
  private async cancelConfirmedChild(
    opts: { userId: number; parentId: number; childId: number },
    shopId: number,
    invoiceId: number | null,
  ): Promise<{ ok: true } | { error: 'NOT_PENDING' | 'NOT_CANCELLABLE' }> {
    const claim = await prisma.purchaseRequest.updateMany({
      where: {
        id: opts.childId,
        customerOrderId: opts.parentId,
        customerUserId: opts.userId,
        status: 'CONFIRMED',
      },
      data: { status: 'CANCELLED', decidedAt: new Date() },
    });
    // Raced away (another cancel, or the merchant moved it) — re-read
    // would just repeat the public diagnostics; NOT_PENDING is accurate.
    if (claim.count !== 1) return { error: 'NOT_PENDING' };

    const revert = () =>
      prisma.purchaseRequest.updateMany({
        where: { id: opts.childId, status: 'CANCELLED' },
        data: { status: 'CONFIRMED' },
      });

    // 1) Cancel the invoice — reverses its stock ledger rows. Failure
    //    reverts the claim so we never strand a CANCELLED child with a
    //    live CONFIRMED invoice still counting in stock + reports.
    if (invoiceId != null) {
      let cancelled;
      try {
        cancelled = await invoicesService.updateStatus(
          shopId,
          invoiceId,
          'CANCELLED',
          opts.userId,
        );
      } catch (err) {
        await revert();
        throw err;
      }
      if ('error' in cancelled) {
        await revert();
        return { error: 'NOT_CANCELLABLE' };
      }
      // Void the wallet/gateway receipts that were reconciled onto the
      // invoice: the money they represent is being handed back to the
      // customer below, and a live credit on a cancelled invoice would
      // read as a phantom negative balance on the party ledger.
      const receipts = await prisma.payment.findMany({
        where: { invoiceId, shopId, voidedAt: null },
        select: { id: true },
      });
      for (const r of receipts) {
        await paymentsService.voidPayment(
          shopId,
          r.id,
          opts.userId,
          'Order cancelled by customer — refunded to wallet',
        );
      }
    }

    // 2) Refund + releases, atomically.
    await prisma.$transaction(async (tx) => {
      const child = await tx.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.childId },
        select: {
          id: true,
          estimatedTotal: true,
          customerUserId: true,
          items: { select: { productId: true, quantity: true } },
        },
      });
      const parent = await tx.customerOrder.findUnique({
        where: { id: opts.parentId },
        select: {
          id: true,
          walletPaid: true,
          estimatedTotal: true,
          couponDiscount: true,
          paymentStatus: true,
        },
      });
      if (parent) {
        const parentTotal = Number(parent.estimatedTotal);
        const paidTotal = this.totalPaidOnOrder(parent);
        if (paidTotal > 0 && parentTotal > 0) {
          const share = Math.min(Number(child.estimatedTotal) / parentTotal, 1);
          const refund = round2(paidTotal * share);
          if (refund > 0) {
            await walletService.credit({
              userId: child.customerUserId,
              amount: refund,
              source: 'CANCEL',
              sourceId: child.id,
              description: `Cancel refund for order #${parent.id} (slice #${child.id})`,
              idempotencyKey: `wallet:cancel-${child.id}`,
              tx,
            });
          }
        }
      }

      const liveSiblings = await tx.purchaseRequest.count({
        where: {
          customerOrderId: opts.parentId,
          status: { notIn: ['CANCELLED', 'REJECTED'] },
        },
      });
      if (liveSiblings === 0) {
        const redemption = await tx.couponRedemption.findUnique({
          where: { customerOrderId: opts.parentId },
          select: { id: true, couponId: true },
        });
        if (redemption) {
          await tx.coupon.update({
            where: { id: redemption.couponId },
            data: { totalRedemptions: { decrement: 1 } },
          });
          await tx.couponRedemption.delete({ where: { id: redemption.id } });
        }
      }

      await tx.purchaseRequestEvent.create({
        data: {
          requestId: opts.childId,
          type: 'CANCELLED',
          actorId: opts.userId,
        },
      });
    });

    // 3) Best-effort Route clawback of this child's HELD transfer.
    await reverseTransferForReturn({
      purchaseRequestId: opts.childId,
      reverseAmount: REVERSE_ALL,
    }).catch(() => undefined);

    return { ok: true };
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
    const row = await prisma.purchaseRequest.findFirst({
      where: { id, shopId },
      select: detailSelect,
    });
    if (!row) return null;
    return {
      ...row,
      invoice: row.invoice ? attachInvoicePaymentSummary(row.invoice) : null,
    };
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
  ///   3. Stock is decremented atomically per product via a gated
  ///      updateMany (decrement only when stockQuantity >= requested).
  ///      Two concurrent confirms for the same row therefore can't
  ///      both succeed past a stale read; the loser bails out with
  ///      INSUFFICIENT_STOCK and the outer transaction rolls back any
  ///      sibling decrements taken earlier in the same call.
  async confirmRequest(opts: {
    shopId: number;
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' | 'NO_ITEMS' | 'INSUFFICIENT_STOCK' | string; productId?: number; available?: number; requested?: number }
    | { invoice: { id: number; invoiceNo: string } }
  > {
    // We CANNOT nest the createInvoice tx inside an outer `prisma.$transaction`
    // here. `invoicesService.createInvoice` opens its own interactive
    // transaction, which Prisma does not nest. The old code returning
    // `{error}` from the outer callback would COMMIT (not roll back),
    // leaving the row stuck in PROCESSING. We solve this by NOT using
    // an outer tx and instead managing the rollback explicitly: every
    // failure path below resets the row from PROCESSING back to PENDING
    // so the merchant can retry.

    // ── 1. Atomic claim scoped to this shop ──────────────────────
    const claim = await prisma.purchaseRequest.updateMany({
      where: { id: opts.requestId, shopId: opts.shopId, status: 'PENDING' },
      data: { status: 'PROCESSING' },
    });
    if (claim.count === 0) {
      const probe = await prisma.purchaseRequest.findFirst({
        where: { id: opts.requestId, shopId: opts.shopId },
        select: { id: true },
      });
      return { error: probe ? 'NOT_PENDING' : 'NOT_FOUND' as const };
    }

    const revertToPending = async (): Promise<void> => {
      // Best-effort restore so a follow-up confirm can re-attempt. We
      // gate on PROCESSING to avoid clobbering a (very unlikely) human
      // who intervened between us.
      await prisma.purchaseRequest
        .updateMany({
          where: { id: opts.requestId, status: 'PROCESSING' },
          data: { status: 'PENDING' },
        })
        .catch(() => undefined);
    };

    try {
      // ── 2. Load full row (now safely ours to act on) ─────────────
      const request = await prisma.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.requestId },
        include: {
          items: true,
          // Needed to apportion the order-level coupon discount onto this
          // shop's invoice (H4). The coupon was applied across the whole
          // CustomerOrder; this child shop earns its proportional slice.
          customerOrder: {
            select: { couponDiscount: true, estimatedTotal: true },
          },
        },
      });
      if (request.items.length === 0) {
        await revertToPending();
        return { error: 'NO_ITEMS' as const };
      }

      // ── 3. Find-or-create Party for this customer in this shop ────
      // Reuses an existing linked Party row if one already exists, so a
      // repeat buyer doesn't accumulate N duplicate party rows (one per
      // order). Falls back to create on first contact.
      let partyId = request.partyId;
      if (!partyId) {
        const existing = await prisma.party.findFirst({
          where: {
            shopId: request.shopId,
            linkedUserId: request.customerUserId,
          },
          select: { id: true },
        });
        if (existing) {
          partyId = existing.id;
        } else {
          const created = await prisma.party.create({
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
      }

      // ── 4. Mint + auto-confirm the invoice ───────────────────────
      // Runs in its own atomic transaction inside invoicesService —
      // both the invoice rows and the ledger entries either both
      // succeed or both roll back. We surface failures back to the
      // caller and revert our PROCESSING claim.
      // This shop's slice of the order-level coupon (H4). The coupon was
      // applied across the whole CustomerOrder at submit time; each child
      // shop earns its proportional share so the invoice bills — and
      // charges GST on (Sec 15(3)) — the post-coupon net the customer
      // actually owes, instead of the full pre-coupon amount.
      const order = request.customerOrder;
      const orderCoupon = Number(order.couponDiscount) || 0;
      const parentTotal = Number(order.estimatedTotal) || 0;
      const thisShopTotal = Number(request.estimatedTotal) || 0;
      const couponShare =
        orderCoupon > 0 && parentTotal > 0
          ? round2(orderCoupon * (thisShopTotal / parentTotal))
          : 0;

      const result = await invoicesService.createInvoice({
        shopId: request.shopId,
        type: 'SALE',
        partyId,
        customerName: request.customerName,
        customerPhone: request.customerPhone ?? undefined,
        note: opts.note ?? request.note ?? undefined,
        // Header discount = this shop's coupon share (H4).
        discount: couponShare > 0 ? couponShare : undefined,
        items: request.items.map((i) => ({
          productId: i.productId,
          quantity: Number(i.quantity),
          unitPrice: Number(i.unitPrice),
          // The snapshot unitPrice already has the flash-sale / carousel
          // promo baked in. Pass an explicit 0 so the invoice engine's
          // promo auto-fill doesn't subtract the same discount a second
          // time (H1). taxPercent is intentionally omitted so the engine
          // fills it from the product's GST rate (C1).
          discount: 0,
        })),
        confirm: true,
        confirmedById: opts.decidedById,
      });

      if ('error' in result) {
        await revertToPending();
        return { error: result.error ?? 'INVOICE_FAILED' as const };
      }
      // Auto-confirm failed (most commonly: ledger could not decrement
      // stock atomically). The DRAFT invoice exists but stock didn't
      // move — caller's UI can re-render the inbox so the merchant can
      // edit and retry. Revert our PROCESSING claim too.
      if ('confirmError' in result && result.confirmError) {
        const ce = result.confirmError as {
          error: string;
          productId?: number;
          available?: number;
          requested?: number;
        };
        await revertToPending();
        if (ce.error === 'Insufficient stock for one or more items') {
          return {
            error: 'INSUFFICIENT_STOCK' as const,
            productId: ce.productId,
            available: ce.available,
            requested: ce.requested,
          };
        }
        return { error: ce.error };
      }

      // ── 5. Mark CONFIRMED + link the invoice ─────────────────────
      await prisma.purchaseRequest.update({
        where: { id: request.id },
        data: {
          status: 'CONFIRMED',
          invoiceId: result.invoice.id,
          partyId,
          decidedById: opts.decidedById,
          decidedAt: new Date(),
          decisionNote: opts.note ?? null,
          events: {
            create: {
              type: 'CONFIRMED',
              actorId: opts.decidedById,
              note: opts.note ?? null,
            },
          },
        },
      });

      // ── 6. Record the online payment against this fresh invoice ──
      // If the customer already paid online (pay-then-confirm — the common
      // case), settle that captured amount onto the merchant's ledger now so
      // the invoice shows PAID instead of UNPAID. Idempotent + best-effort:
      // a failure here must NOT roll back the (already committed) invoice —
      // the confirm-then-pay path and any later run reconcile it.
      try {
        await ensureOrderInvoiceReceipts(request.customerOrderId);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(
          `[confirmRequest] receipt reconcile failed for order ${request.customerOrderId}:`,
          err instanceof Error ? err.message : err,
        );
      }

      return {
        invoice: { id: result.invoice.id, invoiceNo: result.invoice.invoiceNo },
      };
    } catch (e) {
      // Unexpected throw between claim and confirmation. Make sure
      // we don't leak a PROCESSING row that blocks future retries.
      await revertToPending();
      throw e;
    }
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
    // Atomic claim + side-effects (event, wallet refund proportional to
    // this child's share, coupon decrement when the last sibling goes
    // terminal). All inside a single transaction so a downstream
    // failure can't leave a REJECTED row with the customer still
    // debited or the coupon counter still consumed.
    const result = await prisma.$transaction(async (tx) => {
      const update = await tx.purchaseRequest.updateMany({
        where: { id: opts.requestId, shopId: opts.shopId, status: 'PENDING' },
        data: {
          status: 'REJECTED',
          decidedById: opts.decidedById,
          decidedAt: new Date(),
          decisionNote: opts.note ?? null,
        },
      });
      if (update.count !== 1) {
        return { needsDiag: true as const };
      }

      const child = await tx.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.requestId },
        select: {
          id: true,
          customerUserId: true,
          customerOrderId: true,
          estimatedTotal: true,
          items: { select: { productId: true, quantity: true } },
        },
      });

      // Refund proportional to this child's share, mirroring the cancel
      // path — wallet debit plus, when the order was captured online,
      // the gateway slice (previously silently kept on rejection).
      if (child.customerOrderId !== null) {
        const parent = await tx.customerOrder.findUnique({
          where: { id: child.customerOrderId },
          select: {
            walletPaid: true,
            estimatedTotal: true,
            couponDiscount: true,
            paymentStatus: true,
          },
        });
        if (parent) {
          const parentTotal = Number(parent.estimatedTotal);
          const childTotal = Number(child.estimatedTotal);
          const paidTotal = this.totalPaidOnOrder(parent);
          if (paidTotal > 0 && parentTotal > 0) {
            const share = Math.min(childTotal / parentTotal, 1);
            const refund = round2(paidTotal * share);
            if (refund > 0) {
              await walletService.credit({
                userId: child.customerUserId,
                amount: refund,
                source: 'CANCEL',
                sourceId: child.id,
                description: `Merchant rejection refund for child #${child.id}`,
                idempotencyKey: `wallet:reject-${child.id}`,
                tx,
              });
            }
          }
        }
      }

      // Decrement coupon redemption when this rejection drops the last
      // live sibling.
      if (child.customerOrderId !== null) {
        const liveSiblings = await tx.purchaseRequest.count({
          where: {
            customerOrderId: child.customerOrderId,
            status: { notIn: ['CANCELLED', 'REJECTED'] },
          },
        });
        if (liveSiblings === 0) {
          const redemption = await tx.couponRedemption.findUnique({
            where: { customerOrderId: child.customerOrderId },
            select: { id: true, couponId: true },
          });
          if (redemption) {
            await tx.coupon.update({
              where: { id: redemption.couponId },
              data: { totalRedemptions: { decrement: 1 } },
            });
            await tx.couponRedemption.delete({ where: { id: redemption.id } });
          }
        }
      }

      await tx.purchaseRequestEvent.create({
        data: {
          requestId: opts.requestId,
          type: 'REJECTED',
          actorId: opts.decidedById,
          note: opts.note ?? null,
        },
      });
      return { ok: true as const };
    });

    if ('ok' in result) {
      // Best-effort Route clawback, mirroring the customer-cancel path.
      await reverseTransferForReturn({
        purchaseRequestId: opts.requestId,
        reverseAmount: REVERSE_ALL,
      }).catch(() => undefined);
      return { ok: true };
    }

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

  /// Merchant-side — append a shipping milestone to the child's event
  /// timeline. Restricted to the post-confirmation set (PACKED through
  /// DELIVERED/RETURNED) since lifecycle events are emitted by the
  /// service automatically; merchants can't fabricate a CREATED row.
  async addShippingEvent(opts: {
    shopId: number;
    requestId: number;
    actorId: number;
    type: 'PACKED' | 'SHIPPED' | 'OUT_FOR_DELIVERY' | 'DELIVERED' | 'RETURNED';
    courier?: string | null;
    awb?: string | null;
    eta?: Date | null;
    note?: string | null;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_CONFIRMED' }
    | { event: { id: number; type: string; occurredAt: Date } }
  > {
    const pr = await prisma.purchaseRequest.findFirst({
      where: { id: opts.requestId, shopId: opts.shopId },
      select: { id: true, status: true, shop: { select: { returnsEnabled: true } } },
    });
    if (!pr) return { error: 'NOT_FOUND' };
    // Only confirmed orders can move through shipping milestones.
    if (pr.status !== 'CONFIRMED') return { error: 'NOT_CONFIRMED' };
    const created = await prisma.purchaseRequestEvent.create({
      data: {
        requestId: opts.requestId,
        type: opts.type,
        actorId: opts.actorId,
        courier: opts.courier ?? null,
        awb: opts.awb ?? null,
        eta: opts.eta ?? null,
        note: opts.note ?? null,
      },
      select: { id: true, type: true, occurredAt: true },
    });
    // Route on-hold fast-path: on DELIVERED, release the seller's held slice
    // early ONLY when the shop has no return window — otherwise the money must
    // stay held so an in-hold return can reverse cleanly (the P2 sweep releases
    // it at window close). Best-effort + flag-gated; never blocks the event.
    if (opts.type === 'DELIVERED' && pr.shop.returnsEnabled === false) {
      try {
        await releaseTransfersForPurchaseRequest(opts.requestId);
      } catch {
        /* the reconcile sweep is the backstop; the event already recorded. */
      }
    }
    return { event: created };
  }

  /// Customer-side — list buyable items from a past order so the
  /// "Buy again" button can add them to the cart in one tap. Filters
  /// out items the customer can no longer purchase: inactive products,
  /// unpublished, deleted, or products belonging to the buyer's own
  /// shop. Returns the reasons for any skips so the client can show a
  /// "3 added, 1 unavailable" message.
  async reorderItems(opts: { userId: number; parentId: number }): Promise<
    | { error: 'NOT_FOUND' }
    | {
        items: Array<{
          productId: number;
          quantity: number;
          product: unknown;
        }>;
        skipped: Array<{ productId: number; productName: string; reason: 'UNAVAILABLE' | 'OWN_SHOP' }>;
      }
  > {
    const parent = await prisma.customerOrder.findFirst({
      where: { id: opts.parentId, customerUserId: opts.userId },
      select: {
        shopOrders: {
          select: {
            items: {
              select: {
                productId: true,
                productName: true,
                quantity: true,
              },
            },
          },
        },
      },
    });
    if (!parent) return { error: 'NOT_FOUND' };

    // Flatten per-shop lines, summing quantities for duplicated SKUs
    // (a single product can appear twice if the customer bought it
    // across two checkouts merged into one shop).
    const want = new Map<number, { quantity: number; productName: string }>();
    for (const child of parent.shopOrders) {
      for (const it of child.items) {
        const prev = want.get(it.productId);
        want.set(it.productId, {
          quantity: (prev?.quantity ?? 0) + Number(it.quantity),
          productName: prev?.productName ?? it.productName,
        });
      }
    }
    if (want.size === 0) return { items: [], skipped: [] };

    // Single fetch — pick up the full catalog projection so the
    // customer can hand each line straight into the cart provider
    // without a follow-up product fetch.
    const products = await prisma.product.findMany({
      where: { id: { in: [...want.keys()] } },
      select: {
        id: true,
        name: true,
        sku: true,
        unit: true,
        sellingPrice: true,
        mrp: true,
        taxPercent: true,
        stockQuantity: true,
        isActive: true,
        isPublished: true,
        shop: { select: { id: true, name: true, slug: true, ownerUserId: true } },
        category: { select: { id: true, name: true, iconName: true } },
        images: {
          select: { url: true },
          orderBy: { sortOrder: 'asc' as const },
          take: 1,
        },
      },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));

    const items: Array<{
      productId: number;
      quantity: number;
      product: typeof products[number];
    }> = [];
    const skipped: Array<{
      productId: number;
      productName: string;
      reason: 'UNAVAILABLE' | 'OWN_SHOP';
    }> = [];
    for (const [productId, info] of want) {
      const p = productMap.get(productId);
      if (!p || !p.isActive || !p.isPublished) {
        skipped.push({ productId, productName: info.productName, reason: 'UNAVAILABLE' });
        continue;
      }
      if (p.shop.ownerUserId === opts.userId) {
        skipped.push({ productId, productName: info.productName, reason: 'OWN_SHOP' });
        continue;
      }
      items.push({ productId, quantity: info.quantity, product: p });
    }
    return { items, skipped };
  }

  /// Customer-side — fetch the linked invoice id + shop scope for a
  /// child order so the PDF endpoint can authorise + delegate to the
  /// existing merchant-side PDF generator without a second query.
  async customerInvoiceContext(opts: {
    userId: number;
    parentId: number;
    childId: number;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_INVOICED' }
    | { invoiceId: number; shopId: number; invoiceNo: string }
  > {
    const child = await prisma.purchaseRequest.findFirst({
      where: {
        id: opts.childId,
        customerOrderId: opts.parentId,
        customerUserId: opts.userId,
      },
      select: {
        shopId: true,
        invoiceId: true,
        invoice: { select: { invoiceNo: true } },
      },
    });
    if (!child) return { error: 'NOT_FOUND' };
    if (!child.invoiceId || !child.invoice) return { error: 'NOT_INVOICED' };
    return {
      invoiceId: child.invoiceId,
      shopId: child.shopId,
      invoiceNo: child.invoice.invoiceNo,
    };
  }

  /// Idempotency replay helper — returns the existing order envelope
  /// when (customerUserId, idempotencyKey) already exists, or null when
  /// it doesn't. Pulled out of createForCustomer so that 463-line
  /// method starts with the actual checkout flow rather than ~30 lines
  /// of bookkeeping.
  private async _replayIdempotentOrder(
    customerUserId: number,
    idempotencyKey: string,
  ): Promise<
    | {
        order: {
          id: number;
          shopOrders: { id: number; shopId: number }[];
          couponDiscount: number;
          walletPaid: number;
        };
        deduplicated: true;
      }
    | null
  > {
    const existing = await prisma.customerOrder.findUnique({
      where: {
        customer_orders_user_idempotency_key: {
          customerUserId,
          idempotencyKey,
        },
      },
      select: {
        id: true,
        couponDiscount: true,
        walletPaid: true,
        shopOrders: { select: { id: true, shopId: true } },
      },
    });
    if (!existing) return null;
    return {
      order: {
        id: existing.id,
        shopOrders: existing.shopOrders,
        couponDiscount: Number(existing.couponDiscount),
        walletPaid: Number(existing.walletPaid),
      },
      deduplicated: true,
    };
  }

  /// Start an online (gateway) payment for the online-payable remainder of a
  /// customer order — estimatedTotal − couponDiscount − walletPaid. Creates a
  /// GatewayPayment intent (settlement target ORDER, id = this order) and flips
  /// the order to PENDING; the ORDER settlement handler flips it to PAID on
  /// webhook capture. Idempotent per order via the `order:<id>` key — a retry
  /// (abandoned sheet, flaky network) reuses the same intent + Razorpay order.
  async initiateOnlinePayment(opts: {
    userId: number;
    orderId: number;
  }): Promise<
    | { error: 'NOT_FOUND' | 'ALREADY_PAID' | 'NOTHING_TO_PAY' }
    | {
        ok: true;
        payment: Awaited<ReturnType<typeof paymentGatewayService.initiatePayment>>;
      }
  > {
    const order = await prisma.customerOrder.findFirst({
      where: { id: opts.orderId, customerUserId: opts.userId },
      select: {
        id: true,
        estimatedTotal: true,
        couponDiscount: true,
        walletPaid: true,
        paymentStatus: true,
      },
    });
    if (!order) return { error: 'NOT_FOUND' };
    if (order.paymentStatus === 'PAID') return { error: 'ALREADY_PAID' };

    const payable = round2(
      Number(order.estimatedTotal) -
        Number(order.couponDiscount) -
        Number(order.walletPaid),
    );
    if (!(payable > 0)) return { error: 'NOTHING_TO_PAY' };

    const payment = await paymentGatewayService.initiatePayment({
      provider: 'RAZORPAY',
      target: { type: 'ORDER', id: order.id },
      amount: payable,
      currency: 'INR',
      shopId: null,
      customerUserId: opts.userId,
      idempotencyKey: `order:${order.id}`,
    });

    // Flip to PENDING, but never clobber a PAID set by a racing webhook.
    await prisma.customerOrder.updateMany({
      where: { id: order.id, paymentStatus: { not: 'PAID' } },
      data: { paymentStatus: 'PENDING' },
    });

    return { ok: true, payment };
  }

  /// Client-confirm after the checkout sheet returns success. Re-checks the live
  /// provider order and settles if paid (marks the order PAID + posts merchant
  /// receipts), then returns the order's resulting paymentStatus. The webhook is
  /// still authoritative; this covers environments it can't reach (localhost) and
  /// makes the "paid but shows pending" gap impossible. Idempotent.
  async syncOnlinePayment(opts: {
    userId: number;
    orderId: number;
  }): Promise<{ error: 'NOT_FOUND' } | { ok: true; paymentStatus: string; settled: boolean }> {
    const order = await prisma.customerOrder.findFirst({
      where: { id: opts.orderId, customerUserId: opts.userId },
      select: { id: true },
    });
    if (!order) return { error: 'NOT_FOUND' };

    const sync = await paymentGatewayService.syncIntentStatus({
      customerUserId: opts.userId,
      idempotencyKey: `order:${order.id}`,
    });

    const fresh = await prisma.customerOrder.findUnique({
      where: { id: order.id },
      select: { paymentStatus: true },
    });
    return {
      ok: true,
      paymentStatus: fresh?.paymentStatus ?? 'COD',
      settled: sync.settled,
    };
  }
}

export const purchaseRequestsService = new PurchaseRequestsService();
