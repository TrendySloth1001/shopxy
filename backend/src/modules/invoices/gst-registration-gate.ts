import type { PrismaClient, Prisma, RegistrationType } from '@prisma/client';

function utcCalendarDate(d: Date): number {
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

export function isOutputGstRegistered(
  owner: {
    shopGstin: string | null;
    registrationType: RegistrationType;
    gstEffectiveFrom: Date | null;
  },
  asOf: Date,
): boolean {
  if (owner.registrationType !== 'REGULAR' || !owner.shopGstin) return false;
  if (owner.gstEffectiveFrom == null) return true;
  return utcCalendarDate(asOf) >= utcCalendarDate(owner.gstEffectiveFrom);
}

export async function chargesOutputGstForSale(
  db: PrismaClient | Prisma.TransactionClient,
  shopId: number,
  asOf: Date,
): Promise<boolean> {
  const shop = await db.shop.findUnique({
    where: { id: shopId },
    select: {
      owner: {
        select: { shopGstin: true, registrationType: true, gstEffectiveFrom: true },
      },
    },
  });
  if (!shop) return false;
  return isOutputGstRegistered(shop.owner, asOf);
}
