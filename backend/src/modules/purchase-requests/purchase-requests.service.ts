import prisma from '../../infra/db/prisma.js';
import { Prisma } from '@prisma/client';
import { round2 } from '../../shared/numbering/decimal.js';
import { stateCodeFromName } from '../../shared/validation/indian.js';
import { resolveActiveProductPromos } from '../banners/promo-pricing.js';
import { invoicesService } from '../invoices/invoices.service.js';
import { paymentGatewayService } from '../payment-gateway/index.js';
import { ensureOrderInvoiceReceipts } from '../payment-gateway/order-receipts.js';
import {
  releaseTransfersForPurchaseRequest,
  reverseTransferForReturn,
} from '../payment-gateway/settlement/transfer-actions.js';
import { paymentsService } from '../payments/payments.service.js';

const REVERSE_ALL = Number.MAX_SAFE_INTEGER / 100;

const PAISE_TOLERANCE = new Prisma.Decimal('0.01');

function derivePaymentSummary(
  total: Prisma.Decimal,
  paid: Prisma.Decimal,
  status: string,
): { paidAmount: number; balanceDue: number; paymentStatus: 'PAID' | 'PARTIAL' | 'UNPAID' } {
  const balanceDecimal = total.minus(paid);
  const balanceDue = balanceDecimal.greaterThan(0) ? balanceDecimal.toNumber() : 0;
  let paymentStatus: 'PAID' | 'PARTIAL' | 'UNPAID';
  if (status === 'CANCELLED' || status === 'DRAFT') {
    paymentStatus = 'UNPAID';
  } else if (total.greaterThan(0) && paid.greaterThanOrEqualTo(total.minus(PAISE_TOLERANCE))) {
    paymentStatus = 'PAID';
  } else if (paid.greaterThan(PAISE_TOLERANCE)) {
    paymentStatus = 'PARTIAL';
  } else {
    paymentStatus = 'UNPAID';
  }
  return { paidAmount: paid.toNumber(), balanceDue, paymentStatus };
}
import { couponsService } from '../coupons/coupons.service.js';
import { notificationsService } from '../notifications/notifications.service.js';

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

const DETAIL_ITEMS_CAP = 200;
const DETAIL_EVENTS_CAP = 100;
const DETAIL_PAYMENTS_CAP = 100;

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
  buyerGstin: true,
  buyerLegalName: true,
  invoice: {
    select: {
      id: true,
      invoiceNo: true,
      type: true,
      status: true,
      total: true,
      invoiceDate: true,
      documentType: true,
      customerGstin: true,
      payments: { select: { amount: true }, take: DETAIL_PAYMENTS_CAP },
    },
  },
  items: {
    select: {
      ...itemSelect,
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
    take: DETAIL_ITEMS_CAP,
  },
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
    take: DETAIL_EVENTS_CAP,
  },
} satisfies Prisma.PurchaseRequestSelect;

interface CartLine {
  productId: number;
  quantity: number;
  expectedUnitPrice?: number;
}

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
    returnsEnabled: shop.returnsEnabled,
    returnWindowDays: shop.returnWindowDays,
    refundMode: shop.refundMode,
    returnPolicyNote: shop.returnPolicyNote ?? null,
  };
}

function attachInvoicePaymentSummary<
  T extends { total: Prisma.Decimal | number; status: string; payments: { amount: Prisma.Decimal | number }[] },
>(invoice: T) {
  const totalDec =
    invoice.total instanceof Prisma.Decimal
      ? invoice.total
      : new Prisma.Decimal(invoice.total);
  const paidDec = invoice.payments.reduce(
    (sum, p) =>
      sum.plus(p.amount instanceof Prisma.Decimal ? p.amount : new Prisma.Decimal(p.amount)),
    new Prisma.Decimal(0),
  );
  const summary = derivePaymentSummary(totalDec, paidDec, invoice.status);
  const { payments: _drop, ...rest } = invoice;
  return { ...rest, ...summary };
}

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

