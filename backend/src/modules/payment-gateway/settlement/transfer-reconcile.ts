import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import {
  isSplitCapable,
  type ExistingTransfer,
  type PaymentGatewayPort,
  type SplitCapablePort,
} from '../ports/payment-provider.port.js';
import { executeHeldTransfers, isRouteSplitEnabled } from './order-split.js';
import { settlePosTransfer } from './pos-split.js';
import { toMinorUnits, fromMinorUnits } from '../helpers.js';
import { tracker } from '../tracker.js';
import type { GatewayPaymentRecord, SettlementTargetType } from '../ports/types.js';

const OPEN_RETURN_STATUSES = ['REQUESTED', 'APPROVED', 'PICKED_UP', 'RECEIVED'];

export interface TransferReconcileSummary {
  healPaymentsScanned: number;
  healed: { created: number; reconciled: number; failed: number };
  releasesScanned: number;
  released: number;
  deferredOpenReturn: number;
  verified: number;
  reReleased: number;
  autoReleased: number;
  reversalSynced: number;
  reversalMismatchFlagged: number;
  kycRetried: number;
  posReDriven: number;
  failedTransfers: number;
  errors: number;
}

type SplitProvider = PaymentGatewayPort & SplitCapablePort;

export async function reconcileStaleTransfers(opts?: {
  now?: Date;
  healAfterMs?: number;
  batchSize?: number;
}): Promise<TransferReconcileSummary> {
  const now = opts?.now ?? new Date();
  const healAfterMs = opts?.healAfterMs ?? 15 * 60_000;
  const batchSize = opts?.batchSize ?? 100;
  const healBefore = new Date(now.getTime() - healAfterMs);

  const summary: TransferReconcileSummary = {
    healPaymentsScanned: 0,
    healed: { created: 0, reconciled: 0, failed: 0 },
    releasesScanned: 0,
    released: 0,
    deferredOpenReturn: 0,
    verified: 0,
    reReleased: 0,
    autoReleased: 0,
    reversalSynced: 0,
    reversalMismatchFlagged: 0,
    kycRetried: 0,
    posReDriven: 0,
    failedTransfers: 0,
    errors: 0,
  };

  const stalePayments = await prisma.gatewayTransfer.findMany({
    where: { status: 'HELD', providerTransferRef: null, createdAt: { lt: healBefore } },
    select: { gatewayPaymentId: true },
    distinct: ['gatewayPaymentId'],
    take: batchSize,
  });
  summary.healPaymentsScanned = stalePayments.length;
  for (const { gatewayPaymentId } of stalePayments) {
    try {
      const r = await executeHeldTransfers(gatewayPaymentId);
      summary.healed.created += r.created;
      summary.healed.reconciled += r.reconciled;
      summary.healed.failed += r.failed;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: gatewayPaymentId,
        meta: { phase: 'reconcile-heal', error: errMsg(err) },
      });
    }
  }

  const dueHolds = await prisma.gatewayTransfer.findMany({
    where: {
      status: 'HELD',
      providerTransferRef: { not: null },
      holdUntil: { lt: now },
      purchaseRequest: { returns: { none: { status: { in: OPEN_RETURN_STATUSES } } } },
    },
    select: {
      id: true,
      gatewayPaymentId: true,
      purchaseRequestId: true,
      providerTransferRef: true,
    },
    orderBy: { holdUntil: 'asc' },
    take: batchSize,
  });
  summary.releasesScanned = dueHolds.length;

  const providerCache = new Map<number, SplitProvider | null>();
  for (const t of dueHolds) {
    try {
      const openReturn = await prisma.returnRequest.findFirst({
        where: { requestId: t.purchaseRequestId, status: { in: OPEN_RETURN_STATUSES } },
        select: { id: true },
      });
      if (openReturn) {
        summary.deferredOpenReturn++;
        continue;
      }

      const provider = await resolveSplitProvider(t.gatewayPaymentId, providerCache);
      if (!provider) continue;

      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: t.id, status: 'HELD' },
        data: { status: 'RELEASED', releasedAt: new Date() },
      });
      if (claim.count !== 1) continue;

      try {
        await provider.releaseTransfer(t.providerTransferRef!);
        summary.released++;
      } catch (relErr) {
        await prisma.gatewayTransfer.updateMany({
          where: { id: t.id, status: 'RELEASED' },
          data: { status: 'HELD', releasedAt: null },
        });
        throw relErr;
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: t.gatewayPaymentId,
        meta: { phase: 'reconcile-release', transferId: t.id, error: errMsg(err) },
      });
    }
  }

  await verifyAndSyncTransfers(summary, batchSize);

  await retryKycGatedTransfers(summary, batchSize);

  await reDrivePosTransfers(summary, batchSize, healBefore);

  summary.failedTransfers = await prisma.gatewayTransfer.count({ where: { status: 'FAILED' } });
  if (summary.failedTransfers > 0) {
    tracker.track({
      step: 'ROUTE_SPLIT_FAILED',
      meta: { phase: 'reconcile-dead-letter', failedTransfers: summary.failedTransfers, severity: 'CRITICAL' },
    });
  }

  tracker.track({ step: 'RECONCILE_SWEEP', meta: { scope: 'transfers', ...summary } });
  return summary;
}

