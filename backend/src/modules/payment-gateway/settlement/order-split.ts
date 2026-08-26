import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import { isSplitCapable } from '../ports/payment-provider.port.js';
import {
  allocateProportional,
  foldBelowMinimum,
  toMinorUnits,
  fromMinorUnits,
} from '../helpers.js';
import { envOr } from '../../../shared/env.js';
import { tracker } from '../tracker.js';
import type { GatewayPaymentRecord } from '../ports/types.js';

const MIN_TRANSFER_PAISE = 100;
const SECONDS = 1000;
const DAY_MS = 86_400 * SECONDS;

export function isRouteSplitEnabled(): boolean {
  return envOr('ROUTE_SPLIT_ENABLED', 'false') === 'true';
}

function transferKey(gatewayPaymentId: number, purchaseRequestId: number): string {
  return `gw:${gatewayPaymentId}:pr:${purchaseRequestId}`;
}

const NOTES_KEY = 'shopxy_transfer_key';

export async function writeHeldTransferRows(
  intent: GatewayPaymentRecord,
  tx: Prisma.TransactionClient,
): Promise<void> {
  if (!isSplitCapable(getProvider(intent.provider))) return;

  const children = await tx.purchaseRequest.findMany({
    where: { customerOrderId: intent.target.id },
    select: {
      id: true,
      estimatedTotal: true,
      shop: {
        select: {
          returnWindowDays: true,
          linkedAccount: {
            select: { id: true, providerAccountId: true, payoutsEnabled: true },
          },
        },
      },
    },
    orderBy: { id: 'asc' },
  });
  if (children.length === 0) return;

  const totalMinor = toMinorUnits(intent.amount);
  const shares = children.map((c) => Number(c.estimatedTotal));
  const alloc = foldBelowMinimum(allocateProportional(shares, totalMinor), MIN_TRANSFER_PAISE);
  const now = new Date();

  let written = 0;
  let gated = 0;
  for (let i = 0; i < children.length; i++) {
    const amountMinor = alloc[i];
    if (amountMinor <= 0) continue;

    const c = children[i];
    const la = c.shop.linkedAccount;
    const payable = !!(la && la.payoutsEnabled && la.providerAccountId);
    const holdUntil =
      c.shop.returnWindowDays > 0
        ? new Date(now.getTime() + c.shop.returnWindowDays * DAY_MS)
        : null;

    await tx.gatewayTransfer.upsert({
      where: {
        gateway_transfers_payment_request: {
          gatewayPaymentId: intent.id,
          purchaseRequestId: c.id,
        },
      },
      create: {
        gatewayPaymentId: intent.id,
        purchaseRequestId: c.id,
        linkedAccountId: payable ? la!.id : null,
        providerAccountId: payable ? la!.providerAccountId : null,
        amount: new Prisma.Decimal(fromMinorUnits(amountMinor)),
        idempotencyKey: transferKey(intent.id, c.id),
        status: payable ? 'HELD' : 'KYC_GATED',
        holdUntil,
        failureReason: payable ? null : 'KYC_NOT_ACTIVATED',
      },
      update: {},
    });
    payable ? written++ : gated++;
  }
  tracker.track({
    step: 'ROUTE_SPLIT_ROWS',
    provider: intent.provider,
    intentId: intent.id,
    meta: { children: children.length, held: written, kycGated: gated },
  });
}

export interface ExecuteSummary {
  created: number;
  reconciled: number;
  failed: number;
}

export async function executeHeldTransfers(gatewayPaymentId: number): Promise<ExecuteSummary> {
  const empty: ExecuteSummary = { created: 0, reconciled: 0, failed: 0 };
  const intentRow = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true, providerPaymentRef: true },
  });
  if (!intentRow?.providerPaymentRef) return empty;

  const provider = getProvider(intentRow.provider);
  if (!isSplitCapable(provider)) return empty;

  const pending = await prisma.gatewayTransfer.findMany({
    where: { gatewayPaymentId, status: 'HELD', providerTransferRef: null },
    orderBy: { id: 'asc' },
  });
  if (pending.length === 0) return empty;

  let existingByKey = new Map<string, string>();
  try {
    for (const e of await provider.listTransfers(intentRow.providerPaymentRef)) {
      const k = e.notes?.[NOTES_KEY];
      if (k) existingByKey.set(k, e.transferRef);
    }
  } catch {
    existingByKey = new Map();
  }

  let created = 0;
  let reconciled = 0;
  let failed = 0;
  for (const row of pending) {
    const already = existingByKey.get(row.idempotencyKey);
    if (already) {
      await prisma.gatewayTransfer.update({
        where: { id: row.id },
        data: { providerTransferRef: already },
      });
      reconciled++;
      continue;
    }
    try {
      const [res] = await provider.createTransfers(intentRow.providerPaymentRef, [
        {
          destinationAccount: row.providerAccountId!,
          amountMinor: toMinorUnits(Number(row.amount)),
          onHold: true,
          onHoldUntil: row.holdUntil
            ? Math.floor(row.holdUntil.getTime() / SECONDS)
            : undefined,
          notes: {
            [NOTES_KEY]: row.idempotencyKey,
            gateway_payment_id: String(gatewayPaymentId),
            purchase_request_id: String(row.purchaseRequestId),
          },
        },
      ]);
      await prisma.gatewayTransfer.update({
        where: { id: row.id },
        data: { providerTransferRef: res.transferRef },
      });
      created++;
    } catch (err) {
      const e = err as { message?: string };
      await prisma.gatewayTransfer.update({
        where: { id: row.id },
        data: { status: 'FAILED', failureReason: (e.message ?? 'TRANSFER_FAILED').slice(0, 180) },
      });
      failed++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: gatewayPaymentId,
        meta: { purchaseRequestId: row.purchaseRequestId, error: e.message },
      });
    }
  }
  tracker.track({
    step: reconciled > 0 ? 'ROUTE_SPLIT_RECONCILED' : 'ROUTE_SPLIT_EXECUTED',
    intentId: gatewayPaymentId,
    meta: { created, reconciled, failed, pending: pending.length },
  });
  return { created, reconciled, failed };
}
