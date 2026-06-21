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

  /// One-shot summary payload for the PDP review block: average,
  /// total count, per-star histogram (always 1..5 keyed and
  /// zero-filled so the client doesn't need to guard for missing
  /// keys), how many of those came from CONFIRMED-invoice buyers
  /// (measured, not assumed — see verifiedCount below), and the three
  /// most recent reviews so the section can render without a
  /// follow-up list call.
  async getSummary(productId: number) {
    const [agg, buckets, recent, verifiedCount] = await Promise.all([
      prisma.productReview.aggregate({
        where: { productId },
        _avg: { rating: true },
        _count: { _all: true },
      }),
      prisma.productReview.groupBy({
        by: ['rating'],
        where: { productId },
        _count: { _all: true },
      }),
      prisma.productReview.findMany({
        where: { productId },
        orderBy: { id: 'desc' },
        take: 3,
        select: reviewSelect,
      }),
      // CP (E-Commerce) Rules 2020 r.4 / IS 19000 — "verified buyer" must
      // be a measured purchase signal, NOT assumed equal to ratingCount.
      // A review is verified iff its author has a CONFIRMED-invoice line
      // for this product whose party is linked to that author (the same
      // condition canReview enforces at write time). Count distinct
      // reviewers who satisfy it so a seeded/imported/ungated review is
      // never mislabeled.
      this.countVerifiedReviews(productId),
    ]);

    const histogram: Record<string, number> = {
      '1': 0, '2': 0, '3': 0, '4': 0, '5': 0,
    };
    for (const row of buckets) {
      const key = String(row.rating);
      if (key in histogram) histogram[key] = row._count._all;
    }

    const ratingCount = agg._count._all;
    return {
      ratingAvg: agg._avg.rating,
      ratingCount,
      // Measured from actual verified-purchase rows (see above), capped
      // at ratingCount defensively. Never assumed equal to ratingCount.
      verifiedCount: Math.min(verifiedCount, ratingCount),
      histogram,
      recent,
    };
  }

  /// Counts how many reviewers of this product are verified buyers — i.e.
  /// have at least one CONFIRMED-invoice line for the product whose party
  /// is linked to them (the canReview condition). One review per user is
  /// enforced by the (productId, userId) unique index, so a distinct
  /// reviewer count equals a distinct verified-review count.
  private async countVerifiedReviews(productId: number): Promise<number> {
    const reviewers = await prisma.productReview.findMany({
      where: { productId },
      select: { userId: true },
    });
    if (reviewers.length === 0) return 0;
    const reviewerIds = reviewers.map((r) => r.userId);

    const verified = await prisma.invoiceItem.findMany({
      where: {
        productId,
        invoice: {
          status: 'CONFIRMED',
          party: { linkedUserId: { in: reviewerIds } },
        },
      },
      select: { invoice: { select: { party: { select: { linkedUserId: true } } } } },
    });
    const verifiedUserIds = new Set<number>();
    for (const row of verified) {
      const uid = row.invoice.party?.linkedUserId;
      if (uid != null) verifiedUserIds.add(uid);
    }
    return verifiedUserIds.size;
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

  /// "My reviews" feed — every review the caller has written, with
  /// the product (name + first image) joined so the profile page
  /// can render a card per row without a second fetch. Cursor on
  /// id for stable ordering when the user edits an old review.
  async listForUser(
    userId: number,
    opts: { cursor?: number; limit?: number },
  ) {
    const limit = Math.min(50, Math.max(1, opts.limit ?? 20));
    const rows = await prisma.productReview.findMany({
      where: { userId },
      orderBy: { id: 'desc' },
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: {
        ...reviewSelect,
        product: {
          select: {
            id: true,
            name: true,
            sellingPrice: true,
            images: {
              select: { url: true, sortOrder: true },
              orderBy: { sortOrder: 'asc' },
              take: 1,
            },
          },
        },
      },
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? data[data.length - 1].id : null;
    return { data, nextCursor };
  }
}

export const reviewsService = new ReviewsService();