async function resolveSplitProvider(
  gatewayPaymentId: number,
  cache: Map<number, SplitProvider | null>,
): Promise<SplitProvider | null> {
  const cached = cache.get(gatewayPaymentId);
  if (cached !== undefined) return cached;
  const pay = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true },
  });
  let resolved: SplitProvider | null = null;
  if (pay) {
    const p = getProvider(pay.provider);
    if (isSplitCapable(p)) resolved = p;
  }
  cache.set(gatewayPaymentId, resolved);
  return resolved;
}

async function resolvePaymentContext(
  gatewayPaymentId: number,
  cache: Map<number, { provider: SplitProvider; paymentRef: string } | null>,
): Promise<{ provider: SplitProvider; paymentRef: string } | null> {
  const cached = cache.get(gatewayPaymentId);
  if (cached !== undefined) return cached;
  const pay = await prisma.gatewayPayment.findUnique({
    where: { id: gatewayPaymentId },
    select: { provider: true, providerPaymentRef: true },
  });
  let ctx: { provider: SplitProvider; paymentRef: string } | null = null;
  if (pay?.providerPaymentRef) {
    const p = getProvider(pay.provider);
    if (isSplitCapable(p)) ctx = { provider: p, paymentRef: pay.providerPaymentRef };
  }
  cache.set(gatewayPaymentId, ctx);
  return ctx;
}

async function verifyAndSyncTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
): Promise<void> {
  const rows = await prisma.gatewayTransfer.findMany({
    where: {
      providerTransferRef: { not: null },
      status: { in: ['HELD', 'RELEASED', 'PARTIALLY_REVERSED'] },
    },
    select: {
      id: true,
      gatewayPaymentId: true,
      providerTransferRef: true,
      status: true,
      amount: true,
      reversedAmount: true,
    },
    orderBy: { id: 'asc' },
    take: batchSize,
  });
  if (rows.length === 0) return;

  const byPayment = new Map<number, typeof rows>();
  for (const r of rows) {
    const list = byPayment.get(r.gatewayPaymentId);
    if (list) list.push(r);
    else byPayment.set(r.gatewayPaymentId, [r]);
  }

  const ctxCache = new Map<number, { provider: SplitProvider; paymentRef: string } | null>();
  for (const [paymentId, group] of byPayment) {
    let byRef: Map<string, ExistingTransfer>;
    try {
      const ctx = await resolvePaymentContext(paymentId, ctxCache);
      if (!ctx) {
        tracker.track({
          step: 'ROUTE_SPLIT_FAILED',
          intentId: paymentId,
          meta: { phase: 'reconcile-verify-no-context', rows: group.length },
        });
        continue;
      }
      const existing = await ctx.provider.listTransfers(ctx.paymentRef);
      byRef = new Map(existing.map((e) => [e.transferRef, e]));
      for (const row of group) {
        try {
          const prov = byRef.get(row.providerTransferRef!);
          if (!prov) continue;
          summary.verified++;
          await reconcileRowAgainstProvider(row, prov, ctx.provider, summary);
        } catch (err) {
          summary.errors++;
          tracker.track({
            step: 'ROUTE_SPLIT_FAILED',
            intentId: paymentId,
            meta: { phase: 'reconcile-verify', transferId: row.id, error: errMsg(err) },
          });
        }
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: paymentId,
        meta: { phase: 'reconcile-verify-list', error: errMsg(err) },
      });
    }
  }
}

