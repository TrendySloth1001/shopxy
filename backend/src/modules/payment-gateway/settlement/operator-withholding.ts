import { Prisma } from '@prisma/client';
import type { GatewayPaymentRecord } from '../ports/types.js';
import { envOr } from '../../../shared/env.js';

const D = Prisma.Decimal;
const HUNDRED = new D(100);
const GST_TCS_RATE = new D('1');
const INCOME_TAX_TDS_RATE = new D('1');

type Db = Prisma.TransactionClient;

function dround2(d: Prisma.Decimal): Prisma.Decimal {
  return d.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
}

export function isOperatorTcsEnabled(): boolean {
  return envOr('OPERATOR_TCS_ENABLED', 'false') === 'true';
}

export interface WithholdingSummary {
  recorded: number;
  totalWithheld: number;
  applied: boolean;
}

export async function recordOperatorWithholding(
  intent: GatewayPaymentRecord,
  db: Db,
): Promise<WithholdingSummary> {
  const applied = isOperatorTcsEnabled();

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

    const netTaxable = new D(inv.taxableValue);
    const grossAmount = new D(inv.total);
    const isInterstate = inv.isInterstate;

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
