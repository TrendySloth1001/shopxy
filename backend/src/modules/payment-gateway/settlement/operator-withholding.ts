/**
 * PR-C3 — e-commerce-operator tax withheld at source on a captured ORDER.
 *
 * ShopXY collects the buyer's payment in its OWN Razorpay account and splits to
 * sellers via Route. Under the GST + Income-Tax Acts that makes ShopXY an
 * "e-commerce operator" that must withhold, per seller slice of the order:
 *
 *   - GST TCS (CGST Sec 52): 1% of the NET TAXABLE value of the seller's supply.
 *       intrastate → 0.5% CGST-TCS + 0.5% SGST-TCS
 *       interstate → 1% IGST-TCS
 *     Reported monthly in GSTR-8.
 *   - Income-tax TDS (Sec 194-O): 1% of the GROSS supply value.
 *     Reported in Form 26Q.
 *
 * The withheld amount reduces the seller's Route settlement; the operator
 * deposits it to the exchequer. The COMPUTE + PERSIST path always runs (so the
 * reporting ledger exists regardless), but actually subtracting the withheld
 * amount from the Route transfer is gated behind OPERATOR_TCS_ENABLED (default
 * OFF). When the flag is OFF we still write the row (`applied=false`) for parity
 * but the seller is paid in full.
 *
 * Money math uses Prisma.Decimal throughout — never float64.
 *
 * SETTLEMENT-REDUCTION TODO (findings_deferred): the row + computation exist and
 * `applied` reflects the flag, but order-split's writeHeldTransferRows does not
 * yet read totalWithheld to shrink each GatewayTransfer.amount. Wiring that (and
 * a platform "withheld-tax" ledger destination) is the remaining step before the
 * flag can be flipped on in a Route-live environment.
 */
import { Prisma } from '@prisma/client';
import type { GatewayPaymentRecord } from '../ports/types.js';
import { envOr } from '../../../shared/env.js';

const D = Prisma.Decimal;
const HUNDRED = new D(100);
/** GST TCS, CGST Sec 52 — 1% of net taxable (0.5% + 0.5% intrastate). */
const GST_TCS_RATE = new D('1');
/** Income-tax TDS, Sec 194-O — 1% of gross supply value. */
const INCOME_TAX_TDS_RATE = new D('1');

type Db = Prisma.TransactionClient;

function dround2(d: Prisma.Decimal): Prisma.Decimal {
  return d.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
}

/** OFF unless explicitly enabled — flipping it on is a deliberate, compliance-
 *  signed-off step (it changes how much real money a seller is paid). */
export function isOperatorTcsEnabled(): boolean {
  return envOr('OPERATOR_TCS_ENABLED', 'false') === 'true';
}

export interface WithholdingSummary {
  /** Rows written/updated this run. */
  recorded: number;
  /** Σ totalWithheld across all children (Decimal-safe number). */
  totalWithheld: number;
  /** Whether the settlement reduction was applied (flag on). */
  applied: boolean;
}

/**
 * Compute + persist the operator withholding for every CONFIRMED child invoice
 * of a captured order. Idempotent via the (gatewayPaymentId, purchaseRequestId)
 * unique — a redelivered capture upserts the same figures. Tenant-scoped: each
 * row carries the seller `shopId` for GSTR-8 / 26Q reporting.
 *
 * `db` MUST be the settlement transaction client so the rows commit with the
 * paymentStatus flip + receipts.
 */
export async function recordOperatorWithholding(
  intent: GatewayPaymentRecord,
  db: Db,
): Promise<WithholdingSummary> {
  const applied = isOperatorTcsEnabled();

  // The captured intent → its confirmed children with their tax invoices. The
  // invoice carries the authoritative net taxable + GST split the document was
  // issued for; TCS/TDS are computed off THOSE, not off the cart estimate.
  const children = await db.purchaseRequest.findMany({
    where: {
      customerOrderId: intent.target.id,
      status: 'CONFIRMED',
      invoiceId: { not: null },
    },
    select: {
      id: true,
      shopId: true,
      invoice: {
        select: { taxableValue: true, total: true, isInterstate: true },
      },
    },
    orderBy: { id: 'asc' },
  });
  if (children.length === 0) {
    return { recorded: 0, totalWithheld: 0, applied };
  }

  let recorded = 0;
  let totalWithheldAll = new D(0);

  for (const child of children) {
    const inv = child.invoice;
    if (!inv) continue;

    const netTaxable = new D(inv.taxableValue); // GST TCS base (Sec 52)
    const grossAmount = new D(inv.total); // income-tax TDS base (Sec 194-O)
    const isInterstate = inv.isInterstate;

    // GST TCS = 1% of net taxable. Compute the total once, then split so the
    // halves always re-sum to the total (no paisa drift).
    const gstTcsTotal = dround2(netTaxable.mul(GST_TCS_RATE).div(HUNDRED));
    let cgstTcs = new D(0);
    let sgstTcs = new D(0);
    let igstTcs = new D(0);
    if (isInterstate) {
      igstTcs = gstTcsTotal;
    } else {
      cgstTcs = dround2(gstTcsTotal.div(2));
      sgstTcs = dround2(gstTcsTotal.sub(cgstTcs));
    }

    const incomeTaxTds = dround2(grossAmount.mul(INCOME_TAX_TDS_RATE).div(HUNDRED));
    const totalWithheld = dround2(gstTcsTotal.add(incomeTaxTds));
    totalWithheldAll = totalWithheldAll.add(totalWithheld);

    await db.operatorWithholding.upsert({
      where: {
        operator_withholding_payment_request: {
          gatewayPaymentId: intent.id,
          purchaseRequestId: child.id,
        },
      },
      create: {
        gatewayPaymentId: intent.id,
        purchaseRequestId: child.id,
        shopId: child.shopId,
        netTaxable,
        grossAmount,
        isInterstate,
        cgstTcs,
        sgstTcs,
        igstTcs,
        gstTcsTotal,
        incomeTaxTds,
        totalWithheld,
        applied,
      },
      // Redelivered capture → recompute (invoice is immutable post-confirm, so
      // figures are stable) and keep `applied` aligned with the current flag.
      update: {
        shopId: child.shopId,
        netTaxable,
        grossAmount,
        isInterstate,
        cgstTcs,
        sgstTcs,
        igstTcs,
        gstTcsTotal,
        incomeTaxTds,
        totalWithheld,
        applied,
      },
    });
    recorded++;
  }

  return {
    recorded,
    totalWithheld: dround2(totalWithheldAll).toNumber(),
    applied,
  };
}