async function reconcileRowAgainstProvider(
  row: { id: number; status: string; amount: Prisma.Decimal; reversedAmount: Prisma.Decimal; providerTransferRef: string | null },
  prov: ExistingTransfer,
  provider: SplitProvider,
  summary: TransferReconcileSummary,
): Promise<void> {
  const amountMinor = toMinorUnits(Number(row.amount));
  const reversedMinor = prov.amountReversedMinor;

  if (prov.status === 'reversed' || reversedMinor >= amountMinor) {
    if (reversedMinor > amountMinor + 1) {
      summary.reversalMismatchFlagged++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        meta: {
          phase: 'reconcile-over-reversal',
          transferId: row.id,
          amountMinor,
          providerReversedMinor: reversedMinor,
          severity: 'CRITICAL',
        },
      });
    }
    if (row.status !== 'REVERSED') {
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: row.id, status: { not: 'REVERSED' } },
        data: {
          status: 'REVERSED',
          reversedAt: new Date(),
          reversedAmount: new Prisma.Decimal(fromMinorUnits(Math.min(reversedMinor, amountMinor))),
        },
      });
      if (claim.count === 1) summary.reversalSynced++;
    }
    return;
  }

  if (reversedMinor > 0) {
    const dbReversedMinor = toMinorUnits(Number(row.reversedAmount));
    if (reversedMinor < dbReversedMinor - 1) {
      summary.reversalMismatchFlagged++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        meta: {
          phase: 'reconcile-reversal-mismatch',
          transferId: row.id,
          dbReversedMinor,
          providerReversedMinor: reversedMinor,
          severity: 'CRITICAL',
        },
      });
      return;
    }
    const needsAmountSync = Math.abs(reversedMinor - dbReversedMinor) > 1;
    const needsStatus = row.status === 'HELD';
    if (needsAmountSync || needsStatus) {
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: row.id, status: { in: ['HELD', 'PARTIALLY_REVERSED'] } },
        data: {
          ...(needsAmountSync
            ? { reversedAmount: new Prisma.Decimal(fromMinorUnits(reversedMinor)) }
            : {}),
          ...(needsStatus ? { status: 'PARTIALLY_REVERSED' } : {}),
        },
      });
      if (claim.count === 1) summary.reversalSynced++;
    }
    return;
  }

  if (prov.onHold) {
    if (row.status === 'RELEASED') {
      await provider.releaseTransfer(row.providerTransferRef!);
      summary.reReleased++;
    }
    return;
  }
  if (row.status === 'HELD') {
    const claim = await prisma.gatewayTransfer.updateMany({
      where: { id: row.id, status: 'HELD' },
      data: { status: 'RELEASED', releasedAt: new Date() },
    });
    if (claim.count === 1) summary.autoReleased++;
  }
}

async function retryKycGatedTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
): Promise<void> {
  const gated = await prisma.gatewayTransfer.findMany({
    where: { status: 'KYC_GATED' },
    select: {
      id: true,
      gatewayPaymentId: true,
      purchaseRequest: {
        select: {
          shop: {
            select: {
              linkedAccount: {
                select: { id: true, providerAccountId: true, payoutsEnabled: true },
              },
            },
          },
        },
      },
    },
    take: batchSize,
  });
  if (gated.length === 0) return;

  const touchedPayments = new Set<number>();
  for (const g of gated) {
    try {
      const la = g.purchaseRequest.shop.linkedAccount;
      if (!la || !la.payoutsEnabled || !la.providerAccountId) continue;
      const claim = await prisma.gatewayTransfer.updateMany({
        where: { id: g.id, status: 'KYC_GATED' },
        data: {
          status: 'HELD',
          linkedAccountId: la.id,
          providerAccountId: la.providerAccountId,
          failureReason: null,
        },
      });
      if (claim.count === 1) {
        summary.kycRetried++;
        touchedPayments.add(g.gatewayPaymentId);
      }
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: g.gatewayPaymentId,
        meta: { phase: 'reconcile-kyc-retry', transferId: g.id, error: errMsg(err) },
      });
    }
  }

  for (const paymentId of touchedPayments) {
    try {
      const r = await executeHeldTransfers(paymentId);
      summary.healed.created += r.created;
      summary.healed.reconciled += r.reconciled;
      summary.healed.failed += r.failed;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: paymentId,
        meta: { phase: 'reconcile-kyc-execute', error: errMsg(err) },
      });
    }
  }
}

async function reDrivePosTransfers(
  summary: TransferReconcileSummary,
  batchSize: number,
  healBefore: Date,
): Promise<void> {
  if (!isRouteSplitEnabled()) return;

  const rows = await prisma.gatewayPayment.findMany({
    where: {
      status: 'CAPTURED',
      targetType: 'POS',
      providerPaymentRef: { not: null },
      shopId: { not: null },
      updatedAt: { lt: healBefore },
    },
    select: {
      id: true,
      provider: true,
      status: true,
      amount: true,
      currency: true,
      targetType: true,
      targetId: true,
      shopId: true,
      customerUserId: true,
      providerOrderRef: true,
      providerPaymentRef: true,
      amountRefunded: true,
      idempotencyKey: true,
      createdAt: true,
      updatedAt: true,
    },
    orderBy: { updatedAt: 'asc' },
    take: batchSize,
  });

  for (const row of rows) {
    const intent: GatewayPaymentRecord = {
      id: row.id,
      provider: row.provider,
      status: row.status as GatewayPaymentRecord['status'],
      amount: Number(row.amount),
      currency: row.currency,
      target: { type: row.targetType as SettlementTargetType, id: row.targetId },
      shopId: row.shopId,
      customerUserId: row.customerUserId,
      providerOrderRef: row.providerOrderRef,
      providerPaymentRef: row.providerPaymentRef,
      amountRefunded: Number(row.amountRefunded),
      idempotencyKey: row.idempotencyKey,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
    try {
      await settlePosTransfer(intent);
      summary.posReDriven++;
    } catch (err) {
      summary.errors++;
      tracker.track({
        step: 'ROUTE_SPLIT_FAILED',
        intentId: row.id,
        meta: { phase: 'reconcile-pos-redrive', error: errMsg(err) },
      });
    }
  }
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : 'unknown';
}
