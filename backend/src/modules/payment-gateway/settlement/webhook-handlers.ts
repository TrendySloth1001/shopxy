import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { toMinorUnits, fromMinorUnits } from '../helpers.js';
import { mapProviderKyc } from '../kyc-status.js';
import { reverseTransferForReturn } from './transfer-actions.js';
import { tracker } from '../tracker.js';
import type { GatewayEventType, NormalizedEvent } from '../ports/types.js';

const SETTLEMENT_EVENT_TYPES = new Set<GatewayEventType>([
  'TRANSFER_PROCESSED',
  'TRANSFER_FAILED',
  'TRANSFER_REVERSED',
  'ACCOUNT_UPDATED',
  'DISPUTE_LOST',
  'DISPUTE_OTHER',
]);

export function isSettlementEvent(type: GatewayEventType): boolean {
  return SETTLEMENT_EVENT_TYPES.has(type);
}

export async function ownsSettlementEvent(event: NormalizedEvent): Promise<boolean> {
  if (event.transfer) {
    return (
      (await prisma.gatewayTransfer.count({
        where: { providerTransferRef: event.transfer.ref },
      })) > 0
    );
  }
  if (event.account) {
    return (
      (await prisma.linkedAccount.count({
        where: { providerAccountId: event.account.ref },
      })) > 0
    );
  }
  if (event.dispute?.providerPaymentRef) {
    return (
      (await prisma.gatewayPayment.count({
        where: { providerPaymentRef: event.dispute.providerPaymentRef },
      })) > 0
    );
  }
  return false;
}

export async function handleSettlementEvent(event: NormalizedEvent): Promise<void> {
  switch (event.type) {
    case 'TRANSFER_PROCESSED':
      return handleTransferProcessed(event);
    case 'TRANSFER_FAILED':
      return handleTransferFailed(event);
    case 'TRANSFER_REVERSED':
      return handleTransferReversed(event);
    case 'ACCOUNT_UPDATED':
      return handleAccountUpdated(event);
    case 'DISPUTE_LOST':
      return handleDisputeLost(event);
    default:
      return;
  }
}

async function handleTransferProcessed(event: NormalizedEvent): Promise<void> {
  const ref = event.transfer!.ref;
  await prisma.gatewayTransfer.updateMany({
    where: { providerTransferRef: ref, status: { in: ['HELD', 'RELEASED'] } },
    data: { status: 'RELEASED', releasedAt: new Date() },
  });
  tracker.track({ step: 'ROUTE_SPLIT_EXECUTED', meta: { phase: 'webhook-transfer-processed', transferRef: ref } });
}

async function handleTransferFailed(event: NormalizedEvent): Promise<void> {
  const ref = event.transfer!.ref;
  await prisma.gatewayTransfer.updateMany({
    where: { providerTransferRef: ref, status: { in: ['HELD', 'RELEASED'] } },
    data: { status: 'FAILED', failureReason: 'TRANSFER_FAILED_WEBHOOK' },
  });
  tracker.track({
    step: 'ROUTE_SPLIT_FAILED',
    meta: { phase: 'webhook-transfer-failed', transferRef: ref, severity: 'CRITICAL' },
  });
}

async function handleTransferReversed(event: NormalizedEvent): Promise<void> {
  const ref = event.transfer!.ref;
  const reversedMinor = event.transfer!.amountReversedMinor;
  const row = await prisma.gatewayTransfer.findFirst({
    where: { providerTransferRef: ref },
    select: { id: true, amount: true, reversedAmount: true },
  });
  if (!row) return;
  const amountMinor = toMinorUnits(Number(row.amount));
  const dbReversedMinor = toMinorUnits(Number(row.reversedAmount));
  if (reversedMinor <= dbReversedMinor + 1) return;
  const fully = reversedMinor >= amountMinor;
  await prisma.gatewayTransfer.updateMany({
    where: { id: row.id, status: { in: ['HELD', 'PARTIALLY_REVERSED', 'RELEASED'] } },
    data: {
      reversedAmount: new Prisma.Decimal(fromMinorUnits(Math.min(reversedMinor, amountMinor))),
      status: fully ? 'REVERSED' : 'PARTIALLY_REVERSED',
      ...(fully ? { reversedAt: new Date() } : {}),
    },
  });
  tracker.track({
    step: 'ROUTE_SPLIT_RECONCILED',
    meta: { phase: 'webhook-transfer-reversed', transferRef: ref, reversedMinor },
  });
}

async function handleAccountUpdated(event: NormalizedEvent): Promise<void> {
  const ref = event.account!.ref;
  const status = event.account!.status;
  const { kycStatus, payoutsEnabled } = mapProviderKyc(status);
  await prisma.linkedAccount.updateMany({
    where: { providerAccountId: ref },
    data: { kycStatus, payoutsEnabled },
  });
  tracker.track({ step: 'ROUTE_SPLIT_EXECUTED', meta: { phase: 'webhook-account', accountRef: ref, status } });
}

async function handleDisputeLost(event: NormalizedEvent): Promise<void> {
  const payRef = event.dispute?.providerPaymentRef;
  if (!payRef) return;
  const intent = await prisma.gatewayPayment.findFirst({
    where: { providerPaymentRef: payRef },
    select: { id: true },
  });
  if (!intent) return;
  const transfers = await prisma.gatewayTransfer.findMany({
    where: {
      gatewayPaymentId: intent.id,
      status: { in: ['HELD', 'PARTIALLY_REVERSED', 'RELEASED'] },
      providerTransferRef: { not: null },
    },
    select: { purchaseRequestId: true, amount: true, reversedAmount: true },
  });
  for (const t of transfers) {
    const remaining = Number(t.amount) - Number(t.reversedAmount);
    if (remaining <= 0) continue;
    try {
      await reverseTransferForReturn({ purchaseRequestId: t.purchaseRequestId, reverseAmount: remaining });
    } catch (err) {
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        meta: {
          phase: 'dispute-lost-reverse',
          purchaseRequestId: t.purchaseRequestId,
          error: err instanceof Error ? err.message : 'unknown',
        },
      });
    }
  }
  tracker.track({
    step: 'ROUTE_SPLIT_RECONCILED',
    meta: { phase: 'dispute-lost', paymentRef: payRef, transfers: transfers.length, severity: 'CRITICAL' },
  });
}
