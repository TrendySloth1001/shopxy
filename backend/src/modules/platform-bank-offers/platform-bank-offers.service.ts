import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Selection shape returned by every read path. Admin and public both
/// consume the same projection — the customer doesn't see anything
/// sensitive (no creator id, no audit ledger), so there's nothing to
/// hide. Decimal columns serialise as strings, matching the rest of
/// the marketplace DTOs.
const offerSelect = {
  id: true,
  bank: true,
  cardType: true,
  discountType: true,
  discountValue: true,
  maxDiscount: true,
  minOrderAmount: true,
  terms: true,
  validFrom: true,
  validUntil: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.PlatformBankOfferSelect;

export interface PlatformBankOfferInput {
  bank: string;
  cardType: string;
  discountType: 'PERCENT' | 'FLAT';
  discountValue: number;
  maxDiscount?: number | null;
  minOrderAmount?: number;
  terms?: string | null;
  validFrom: Date;
  validUntil: Date;
  isActive?: boolean;
}

export class PlatformBankOffersService {
  /// Admin list — every row regardless of schedule + active flag so the
  /// admin UI can show "Scheduled", "Expired" and "Off" states.
  listForAdmin() {
    return prisma.platformBankOffer.findMany({
      orderBy: [{ isActive: 'desc' }, { validUntil: 'desc' }, { id: 'desc' }],
      select: offerSelect,
    });
  }

  getById(id: number) {
    return prisma.platformBankOffer.findUnique({
      where: { id },
      select: offerSelect,
    });
  }

  create(input: PlatformBankOfferInput) {
    return prisma.platformBankOffer.create({
      data: {
        bank: input.bank,
        cardType: input.cardType,
        discountType: input.discountType,
        discountValue: input.discountValue,
        maxDiscount: input.maxDiscount ?? null,
        minOrderAmount: input.minOrderAmount ?? 0,
        terms: input.terms ?? null,
        validFrom: input.validFrom,
        validUntil: input.validUntil,
        isActive: input.isActive ?? true,
      },
      select: offerSelect,
    });
  }

  async update(id: number, input: Partial<PlatformBankOfferInput>) {
    const exists = await prisma.platformBankOffer.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!exists) return null;
    return prisma.platformBankOffer.update({
      where: { id },
      data: {
        ...(input.bank !== undefined && { bank: input.bank }),
        ...(input.cardType !== undefined && { cardType: input.cardType }),
        ...(input.discountType !== undefined && {
          discountType: input.discountType,
        }),
        ...(input.discountValue !== undefined && {
          discountValue: input.discountValue,
        }),
        ...(input.maxDiscount !== undefined && {
          maxDiscount: input.maxDiscount,
        }),
        ...(input.minOrderAmount !== undefined && {
          minOrderAmount: input.minOrderAmount,
        }),
        ...(input.terms !== undefined && { terms: input.terms }),
        ...(input.validFrom !== undefined && { validFrom: input.validFrom }),
        ...(input.validUntil !== undefined && {
          validUntil: input.validUntil,
        }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
      },
      select: offerSelect,
    });
  }

  async deactivate(id: number) {
    const exists = await prisma.platformBankOffer.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!exists) return false;
    await prisma.platformBankOffer.update({
      where: { id },
      data: { isActive: false },
    });
    return true;
  }

  /// PDP-facing read. Returns every currently-eligible offer for an
  /// item priced at `productPrice`. Eligibility = active + inside the
  /// [validFrom, validUntil] window + price ≥ minOrderAmount. Sorted
  /// PERCENT-first then by discountValue desc so the biggest offer
  /// sits leftmost in the strip. Bounded to 10 rows so the strip
  /// stays scannable on mobile.
  async listEligibleForProduct(productPrice: number) {
    const now = new Date();
    const rows = await prisma.platformBankOffer.findMany({
      where: {
        isActive: true,
        validFrom: { lte: now },
        validUntil: { gte: now },
        minOrderAmount: { lte: productPrice },
      },
      orderBy: [
        { discountType: 'asc' }, // FLAT < PERCENT alphabetically — PERCENT typically wins
        { discountValue: 'desc' },
        { id: 'asc' },
      ],
      take: 10,
      select: offerSelect,
    });
    return rows;
  }
}

export const platformBankOffersService = new PlatformBankOffersService();
