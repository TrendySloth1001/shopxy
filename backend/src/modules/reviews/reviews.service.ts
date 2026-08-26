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
      verifiedCount: Math.min(verifiedCount, ratingCount),
      histogram,
      recent,
    };
  }

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
