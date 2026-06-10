import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { nextCautionRef } from '../../shared/numbering/sequences.js';
import { toNumber } from '../../shared/numbering/decimal.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import { paymentGatewayService } from '../payment-gateway/index.js';

export type CautionRequestStatus =
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'CANCELLED';

const requestSelect = {
  id: true,
  shopId: true,
  partyId: true,
  amount: true,
  mode: true,
  modeReference: true,
  note: true,
  basket: true,
  basketValue: true,
  status: true,
  channel: true,
  reviewNote: true,
  reviewedAt: true,
  cautionTxnId: true,
  createdAt: true,
  updatedAt: true,
  party: { select: { id: true, name: true } },
} satisfies Prisma.CautionRequestSelect;

type RequestRow = Prisma.CautionRequestGetPayload<{ select: typeof requestSelect }>;

function toDTO(r: RequestRow) {
  return {
    ...r,
    amount: toNumber(r.amount),
    basketValue: r.basketValue == null ? null : toNumber(r.basketValue),
  };
}

/// One basket line the customer browsed. Validated/normalised in createRequest.
export interface CautionBasketItem {
  productId: number;
  name: string;
  sku?: string | null;
  qty: number;
  unitPrice: number;
}

/// Party-initiated caution requests. A linked customer declares a deposit
/// they want to post (amount + how they'll pay); the merchant approves —
/// which mints a confirmed `CautionTxn(DEPOSIT)` — or rejects. The customer
/// can cancel while still PENDING. Balance never counts a request, only the
/// DEPOSIT produced on approval. `approveCautionRequest` is the single
/// confirmation entry point a future payment-gateway webhook will also call.
export class CautionRequestsService {
  /// Customer creates a PENDING request and the shop owner is notified.
  /// Returns null when the party isn't in this shop.
  async createRequest(
    shopId: number,
    partyId: number,
    requestedById: number,
    input: {
      amount: number;
      mode?: string | null;
      modeReference?: string | null;
      note?: string | null;
      basket?: CautionBasketItem[] | null;
    },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: {
        id: true,
        name: true,
        shop: { select: { id: true, ownerUserId: true } },
      },
    });
    if (!party) return null;

    // Normalise the basket: compute each line total + the overall value
    // server-side so we never trust a client-sent total. Null when empty.
    const basketItems = (input.basket ?? []).filter((b) => b.qty > 0);
    const basketJson =
      basketItems.length === 0
        ? null
        : basketItems.map((b) => ({
            productId: b.productId,
            name: b.name,
            sku: b.sku ?? null,
            qty: b.qty,
            unitPrice: b.unitPrice,
            lineTotal: Math.round(b.qty * b.unitPrice * 100) / 100,
          }));
    const basketValue =
      basketJson == null
        ? null
        : new Prisma.Decimal(
            basketJson.reduce((sum, b) => sum + b.lineTotal, 0),
          );

    const created = await prisma.$transaction(async (tx) => {
      const row = await tx.cautionRequest.create({
        data: {
          shopId,
          partyId,
          amount: new Prisma.Decimal(input.amount),
          mode: input.mode ?? null,
          modeReference: input.modeReference ?? null,
          note: input.note ?? null,
          basket: (basketJson ?? Prisma.JsonNull) as Prisma.InputJsonValue,
          basketValue,
          status: 'PENDING',
          channel: 'MANUAL',
          requestedById,
        },
        select: requestSelect,
      });

      await tx.notification.create({
        data: {
          userId: party.shop.ownerUserId,
          kind: 'CAUTION_REQUEST_RECEIVED',
          title: `${party.name} requested to post a caution`,
          body: basketItems.length > 0
            ? `₹${input.amount.toFixed(2)} via ${input.mode ?? 'bank transfer'} · against ${basketItems.length} item(s)`
            : `₹${input.amount.toFixed(2)} via ${input.mode ?? 'bank transfer'}`,
          data: {
            cautionRequestId: row.id,
            partyId,
            amount: input.amount,
          },
        },
      });

      return row;
    });

    return toDTO(created);
  }

  /// The party's own requests (customer view) — newest first, paginated.
  async listForParty(
    shopId: number,
    partyId: number,
    opts: { status?: CautionRequestStatus; skip: number; take: number },
  ) {
    const where: Prisma.CautionRequestWhereInput = { shopId, partyId };
    if (opts.status) where.status = opts.status;
    const [rows, total] = await Promise.all([
      prisma.cautionRequest.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: opts.skip,
        take: opts.take,
        select: requestSelect,
      }),
      prisma.cautionRequest.count({ where }),
    ]);
    return { data: rows.map(toDTO), total };
  }

  /// Shop-wide inbox (merchant view) — defaults to PENDING when no status.
  async listForShop(
    shopId: number,
    opts: { status?: CautionRequestStatus; skip: number; take: number },
  ) {
    const where: Prisma.CautionRequestWhereInput = { shopId };
    if (opts.status) where.status = opts.status;
    const [rows, total] = await Promise.all([
      prisma.cautionRequest.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: opts.skip,
        take: opts.take,
        select: requestSelect,
      }),
      prisma.cautionRequest.count({ where }),
    ]);
    return { data: rows.map(toDTO), total };
  }

  /// Merchant approves a PENDING request → mints a confirmed DEPOSIT (with a
  /// caution receipt number), links it back, and notifies the customer. The
  /// `updateMany` status claim is the race guard against a double-approve;
  /// Serializable isolation keeps the deposit + counter bump consistent.
  /// This is the single confirmation entry point — a gateway webhook would
  /// resolve the request by `providerRef` and call straight into this path.
  async approveCautionRequest(
    shopId: number,
    requestId: number,
    reviewerId: number,
  ) {
    return prisma.$transaction(
      async (tx) => {
        const req = await tx.cautionRequest.findFirst({
          where: { id: requestId, shopId },
          select: {
            id: true,
            partyId: true,
            amount: true,
            mode: true,
            modeReference: true,
            note: true,
            requestedById: true,
          },
        });
        if (!req) {
          throw new HttpError(404, 'CAUTION_REQUEST_NOT_FOUND', 'Request not found');
        }

        const claimed = await tx.cautionRequest.updateMany({
          where: { id: requestId, shopId, status: 'PENDING' },
          data: { status: 'APPROVED', reviewedById: reviewerId, reviewedAt: new Date() },
        });
        if (claimed.count === 0) {
          throw new HttpError(
            409,
            'CAUTION_REQUEST_NOT_PENDING',
            'Request is no longer pending',
          );
        }

        const receiptNo = await nextCautionRef(shopId, new Date(), tx);
        const txn = await tx.cautionTxn.create({
          data: {
            shopId,
            partyId: req.partyId,
            type: 'DEPOSIT',
            amount: req.amount,
            mode: req.mode,
            modeReference: req.modeReference,
            receiptNo,
            note: req.note ?? 'Approved caution request',
            createdById: reviewerId,
          },
        });

        const updated = await tx.cautionRequest.update({
          where: { id: requestId },
          data: { cautionTxnId: txn.id },
          select: requestSelect,
        });

        if (req.requestedById) {
          await tx.notification.create({
            data: {
              userId: req.requestedById,
              kind: 'CAUTION_REQUEST_APPROVED',
              title: 'Your caution deposit was approved',
              body: `₹${toNumber(req.amount).toFixed(2)} added to your deposit (receipt ${receiptNo})`,
              data: { cautionRequestId: requestId, partyId: req.partyId },
            },
          });
        }

        return toDTO(updated);
      },
      { isolationLevel: 'Serializable' },
    );
  }

  /// Merchant rejects a PENDING request and notifies the customer.
  async rejectRequest(
    shopId: number,
    requestId: number,
    reviewerId: number,
    reviewNote?: string | null,
  ) {
    return prisma.$transaction(async (tx) => {
      const req = await tx.cautionRequest.findFirst({
        where: { id: requestId, shopId },
        select: { id: true, partyId: true, amount: true, requestedById: true },
      });
      if (!req) {
        throw new HttpError(404, 'CAUTION_REQUEST_NOT_FOUND', 'Request not found');
      }

      const claimed = await tx.cautionRequest.updateMany({
        where: { id: requestId, shopId, status: 'PENDING' },
        data: {
          status: 'REJECTED',
          reviewedById: reviewerId,
          reviewedAt: new Date(),
          reviewNote: reviewNote ?? null,
        },
      });
      if (claimed.count === 0) {
        throw new HttpError(
          409,
          'CAUTION_REQUEST_NOT_PENDING',
          'Request is no longer pending',
        );
      }

      const updated = await tx.cautionRequest.findUniqueOrThrow({
        where: { id: requestId },
        select: requestSelect,
      });

      if (req.requestedById) {
        await tx.notification.create({
          data: {
            userId: req.requestedById,
            kind: 'CAUTION_REQUEST_REJECTED',
            title: 'Your caution deposit request was declined',
            body: reviewNote ?? null,
            data: { cautionRequestId: requestId, partyId: req.partyId },
          },
        });
      }

      return toDTO(updated);
    });
  }

  /// Customer starts an ONLINE payment for their own PENDING request —
  /// returns the gateway checkout session (provider, providerOrderRef,
  /// clientParams) the app opens the Razorpay sheet with. The CAUTION
  /// settlement handler mints the DEPOSIT on webhook capture; nothing is
  /// approved on the client callback. Ownership is proven by the /me guard.
  async initiateOnlinePayment(opts: {
    shopId: number;
    partyId: number;
    requestId: number;
    userId: number;
  }) {
    const req = await prisma.cautionRequest.findFirst({
      where: { id: opts.requestId, shopId: opts.shopId, partyId: opts.partyId },
      select: { id: true, amount: true, status: true },
    });
    if (!req) {
      throw new HttpError(404, 'CAUTION_REQUEST_NOT_FOUND', 'Request not found');
    }
    if (req.status !== 'PENDING') {
      throw new HttpError(
        409,
        'CAUTION_REQUEST_NOT_PENDING',
        'Request is no longer pending',
      );
    }

    const payment = await paymentGatewayService.initiatePayment({
      provider: 'RAZORPAY',
      target: { type: 'CAUTION', id: req.id },
      amount: toNumber(req.amount),
      currency: 'INR',
      shopId: opts.shopId,
      customerUserId: opts.userId,
      idempotencyKey: `caution:${req.id}`,
    });

    // Stamp the gateway seam (display/reconciliation only — settlement
    // re-stamps authoritatively on capture). Guarded on PENDING so a
    // racing webhook's APPROVED stamp is never overwritten.
    await prisma.cautionRequest.updateMany({
      where: { id: req.id, status: 'PENDING' },
      data: {
        channel: 'GATEWAY',
        provider: 'RAZORPAY',
        providerRef: payment.providerOrderRef ?? null,
      },
    });

    return payment;
  }

  /// Client-confirm after the checkout sheet returns success: re-checks the
  /// live provider order and settles if paid (webhook backstop — localhost
  /// dev and webhook lag), then returns the fresh request so the app can
  /// render APPROVED immediately. Idempotent.
  async syncOnlinePayment(opts: {
    shopId: number;
    partyId: number;
    requestId: number;
    userId: number;
  }) {
    const req = await prisma.cautionRequest.findFirst({
      where: { id: opts.requestId, shopId: opts.shopId, partyId: opts.partyId },
      select: { id: true },
    });
    if (!req) {
      throw new HttpError(404, 'CAUTION_REQUEST_NOT_FOUND', 'Request not found');
    }

    const sync = await paymentGatewayService.syncIntentStatus({
      customerUserId: opts.userId,
      idempotencyKey: `caution:${req.id}`,
    });

    const fresh = await prisma.cautionRequest.findUniqueOrThrow({
      where: { id: req.id },
      select: requestSelect,
    });
    return { request: toDTO(fresh), settled: sync.settled };
  }

  /// Customer cancels their own PENDING request. Ownership (the caller is the
  /// linked user of this party) is proven by the /me guard before we get here.
  async cancelRequest(partyId: number, requestId: number) {
    const claimed = await prisma.cautionRequest.updateMany({
      where: { id: requestId, partyId, status: 'PENDING' },
      data: { status: 'CANCELLED' },
    });
    if (claimed.count === 0) {
      const exists = await prisma.cautionRequest.findFirst({
        where: { id: requestId, partyId },
        select: { id: true },
      });
      if (!exists) {
        throw new HttpError(404, 'CAUTION_REQUEST_NOT_FOUND', 'Request not found');
      }
      throw new HttpError(
        409,
        'CAUTION_REQUEST_NOT_PENDING',
        'Request is no longer pending',
      );
    }
    const updated = await prisma.cautionRequest.findUniqueOrThrow({
      where: { id: requestId },
      select: requestSelect,
    });
    return toDTO(updated);
  }
}

export const cautionRequestsService = new CautionRequestsService();
