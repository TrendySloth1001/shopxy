import prisma from '../../infra/db/prisma.js';

const reviewSelect = {
  id: true,
  productId: true,
  userId: true,
  rating: true,
  title: true,
  body: true,
  createdAt: true,
  updatedAt: true,
  user: { select: { id: true, name: true } },
} as const;

/// The review gate: a user may only review a product they purchased
/// through this marketplace. "Purchased" = at least one CONFIRMED
/// invoice with a line for this product, where the invoice's party is
/// linked to the calling user.
///
/// DRAFT invoices don't count — the merchant could spin up a fake
/// invoice to seed reviews. The CONFIRMED gate also matches how the
/// app already treats invoices as "issued/final" elsewhere (see
/// invoices.service status transitions).
export async function canReview(userId: number, productId: number): Promise<boolean> {
  const hit = await prisma.invoiceItem.findFirst({
    where: {
      productId,
      invoice: {
        status: 'CONFIRMED',
        party: { linkedUserId: userId },
      },
    },
    select: { id: true },
  });
  return hit !== null;
}

/// Recomputes (ratingAvg, ratingCount) for a product from product_reviews
/// and writes them back to products. Always called inside the same
/// transaction as the upsert/delete so the denorm can't drift.
async function recomputeRatingDenorm(
  txClient: typeof prisma | Parameters<Parameters<typeof prisma.$transaction>[0]>[0],
  productId: number,
): Promise<void> {
  const agg = await (txClient as typeof prisma).productReview.aggregate({
    where: { productId },
    _avg: { rating: true },
    _count: { _all: true },
  });
  await (txClient as typeof prisma).product.update({
    where: { id: productId },
    data: {
      ratingAvg: agg._avg.rating,
      ratingCount: agg._count._all,
    },
  });
}

export class ReviewsService {
  /// Upserts the caller's review for a product. The (productId, userId)
  /// unique index makes editing a review a same-row update. Denorms on
  /// Product get recomputed in the same transaction.
  ///
  /// Returns `{ error: 'not_purchased' }` instead of throwing so the
  /// controller can map to 403 without parsing exception text.
  async upsertReview(args: {
    userId: number;
    productId: number;
    rating: number;
    title?: string | null;
    body?: string | null;
  }) {
    if (!(await canReview(args.userId, args.productId))) {
      return { error: 'not_purchased' as const };
    }
    if (args.rating < 1 || args.rating > 5) {
      return { error: 'invalid_rating' as const };
    }

    const review = await prisma.$transaction(async (tx) => {
      const row = await tx.productReview.upsert({
        where: {
          productId_userId: { productId: args.productId, userId: args.userId },
        },
        create: {
          productId: args.productId,
          userId: args.userId,
          rating: args.rating,
          title: args.title ?? null,
          body: args.body ?? null,
        },
        update: {
          rating: args.rating,
          title: args.title ?? null,
          body: args.body ?? null,
        },
        select: reviewSelect,
      });
      await recomputeRatingDenorm(tx as unknown as typeof prisma, args.productId);
      return row;
    });

    return { review };
  }

  /// Deletes the caller's review and recomputes denorms. Idempotent —
  /// returns null when the caller has no review for this product.
  async deleteOwnReview(userId: number, productId: number) {
    return prisma.$transaction(async (tx) => {
      const existing = await tx.productReview.findUnique({
        where: { productId_userId: { productId, userId } },
        select: { id: true },
      });
      if (!existing) return null;
      await tx.productReview.delete({ where: { id: existing.id } });
      await recomputeRatingDenorm(tx as unknown as typeof prisma, productId);
      return { ok: true };
    });
  }

  /// Cursor-paginated public listing — id-based cursor for stable
  /// ordering when reviews land mid-scroll. Newest first.
  async listForProduct(
    productId: number,
    opts: { cursor?: number; limit?: number },
  ) {
    const limit = Math.min(50, Math.max(1, opts.limit ?? 20));
    const rows = await prisma.productReview.findMany({
      where: { productId },
      orderBy: { id: 'desc' },
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: reviewSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? data[data.length - 1].id : null;
    return { data, nextCursor };
  }
}

export const reviewsService = new ReviewsService();
