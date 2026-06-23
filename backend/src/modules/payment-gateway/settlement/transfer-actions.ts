/**
 * The buyer-driven half of the on-hold split — the two-way symmetry:
 *   • releaseTransfersForPurchaseRequest — buyer confirms delivery → release the
 *     seller's held slice early (the P2 sweep is the backstop).
 *   • reverseTransferForReturn — a return refund claws the seller's slice back
 *     into the platform, partial-aware, BEFORE it ever reaches the seller.
 *
 * Both are claim-once + idempotent, no-op when ROUTE_SPLIT_ENABLED is off, and
 * route every provider call through the adapter (retry/circuit breaker). P5:
 * a reversal that fails for insufficient balance (funds already settled/withdrawn)
 * is FLAGGED for manual recovery and NEVER blocks the customer's refund.
 */
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

// A transfer is still actionable (releasable / reversible) in these states.
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

/**
 * Release the held transfers for one delivered child (buyer-confirm fast path).
 * Claim-once HELD→RELEASED, then release; roll back on a provider failure so a
 * later sweep retries. Returns how many were released.
 */
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
    // Claim-once: the same row the P2 sweep / a return reversal also competes for.
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
  /** P5: the reversal couldn't pull funds back (already settled) — flagged. */
  flagged: boolean;
  /**
   * PR-M2: rupee gap between the customer refund the caller asked us to claw
   * back and the seller slice we could actually reverse (the held transfer).
   * Non-zero when the refund exceeds the recoverable seller slice — e.g. a
   * platform-funded coupon's value, or a slice already released/settled. The
   * platform absorbs this slice, so it is surfaced (flagged) for manual
   * recovery instead of silently vanishing. 0 when the refund fit the slice.
   */
  shortfall: number;
}

/**
 * Reverse up to `reverseAmount` (rupees) of the child's transfer on a return.
 * Partial-aware and capped at the remaining un-reversed amount, so repeated
 * partial returns sum correctly and a redelivered refund can't over-reverse.
 *
 * PR-M2: the caller passes the FULL tax-inclusive customer refund, which can
 * exceed the seller's held slice (platform-funded coupon, or a slice already
 * released). We reverse what we can and FLAG the uncovered gap as a shortfall
 * for manual recovery rather than silently succeeding on the capped amount.
 */
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
    // One transfer per child today (the @@unique invariant); deterministic anyway.
    orderBy: { id: 'asc' },
  });
  // No held transfer for this child → nothing was split through Route, so there
  // is no seller slice to claw back and no platform shortfall to recover.
  if (!t) return { reversed: false, flagged: false, shortfall: 0 };

  const amountMinor = toMinorUnits(Number(t.amount));
  const alreadyMinor = toMinorUnits(Number(t.reversedAmount));
  const remainingMinor = amountMinor - alreadyMinor;

  // PR-M2 — the caller asked us to claw back the full customer refund; the
  // most we can reverse is the seller's remaining held slice. The uncovered
  // gap (refund > slice) is funded by neither side automatically — flag it.
  const requestedMinor = toMinorUnits(input.reverseAmount);

  if (remainingMinor <= 0) {
    // Fully reversed already, yet the caller still wants more clawed back: the
    // entire requested amount is unrecoverable from this transfer — flag it.
    return flagShortfall(t.id, t.gatewayPaymentId, requestedMinor);
  }

  const reverseMinor = Math.min(requestedMinor, remainingMinor);
  if (reverseMinor <= 0) return { reversed: false, flagged: false, shortfall: 0 };

  // The slice the customer refund overshoots the seller's recoverable amount by.
  const shortfallMinor = Math.max(requestedMinor - remainingMinor, 0);

  const provider = await splitProviderFor(t.gatewayPaymentId);
  if (!provider) return { reversed: false, flagged: false, shortfall: 0 };

  const newReversedMinor = alreadyMinor + reverseMinor;
  const fullyReversed = newReversedMinor >= amountMinor;
  const targetStatus = fullyReversed ? 'REVERSED' : 'PARTIALLY_REVERSED';

  // Compare-and-set claim BEFORE the provider call: advance reversedAmount only
  // if no concurrent reversal changed it. The loser of a race (two sibling
  // returns of one child, or a refund racing the reconcile sweep) sees count 0
  // and bails WITHOUT calling the provider — so Razorpay is never double-reversed
  // and reversedAmount can't be lost-updated.
  const claim = await prisma.gatewayTransfer.updateMany({
    where: { id: t.id, status: { in: ACTIVE }, reversedAmount: t.reversedAmount },
    data: {
      reversedAmount: new Prisma.Decimal(fromMinorUnits(newReversedMinor)),
      status: targetStatus,
      ...(fullyReversed ? { reversedAt: new Date() } : {}),
    },
  });
  if (claim.count !== 1) return { reversed: false, flagged: false, shortfall: 0 }; // lost the race

  try {
    await provider.reverseTransfer(t.providerTransferRef!, reverseMinor);
    // Reversed the seller slice. If the customer refund exceeded that slice,
    // the uncovered remainder is a platform shortfall — record + flag it so it
    // surfaces for manual recovery instead of silently vanishing.
    if (shortfallMinor > 0) {
      await recordShortfall(t.id, t.gatewayPaymentId, shortfallMinor);
      return { reversed: true, flagged: true, shortfall: fromMinorUnits(shortfallMinor) };
    }
    return { reversed: true, flagged: false, shortfall: 0 };
  } catch (err) {
    // The provider call failed — nothing actually moved. Roll the optimistic
    // claim back (only if we still own it) so reversedAmount reflects reality.
    await prisma.gatewayTransfer.updateMany({
      where: { id: t.id, reversedAmount: new Prisma.Decimal(fromMinorUnits(newReversedMinor)) },
      data: { reversedAmount: t.reversedAmount, status: t.status },
    });
    const status = (err as { status?: number }).status;
    // P5 — insufficient balance (seller already settled/withdrawn). Razorpay
    // usually returns 402; some balance errors come back 400, so check the
    // message too. Flag for manual recovery; the buyer's refund still proceeds.
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

/**
 * PR-M2 — persist a reverse-shortfall flag (the customer refund slice that
 * exceeded the seller's recoverable transfer) and emit a CRITICAL track so it
 * surfaces in reconciliation for manual recovery. Best-effort: never throws.
 */
async function recordShortfall(
  transferId: number,
  gatewayPaymentId: number,
  shortfallMinor: number,
): Promise<void> {
  try {
    await prisma.gatewayTransfer.update({
      where: { id: transferId },
      // Don't clobber an existing insufficient-balance flag.
      data: { failureReason: 'REVERSAL_SHORTFALL' },
    });
  } catch {
    /* flag is advisory; the track below is the durable signal */
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

/**
 * The held slice is already fully reversed but the caller still wants more
 * clawed back — the entire requested amount is a platform shortfall.
 */
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