export async function ensureLinkedParty(
  db: Prisma.TransactionClient,
  opts: {
    shopId: number;
    userId: number;
    name: string;
    phone?: string | null;
    email?: string | null;
    address?: string | null;
    city?: string | null;
    state?: string | null;
    stateCode?: string | null;
    pinCode?: string | null;
    gstin?: string | null;
  },
): Promise<number> {
  const existing = await db.party.findFirst({
    where: { shopId: opts.shopId, linkedUserId: opts.userId },
    select: { id: true, gstin: true },
  });
  if (existing) {
    if (opts.gstin && !existing.gstin) {
      await db.party.update({
        where: { id: existing.id },
        data: { gstin: opts.gstin },
      });
    }
    return existing.id;
  }
  const created = await db.party.create({
    data: {
      shopId: opts.shopId,
      name: opts.name,
      phone: opts.phone ?? null,
      email: opts.email ?? null,
      address: opts.address ?? null,
      city: opts.city ?? null,
      state: opts.state ?? null,
      stateCode: opts.stateCode ?? null,
      pinCode: opts.pinCode ?? null,
      gstin: opts.gstin ?? null,
      linkedUserId: opts.userId,
    },
    select: { id: true },
  });
  return created.id;
}

export class PurchaseRequestsService {
  async createForCustomer(opts: {
    customerUserId: number;
    items: CartLine[];
    note?: string;
    idempotencyKey?: string;
    addressId?: number;
    couponCode?: string | null;
    useWallet?: boolean;
    claimGst?: boolean;
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
          | 'SHOP_ON_VACATION'
          | 'CROSS_SHOP_ITEM'
          | 'COUPON_INVALID'
          | 'GST_PROFILE_MISSING'
          | 'PRICE_DRIFT';
        priceDrift?: {
          productId: number;
          expectedUnitPrice: number;
          actualUnitPrice: number;
        }[];
      }
    | {
        order: {
          id: number;
          shopOrders: { id: number; shopId: number; customerName?: string; itemCount?: number }[];
          couponDiscount: number;
          walletPaid: number;
        };
        deduplicated?: true;
      }
  > {
    if (opts.items.length === 0) return { error: 'EMPTY_CART' };

    if (opts.idempotencyKey) {
      const replay = await this._replayIdempotentOrder(
        opts.customerUserId,
        opts.idempotencyKey,
      );
      if (replay) return replay;
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
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const line of opts.items) {
      const product = productMap.get(line.productId);
      if (!product) return { error: 'PRODUCT_MISSING' };
      if (!product.isActive) return { error: 'PRODUCT_INACTIVE' };
      if (!(line.quantity > 0)) return { error: 'BAD_QTY' };
    }

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

    const shopIds = [...linesByShop.keys()];
    const shops = await prisma.shop.findMany({
      where: { id: { in: shopIds } },
      select: { id: true, ownerUserId: true, isPublished: true, vacationMode: true },
    });
    if (shops.length !== shopIds.length) return { error: 'SHOP_NOT_FOUND' };
    for (const shop of shops) {
      if (shop.ownerUserId === opts.customerUserId) {
        return { error: 'OWN_SHOP_ITEM' };
      }
      if (!shop.isPublished) return { error: 'SHOP_NOT_FOUND' };
      if (shop.vacationMode) return { error: 'SHOP_ON_VACATION' };
    }

    const bannerPromos = await resolveActiveProductPromos(null, productIds);
    const effectiveUnitPrice = (productId: number): number => {
      const product = productMap.get(productId)!;
      const selling = Number(product.sellingPrice);
      const promo = bannerPromos.get(productId);
      return promo ? Math.max(0, round2(selling - promo.perUnit)) : selling;
    };

    const priceDrift: {
      productId: number;
      expectedUnitPrice: number;
      actualUnitPrice: number;
    }[] = [];
    for (const line of opts.items) {
      if (line.expectedUnitPrice == null) continue;
      const effective = effectiveUnitPrice(line.productId);
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

    const user = await prisma.user.findUniqueOrThrow({
      where: { id: opts.customerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        buyerGstin: true,
        buyerLegalName: true,
        linkedParties: {
          where: { isActive: true, shopId: { in: shopIds } },
          select: { id: true, shopId: true, name: true, phone: true, address: true },
        },
      },
    });
    const linkedByShop = new Map(user.linkedParties.map((p) => [p.shopId, p]));

    const claimGst = opts.claimGst === true;
    if (claimGst && (!user.buyerGstin || !user.buyerLegalName)) {
      return { error: 'GST_PROFILE_MISSING' };
    }
    const buyerGstin = claimGst ? user.buyerGstin : null;
    const buyerLegalName = claimGst ? user.buyerLegalName : null;

    let snapshotName: string | null = null;
    let snapshotPhone: string | null = null;
    let snapshotAddress: string | null = null;
    let shipCity: string | null = null;
    let shipState: string | null = null;
    let shipStateCode: string | null = null;
    let shipPincode: string | null = null;
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
      shipCity = addr.city;
      shipState = addr.state;
      shipPincode = addr.pincode;
      shipStateCode = stateCodeFromName(addr.state);
    }

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

    try {
      const order = await prisma.$transaction(async (tx) => {
        const parent = await tx.customerOrder.create({
          data: {
            customerUserId: opts.customerUserId,
            customerName: snapshotName ?? user.name,
            customerPhone: snapshotPhone,
            customerEmail: user.email,
            customerAddress: snapshotAddress,
            shipCity,
            shipState,
            shipStateCode,
            shipPincode,
            note: opts.note ?? null,
            buyerGstin,
            buyerLegalName,
            estimatedTotal: round2(parentTotal),
            idempotencyKey: opts.idempotencyKey ?? null,
          },
          select: { id: true },
        });

        let couponDiscount = 0;
        let couponShopId: number | null = null;
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
          couponShopId = result.couponShopId;
        }

        const walletPaid = 0;

        if (couponDiscount > 0) {
          await tx.customerOrder.update({
            where: { id: parent.id },
            data: {
              couponDiscount: round2(couponDiscount),
              walletPaid: round2(walletPaid),
              couponShopId,
            },
          });
        }

        const childRecords: { id: number; shopId: number; customerName?: string; itemCount?: number }[] = [];
        for (const child of childPayloads) {
          const partyId = await ensureLinkedParty(tx, {
            shopId: child.shopId,
            userId: opts.customerUserId,
            name: buyerLegalName ?? child.customerName,
            phone: child.customerPhone,
            email: user.email,
            address: child.customerAddress,
            city: shipCity,
            state: shipState,
            stateCode: shipStateCode,
            pinCode: shipPincode,
            gstin: buyerGstin,
          });
          const created = await tx.purchaseRequest.create({
            data: {
              customerOrderId: parent.id,
              shopId: child.shopId,
              customerUserId: opts.customerUserId,
              partyId,
              customerName: child.customerName,
              customerPhone: child.customerPhone,
              customerEmail: user.email,
              customerAddress: child.customerAddress,
              shipCity,
              shipState,
              shipStateCode,
              shipPincode,
              note: opts.note ?? null,
              buyerGstin,
              buyerLegalName,
              estimatedTotal: child.estimatedTotal,
              items: { create: child.items },
              events: {
                create: { type: 'CREATED', actorId: opts.customerUserId },
              },
            },
            select: { id: true, shopId: true, customerName: true, _count: { select: { items: true } } },
          });
          childRecords.push({
            id: created.id,
            shopId: created.shopId,
            customerName: created.customerName,
            itemCount: created._count.items,
          });
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

  async cancelChildForCustomer(opts: {
    userId: number;
    parentId: number;
    childId: number;
  }): Promise<
    | { ok: true }
    | { error: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_PENDING' | 'NOT_CANCELLABLE' }
  > {
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

    let cancelRefund = 0;
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

      const parent = await tx.customerOrder.findUnique({
        where: { id: opts.parentId },
        select: { id: true, walletPaid: true, estimatedTotal: true },
      });
      if (parent) {
        cancelRefund = await this.refundShareForChild(tx, parent, child);
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
      return { ok: true as const };
    });

    if ('ok' in result) {
      await reverseTransferForReturn({
        purchaseRequestId: opts.childId,
        reverseAmount: REVERSE_ALL,
      }).catch(() => undefined);
      await this.refundCancelledChildToSource({
        parentId: opts.parentId,
        childId: opts.childId,
        amount: cancelRefund,
        kind: 'cancel',
      });
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

  private static readonly CANCEL_BLOCKERS: Record<string, string[]> = {
    UNTIL_PACKED: ['PACKED', 'SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED'],
    UNTIL_SHIPPED: ['SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED'],
    UNTIL_DELIVERED: ['DELIVERED'],
  };

  isCancellableByPolicy(policy: string, eventTypes: string[]): boolean {
    if (policy === 'UNTIL_CONFIRMED') return false;
    const blockers =
      PurchaseRequestsService.CANCEL_BLOCKERS[policy] ??
      PurchaseRequestsService.CANCEL_BLOCKERS.UNTIL_SHIPPED;
    return !eventTypes.some((t) => blockers.includes(t));
  }

  private async totalPaidOnOrder(
    tx: Prisma.TransactionClient,
    parent: { id: number; walletPaid: unknown },
  ): Promise<number> {
    const walletPaid = Number(parent.walletPaid);
    const gw = await tx.gatewayPayment.findFirst({
      where: { targetType: 'ORDER', targetId: parent.id, status: 'CAPTURED' },
      select: { amount: true },
    });
    const gatewayPaid = gw ? Number(gw.amount) : 0;
    return round2(walletPaid + gatewayPaid);
  }

  private async refundShareForChild(
    tx: Prisma.TransactionClient,
    parent: { id: number; walletPaid: unknown; estimatedTotal: unknown },
    child: { id: number; estimatedTotal: unknown },
  ): Promise<number> {
    const paidTotal = await this.totalPaidOnOrder(tx, parent);
    const parentTotal = Number(parent.estimatedTotal);
    if (paidTotal <= 0 || parentTotal <= 0) return 0;

    const liveSiblings = await tx.purchaseRequest.count({
      where: {
        customerOrderId: parent.id,
        id: { not: child.id },
        status: { notIn: ['CANCELLED', 'REJECTED'] },
      },
    });

    if (liveSiblings === 0) {
      return paidTotal;
    }

    const share = Math.min(Number(child.estimatedTotal) / parentTotal, 1);
    return round2(paidTotal * share);
  }

  private async refundCancelledChildToSource(input: {
    parentId: number;
    childId: number;
    amount: number;
    kind: 'cancel' | 'reject';
  }): Promise<void> {
    if (!(input.amount > 0)) return;
    try {
      await paymentGatewayService.refundToSource({
        targetType: 'ORDER',
        targetId: input.parentId,
        amount: input.amount,
        sourceType: 'CANCEL',
        sourceId: input.childId,
        idempotencyKey: `${input.kind}-${input.childId}`,
        reason:
          input.kind === 'reject'
            ? `Merchant rejection refund for child #${input.childId}`
            : `Cancel refund for order #${input.parentId} (slice #${input.childId})`,
        notes: { orderId: String(input.parentId), childId: String(input.childId) },
      });
    } catch {
    }
  }

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
    if (claim.count !== 1) return { error: 'NOT_PENDING' };

    const revert = () =>
      prisma.purchaseRequest.updateMany({
        where: { id: opts.childId, status: 'CANCELLED' },
        data: { status: 'CONFIRMED' },
      });

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
      const receipts = await prisma.payment.findMany({
        where: { invoiceId, shopId, voidedAt: null },
        select: { id: true },
      });
      for (const r of receipts) {
        await paymentsService.voidPayment(
          shopId,
          r.id,
          opts.userId,
          'Order cancelled by customer — refunded to original payment method',
          { allowPlatformCollected: true },
        );
      }
    }

    let cancelRefund = 0;
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
        select: { id: true, walletPaid: true, estimatedTotal: true },
      });
      if (parent) {
        cancelRefund = await this.refundShareForChild(tx, parent, child);
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

    await reverseTransferForReturn({
      purchaseRequestId: opts.childId,
      reverseAmount: REVERSE_ALL,
    }).catch(() => undefined);

    await this.refundCancelledChildToSource({
      parentId: opts.parentId,
      childId: opts.childId,
      amount: cancelRefund,
      kind: 'cancel',
    });

    return { ok: true };
  }

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

  async confirmRequest(opts: {
    shopId: number;
    requestId: number;
    decidedById: number;
    note?: string;
  }): Promise<
    | { error: 'NOT_FOUND' | 'NOT_PENDING' | 'NO_ITEMS' | 'INSUFFICIENT_STOCK' | string; productId?: number; available?: number; requested?: number }
    | { invoice: { id: number; invoiceNo: string } }
  > {
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
      await prisma.purchaseRequest
        .updateMany({
          where: { id: opts.requestId, status: 'PROCESSING' },
          data: { status: 'PENDING' },
        })
        .catch(() => undefined);
    };

    try {
      const request = await prisma.purchaseRequest.findUniqueOrThrow({
        where: { id: opts.requestId },
        include: {
          items: true,
          customerOrder: {
            select: {
              couponDiscount: true,
              estimatedTotal: true,
              couponShopId: true,
            },
          },
        },
      });
      if (request.items.length === 0) {
        await revertToPending();
        return { error: 'NO_ITEMS' as const };
      }

      const partyId =
        request.partyId ??
        (await ensureLinkedParty(prisma, {
          shopId: request.shopId,
          userId: request.customerUserId,
          gstin: request.buyerGstin,
          name: request.buyerLegalName ?? request.customerName,
          phone: request.customerPhone,
          email: request.customerEmail,
          address: request.customerAddress,
          city: request.shipCity,
          state: request.shipState,
          stateCode: request.shipStateCode,
          pinCode: request.shipPincode,
        }));

      const order = request.customerOrder;
      const orderCoupon = Number(order.couponDiscount) || 0;
      const thisShopTotal = Number(request.estimatedTotal) || 0;
      const isSellerFundedForThisShop =
        order.couponShopId != null && order.couponShopId === request.shopId;
      const couponShare =
        isSellerFundedForThisShop && orderCoupon > 0
          ? round2(Math.min(orderCoupon, thisShopTotal))
          : 0;

      const placeOfSupplyStateCode = request.shipStateCode ?? undefined;

      const result = await invoicesService.createInvoice({
        shopId: request.shopId,
        type: 'SALE',
        partyId,
        customerName: request.buyerLegalName ?? request.customerName,
        customerGstin: request.buyerGstin ?? undefined,
        customerPhone: request.customerPhone ?? undefined,
        placeOfSupplyStateCode,
        note: opts.note ?? request.note ?? undefined,
        discount: couponShare > 0 ? couponShare : undefined,
        items: request.items.map((i) => ({
          productId: i.productId,
          quantity: Number(i.quantity),
          unitPrice: Number(i.unitPrice),
          discount: 0,
        })),
        confirm: true,
        confirmedById: opts.decidedById,
      });

      if ('error' in result) {
        await revertToPending();
        return { error: result.error ?? 'INVOICE_FAILED' as const };
      }
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
    let rejectRefund = 0;
    let rejectParentId: number | null = null;
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

      if (child.customerOrderId !== null) {
        const parent = await tx.customerOrder.findUnique({
          where: { id: child.customerOrderId },
          select: { id: true, walletPaid: true, estimatedTotal: true },
        });
        if (parent) {
          rejectRefund = await this.refundShareForChild(tx, parent, child);
          rejectParentId = parent.id;
        }
      }

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
      await reverseTransferForReturn({
        purchaseRequestId: opts.requestId,
        reverseAmount: REVERSE_ALL,
      }).catch(() => undefined);
      if (rejectParentId != null) {
        await this.refundCancelledChildToSource({
          parentId: rejectParentId,
          childId: opts.requestId,
          amount: rejectRefund,
          kind: 'reject',
        });
      }
      return { ok: true };
    }

    const probe = await prisma.purchaseRequest.findFirst({
      where: { id: opts.requestId, shopId: opts.shopId },
      select: { id: true },
    });
    return { error: probe ? 'NOT_PENDING' : 'NOT_FOUND' };
  }

  async pendingCount(shopId: number) {
    return prisma.purchaseRequest.count({ where: { shopId, status: 'PENDING' } });
  }

  async addShippingEvent(opts: {
    shopId: number;
    requestId: number;
    actorId: number;
    type: 'PACKED' | 'SHIPPED' | 'OUT_FOR_DELIVERY' | 'DELIVERED';
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
    if (opts.type === 'DELIVERED' && pr.shop.returnsEnabled === false) {
      try {
        await releaseTransfersForPurchaseRequest(opts.requestId);
      } catch {
      }
    }
    return { event: created };
  }

  async reorderItems(opts: { userId: number; parentId: number }): Promise<
    | { error: 'NOT_FOUND' }
    | {
        items: Array<{
          productId: number;
          quantity: number;
          effectiveUnitPrice: number;
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

    const reorderPromos = await resolveActiveProductPromos(null, [...want.keys()]);
    const effectiveUnitPrice = (p: typeof products[number]): number => {
      const selling = Number(p.sellingPrice);
      const promo = reorderPromos.get(p.id);
      return promo ? Math.max(0, round2(selling - promo.perUnit)) : selling;
    };

    const items: Array<{
      productId: number;
      quantity: number;
      effectiveUnitPrice: number;
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
      items.push({
        productId,
        quantity: info.quantity,
        effectiveUnitPrice: effectiveUnitPrice(p),
        product: p,
      });
    }
    return { items, skipped };
  }

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

    await prisma.customerOrder.updateMany({
      where: { id: order.id, paymentStatus: { not: 'PAID' } },
      data: { paymentStatus: 'PENDING' },
    });

    return { ok: true, payment };
  }

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
      paymentStatus: fresh?.paymentStatus ?? 'UNKNOWN',
      settled: sync.settled,
    };
  }
}

export const purchaseRequestsService = new PurchaseRequestsService();
