import { BrandSpotlightStatus, Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Brand-spotlight model (P4):
///   merchant submits a PENDING row → platform admin reviews → flips to
///   APPROVED or REJECTED. The public surface only shows APPROVED rows
///   whose [startAt, endAt] window contains `now()`.
///
/// Service is shared across three call sites:
///   * merchant submit/list/cancel (scoped by shopId)
///   * platform admin queue + approve/reject
///   * public read (only-approved-and-live filter)

const merchantSelect = {
  id: true,
  shopId: true,
  dealLabel: true,
  subtitle: true,
  heroImageUrl: true,
  bgColor: true,
  accentColor: true,
  ctaTarget: true,
  startAt: true,
  endAt: true,
  status: true,
  rejectionReason: true,
  reviewedAt: true,
  createdAt: true,
  updatedAt: true,
} as const;

const adminSelect = {
  ...merchantSelect,
  reviewedByUserId: true,
  shop: {
    select: { id: true, name: true, slug: true, logoUrl: true },
  },
} as const;

const publicSelect = {
  id: true,
  shopId: true,
  dealLabel: true,
  subtitle: true,
  heroImageUrl: true,
  bgColor: true,
  accentColor: true,
  ctaTarget: true,
  startAt: true,
  endAt: true,
  shop: {
    select: { id: true, name: true, slug: true, logoUrl: true },
  },
} as const;

export interface CreateSpotlightInput {
  shopId: number;
  dealLabel: string;
  subtitle?: string | null;
  heroImageUrl: string;
  bgColor: string;
  accentColor?: string | null;
  ctaTarget?: string | null;
  startAt: Date;
  endAt: Date;
}

export class BrandSpotlightService {
  /// Merchant-side create. Always lands in PENDING — the merchant cannot
  /// self-approve. shopId comes from req.shopId (resolveShop middleware),
  /// never from the request body.
  async submit(input: CreateSpotlightInput) {
    return prisma.brandSpotlight.create({
      data: {
        shopId: input.shopId,
        dealLabel: input.dealLabel,
        subtitle: input.subtitle ?? null,
        heroImageUrl: input.heroImageUrl,
        bgColor: input.bgColor,
        accentColor: input.accentColor ?? null,
        ctaTarget: input.ctaTarget ?? null,
        startAt: input.startAt,
        endAt: input.endAt,
        status: BrandSpotlightStatus.PENDING,
      },
      select: merchantSelect,
    });
  }

  async listForShop(shopId: number, opts: { status?: BrandSpotlightStatus } = {}) {
    return prisma.brandSpotlight.findMany({
      where: { shopId, ...(opts.status ? { status: opts.status } : {}) },
      orderBy: [{ createdAt: 'desc' }],
      select: merchantSelect,
    });
  }

  /// Cancel = hard delete only while still PENDING (the merchant
  /// changed their mind before review). Approved/Rejected rows are
  /// kept for audit; cancel returns 409 in the controller for those.
  async cancelPending(shopId: number, id: number): Promise<'ok' | 'not_found' | 'not_pending'> {
    const row = await prisma.brandSpotlight.findUnique({
      where: { id },
      select: { shopId: true, status: true },
    });
    if (!row || row.shopId !== shopId) return 'not_found';
    if (row.status !== BrandSpotlightStatus.PENDING) return 'not_pending';
    await prisma.brandSpotlight.delete({ where: { id } });
    return 'ok';
  }

  // ── Admin ────────────────────────────────────────────────────────

  async listForAdmin(opts: { status?: BrandSpotlightStatus; cursor?: number; limit?: number }) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const where: Prisma.BrandSpotlightWhereInput = {};
    if (opts.status) where.status = opts.status;
    const rows = await prisma.brandSpotlight.findMany({
      where,
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: adminSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return { data, nextCursor: hasMore ? data[data.length - 1].id : null };
  }

  async getByIdForAdmin(id: number) {
    return prisma.brandSpotlight.findUnique({ where: { id }, select: adminSelect });
  }

  async approve(id: number, reviewerUserId: number) {
    const existing = await prisma.brandSpotlight.findUnique({
      where: { id },
      select: { status: true },
    });
    if (!existing) return null;
    return prisma.brandSpotlight.update({
      where: { id },
      data: {
        status: BrandSpotlightStatus.APPROVED,
        rejectionReason: null,
        reviewedByUserId: reviewerUserId,
        reviewedAt: new Date(),
      },
      select: adminSelect,
    });
  }

  async reject(id: number, reviewerUserId: number, reason: string) {
    const existing = await prisma.brandSpotlight.findUnique({
      where: { id },
      select: { status: true },
    });
    if (!existing) return null;
    return prisma.brandSpotlight.update({
      where: { id },
      data: {
        status: BrandSpotlightStatus.REJECTED,
        rejectionReason: reason,
        reviewedByUserId: reviewerUserId,
        reviewedAt: new Date(),
      },
      select: adminSelect,
    });
  }

  // ── Public ───────────────────────────────────────────────────────

  /// Active = APPROVED + now ∈ [startAt, endAt]. Ordered by endAt asc so
  /// "ending soon" surfaces first; the customer home strip can take the
  /// top N from the front of the list.
  async listActive() {
    const now = new Date();
    return prisma.brandSpotlight.findMany({
      where: {
        status: BrandSpotlightStatus.APPROVED,
        startAt: { lte: now },
        endAt: { gte: now },
      },
      orderBy: [{ endAt: 'asc' }],
      select: publicSelect,
    });
  }
}

export const brandSpotlightService = new BrandSpotlightService();
