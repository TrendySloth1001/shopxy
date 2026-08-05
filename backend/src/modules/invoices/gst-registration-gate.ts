import type { PrismaClient, Prisma, RegistrationType } from '@prisma/client';

/// Truncates to a UTC calendar day (drops time-of-day) so a `gstEffectiveFrom`
/// DATE column (no time component) compares correctly against a document's
/// own date (`invoiceDate`/`createdAt`), which may carry one — a document
/// created at any time-of-day ON the effective date must still count as
/// GST-applicable.
function utcCalendarDate(d: Date): number {
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/// Only a regular GST-registered person may collect output tax on a SALE
/// (CGST Sec 32). REGULAR charges GST and issues tax invoices. COMPOSITION
/// holds a GSTIN but (Sec 10) cannot charge GST, and UNREGISTERED has no
/// GSTIN — both must issue a Bill of Supply with zero tax (Rule 49). Belt-
/// and-suspenders: requires REGULAR AND a GSTIN actually present, against a
/// misconfigured row.
///
/// `gstEffectiveFrom` additionally gates REGULAR by date: a shop's GSTIN
/// entry into the app is not the same event as becoming liable to collect
/// tax, so a document dated before the shop's actual registration date must
/// still be a zero-tax Bill of Supply even though the GSTIN is now on file.
/// Null means ungated — the pre-feature behaviour, preserved for every shop
/// that hasn't gone through the new date-picking flow. Compared as calendar
/// dates against the caller-supplied `asOf` (a document's own date, e.g.
/// `Invoice.invoiceDate` — NEVER wall-clock "now" for anything backdatable),
/// never today's system date.
///
/// Pure — takes the owner fields a caller already has loaded, so the
/// invoice engine (which fetches the shop for other reasons anyway) doesn't
/// pay a second query for this. [chargesOutputGstForSale] below is the
/// DB-fetching convenience wrapper for callers that haven't.
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

/// Shared by quotations — whose preview must apply the same gate at write
/// time so a quoted total doesn't silently disagree with the invoice
/// acceptance later produces — for callers that haven't already loaded the
/// shop's owner row the way the invoice engine has.
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
