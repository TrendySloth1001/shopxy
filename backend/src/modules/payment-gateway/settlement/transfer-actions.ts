import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import {
  isSplitCapable,
  type PaymentGatewayPort,
  type SplitCapablePort,
} from '../ports/payment-provider.port.js';
import { isRouteSplitEnabled } from './order-split.js';
import { toMinorUnits, fromMinorUnits } from '../helpers.js';
import { tracker } from '../tracker.js';

type SplitProvider = PaymentGatewayPort & SplitCapablePort;

const ACTIVE = ['HELD', 'PARTIALLY_REVERSED', 'RELEASED'];

async function splitProviderFor(gatewayPaymentId: number): Promise<SplitProvider | null> {
  const pay = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true },
  });
  if (!pay) return null;
  const p = getProvider(pay.provider);
  return isSplitCapable(p) ? p : null;
}

export async function releaseTransfersForPurchaseRequest(
  purchaseRequestId: number,
): Promise<{ released: number }> {
  if (!isRouteSplitEnabled()) return { released: 0 };

  const transfers = await prisma.gatewayTransfer.findMany({
    where: { purchaseRequestId, status: 'HELD', providerTransferRef: { not: null } },
    select: { id: true, gatewayPaymentId: true, providerTransferRef: true },
  });

  let released = 0;
  for (const t of transfers) {
    const provider = await splitProviderFor(t.gatewayPaymentId);
    if (!provider) continue;
    const claim = await prisma.gatewayTransfer.updateMany({
      where: { id: t.id, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: new Date() },
    });
    if (claim.count !== 1) continue;
    try {
      await provider.releaseTransfer(t.providerTransferRef!);
      released++;
    } catch (err) {
      await prisma.gatewayTransfer.updateMany({
        where: { id: t.id, status: 'RELEASED' },
        data: { status: 'HELD', releasedAt: null },
      });
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: t.gatewayPaymentId,
        meta: { phase: 'release-on-confirm', transferId: t.id, error: errMsg(err) },
      });
    }
  }
  return { released };
}

export interface ReverseResult {
  reversed: boolean;
  flagged: boolean;
  shortfall: number;
}

export async function reverseTransferForReturn(input: {
  purchaseRequestId: number;
  reverseAmount: number;
}): Promise<ReverseResult> {
  if (!isRouteSplitEnabled()) return { reversed: false, flagged: false, shortfall: 0 };

  const t = await prisma.gatewayTransfer.findFirst({
    where: {
      purchaseRequestId: input.purchaseRequestId,
      status: { in: ACTIVE },
      providerTransferRef: { not: null },
    },
    select: {
      id: true,
      gatewayPaymentId: true,
      providerTransferRef: true,
      amount: true,
      reversedAmount: true,
      status: true,
    },
    orderBy: { id: 'asc' },
  });
  if (!t) return { reversed: false, flagged: false, shortfall: 0 };

  const amountMinor = toMinorUnits(Number(t.amount));
  const alreadyMinor = toMinorUnits(Number(t.reversedAmount));
  const remainingMinor = amountMinor - alreadyMinor;

  const requestedMinor = toMinorUnits(input.reverseAmount);

  if (remainingMinor <= 0) {
    return flagShortfall(t.id, t.gatewayPaymentId, requestedMinor);
  }

  const reverseMinor = Math.min(requestedMinor, remainingMinor);
  if (reverseMinor <= 0) return { reversed: false, flagged: false, shortfall: 0 };

  const shortfallMinor = Math.max(requestedMinor - remainingMinor, 0);

  const provider = await splitProviderFor(t.gatewayPaymentId);
  if (!provider) return { reversed: false, flagged: false, shortfall: 0 };

  const newReversedMinor = alreadyMinor + reverseMinor;
  const fullyReversed = newReversedMinor >= amountMinor;
  const targetStatus = fullyReversed ? 'REVERSED' : 'PARTIALLY_REVERSED';

  const claim = await prisma.gatewayTransfer.updateMany({
    where: { id: t.id, status: { in: ACTIVE }, reversedAmount: t.reversedAmount },
    data: {
      reversedAmount: new Prisma.Decimal(fromMinorUnits(newReversedMinor)),
      status: targetStatus,
      ...(fullyReversed ? { reversedAt: new Date() } : {}),
    },
  });
  if (claim.count !== 1) return { reversed: false, flagged: false, shortfall: 0 };

  try {
    await provider.reverseTransfer(t.providerTransferRef!, reverseMinor);
    if (shortfallMinor > 0) {
      await recordShortfall(t.id, t.gatewayPaymentId, shortfallMinor);
      return { reversed: true, flagged: true, shortfall: fromMinorUnits(shortfallMinor) };
    }
    return { reversed: true, flagged: false, shortfall: 0 };
  } catch (err) {
    await prisma.gatewayTransfer.updateMany({
      where: { id: t.id, reversedAmount: new Prisma.Decimal(fromMinorUnits(newReversedMinor)) },
      data: { reversedAmount: t.reversedAmount, status: t.status },
    });
    const status = (err as { status?: number }).status;
    const insufficient =
      status === 402 || (status === 400 && /balance|insufficient/i.test(errMsg(err)));
    if (insufficient) {
      await prisma.gatewayTransfer.update({
        where: { id: t.id },
        data: { failureReason: 'REVERSAL_INSUFFICIENT_BALANCE' },
      });
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: t.gatewayPaymentId,
        meta: { phase: 'reverse-insufficient-balance', transferId: t.id, severity: 'CRITICAL' },
      });
      return { reversed: false, flagged: true, shortfall: 0 };
    }
    throw err;
  }
}

async function recordShortfall(
  transferId: number,
  gatewayPaymentId: number,
  shortfallMinor: number,
): Promise<void> {
  try {
    await prisma.gatewayTransfer.update({
      where: { id: transferId },
      data: { failureReason: 'REVERSAL_SHORTFALL' },
    });
  } catch {
  }
  tracker.track({
    step: 'ROUTE_SPLIT_FAILED',
    intentId: gatewayPaymentId,
    meta: {
      phase: 'reverse-shortfall',
      transferId,
      shortfallMinor,
      severity: 'CRITICAL',
    },
  });
}

async function flagShortfall(
  transferId: number,
  gatewayPaymentId: number,
  shortfallMinor: number,
): Promise<ReverseResult> {
  if (shortfallMinor <= 0) return { reversed: false, flagged: false, shortfall: 0 };
  await recordShortfall(transferId, gatewayPaymentId, shortfallMinor);
  return { reversed: false, flagged: true, shortfall: fromMinorUnits(shortfallMinor) };
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : 'unknown';
}
