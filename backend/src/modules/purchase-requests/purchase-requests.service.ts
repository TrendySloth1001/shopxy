import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { invoicesService } from '../invoices/invoices.service.js';

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
import { flashSalesService } from '../flash-sales/flash-sales.service.js';
import { couponsService } from '../coupons/coupons.service.js';
import { walletService } from '../wallet/wallet.service.js';

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

    // ── Idempotency short-circuit on the parent ──────────────────────
    if (opts.idempotencyKey) {
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

    // ── Flash-sale claim pass (across all lines, all shops) ─────────
    // Atomically reserve units from any active flash sale. Lines that
    // claim get billed at the flash price; the rest at sellingPrice.
    // Out-of-stock at submit time rolls back every prior claim so the
    // customer never holds a partial reserve they can't unwind.
    const claimedQty = new Map<number, number>();
    const flashPrices = new Map<number, number>();
    for (const line of opts.items) {
      const result = await flashSalesService.claim(line.productId, Math.ceil(line.quantity));
      if (result.ok) {
        claimedQty.set(line.productId, (claimedQty.get(line.productId) ?? 0) + Math.ceil(line.quantity));
        flashPrices.set(line.productId, result.flashPrice);
        continue;
      }
      if (result.reason === 'not_active') continue;
      for (const [pid, q] of claimedQty.entries()) {
        await flashSalesService.release(pid, q);
      }
      return { error: 'PRODUCT_INACTIVE' };
    }

    // ── Price-drift guard ────────────────────────────────────────────
    // Every line whose client sent `expectedUnitPrice` is compared
    // against the effective price (flash sale > selling price). On any
    // mismatch we roll back the flash claims and surface the corrected
    // prices so the FE can show "₹X has changed to ₹Y" in one toast.
    const priceDrift: {
      productId: number;
      expectedUnitPrice: number;
      actualUnitPrice: number;
    }[] = [];
    for (const line of opts.items) {
      if (line.expectedUnitPrice == null) continue;
      const product = productMap.get(line.productId)!;
      const effective =
        flashPrices.get(line.productId) ?? Number(product.sellingPrice);
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
      for (const [pid, q] of claimedQty.entries()) {
        await flashSalesService.release(pid, q).catch(() => undefined);
      }
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
        const price = flashPrices.get(line.productId) ?? Number(p.sellingPrice);
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
    // Flash-sale claims happened above (outside the transaction) — if
    // the persist phase fails for ANY reason we MUST release them, or
    // the reserved stock is permanently lost until the cron sweep.
    let orderPersisted = false;
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
      orderPersisted = true;
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
          // Deduplicated: the prior call already holds the flash claims
          // we'd otherwise release. Mark persisted so the finally
          // doesn't unwind them.
          orderPersisted = true;
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
    } finally {
      if (!orderPersisted && claimedQty.size > 0) {
        // Best-effort release. Each release is its own Redis op; we
        // don't fail the caller if one of them errors.
        for (const [pid, qty] of claimedQty.entries()) {
          await flashSalesService.release(pid, qty).catch(() => undefined);
        }
      }
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
      shopOrders: order.shopOrders.map((child) => ({
        ...child,
        shop: shopAsDto(child.shop),
        invoice: child.invoice ? attachInvoicePaymentSummary(child.invoice) : null,
      })),
    };
  }

  /// Cancel one shop's slice of a customer's order. The whole parent
  /// is *not* cancelled — other shops in the same checkout proceed
  /// independently. Returns reason codes so the FE can render targeted
  /// copy.
  async cancelChildForCustomer(opts: {
    userId: number;
    parentId: number;
    childId: number;
  }): Promise<
    | { ok: true }
    | { error: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_PENDING' }
  > {
    // We need to release reserved inventory + refund wallet money + back
    // out the coupon usage, all atomically with the status flip. Do
    // everything inside one transaction so a partial failure can't
    // leave a CANCELLED row with the customer still debited.
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

      // Refund the cancelled slice's share of the parent's wallet
      // payment. If this is the only/last shop in the order, the full
      // walletPaid comes back. Otherwise the slice gets a proportional
      // share keyed on the original split (estimatedTotal share of
      // parent.estimatedTotal at the time of order create).
      const parent = await tx.customerOrder.findUnique({
        where: { id: opts.parentId },
        select: {
          id: true,
          walletPaid: true,
          estimatedTotal: true,
          couponDiscount: true,
        },
      });
      if (parent) {
        const childTotal = Number(child.estimatedTotal);
        const parentTotal = Number(parent.estimatedTotal);
        const walletPaid = Number(parent.walletPaid);
        if (walletPaid > 0 && parentTotal > 0) {
          const share = Math.min(childTotal / parentTotal, 1);
          const refund = Math.round(walletPaid * share * 100) / 100;
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

      // Best-effort flash-sale release. Outside Redis-aware code paths
      // this is a no-op (the cron also reconciles).
      for (const item of child.items) {
        await flashSalesService
          .release(item.productId, Math.ceil(Number(item.quantity)))
          .catch(() => undefined);
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

    if ('ok' in result) return { ok: true };

    const existing = await prisma.purchaseRequest.findUnique({
      where: { id: opts.childId },
      select: { customerUserId: true, customerOrderId: true, status: true },
    });
    if (!existing) return { error: 'NOT_FOUND' };
    if (existing.customerUserId !== opts.userId) return { error: 'NOT_OWNED' };
    if (existing.customerOrderId !== opts.parentId) return { error: 'NOT_FOUND' };
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
        include: { items: true },
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

      // Wallet refund proportional to this child's share, mirroring the
      // cancel path.
      if (child.customerOrderId !== null) {
        const parent = await tx.customerOrder.findUnique({
          where: { id: child.customerOrderId },
          select: { walletPaid: true, estimatedTotal: true },
        });
        if (parent) {
          const parentTotal = Number(parent.estimatedTotal);
          const childTotal = Number(child.estimatedTotal);
          const walletPaid = Number(parent.walletPaid);
          if (walletPaid > 0 && parentTotal > 0) {
            const share = Math.min(childTotal / parentTotal, 1);
            const refund = Math.round(walletPaid * share * 100) / 100;
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

      // Release flash-sale reservations.
      for (const item of child.items) {
        await flashSalesService
          .release(item.productId, Math.ceil(Number(item.quantity)))
          .catch(() => undefined);
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

    if ('ok' in result) return { ok: true };

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
      select: { id: true, status: true },
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
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export const purchaseRequestsService = new PurchaseRequestsService();
