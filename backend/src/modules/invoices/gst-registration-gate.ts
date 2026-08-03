import type { PrismaClient, Prisma, RegistrationType } from '@prisma/client';

/// Only a regular GST-registered person may collect output tax on a SALE
/// (CGST Sec 32). REGULAR charges GST and issues tax invoices. COMPOSITION
/// holds a GSTIN but (Sec 10) cannot charge GST, and UNREGISTERED has no
/// GSTIN — both must issue a Bill of Supply with zero tax (Rule 49). Belt-
/// and-suspenders: requires REGULAR AND a GSTIN actually present, against a
/// misconfigured row.
///
/// Pure — takes the owner fields a caller already has loaded, so the
/// invoice engine (which fetches the shop for other reasons anyway) doesn't
/// pay a second query for this. [chargesOutputGstForSale] below is the
/// DB-fetching convenience wrapper for callers that haven't.
export function isOutputGstRegistered(owner: {
  shopGstin: string | null;
  registrationType: RegistrationType;
}): boolean {
  return owner.registrationType === 'REGULAR' && !!owner.shopGstin;
}

/// Shared by quotations — whose preview must apply the same gate at write
/// time so a quoted total doesn't silently disagree with the invoice
/// acceptance later produces — for callers that haven't already loaded the
/// shop's owner row the way the invoice engine has.
export async function chargesOutputGstForSale(
  db: PrismaClient | Prisma.TransactionClient,
  shopId: number,
): Promise<boolean> {
  const shop = await db.shop.findUnique({
    where: { id: shopId },
    select: { owner: { select: { shopGstin: true, registrationType: true } } },
  });
  if (!shop) return false;
  return isOutputGstRegistered(shop.owner);
}
