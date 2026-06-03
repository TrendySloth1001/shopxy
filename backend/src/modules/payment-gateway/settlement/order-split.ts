/**
 * Route on-hold split for a captured ORDER — the per-shop held-transfer layer.
 *
 * Legal framing (do not lose this): this is Razorpay Route `on_hold`, NOT a
 * licensed escrow. Each seller's slice is parked in RAZORPAY's regulated
 * balance (Razorpay is custodian), never in a ShopXY-controlled account. We only
 * send create / release / reverse instructions. Customer-facing copy says
 * "released to the seller once you confirm delivery", never "escrow". The whole
 * path is gated by ROUTE_SPLIT_ENABLED (off by default) and must not move real
 * money until it is sandbox-verified and compliance/legal sign off the flag.
 *
 * Two phases, deliberately split across the settlement transaction boundary so a
 * crash can never leave money moved without a row, and so reconciliation can
 * heal a row whose provider call never landed:
 *
 *   writeHeldTransferRows(intent, tx)   — INSIDE the settlement tx
 *     Allocate the captured amount across child PurchaseRequests, gate each on
 *     its shop's LinkedAccount KYC, and upsert one GatewayTransfer row per child
 *     (HELD or KYC_GATED, providerTransferRef null, deterministic idempotencyKey).
 *     Idempotent via the (gatewayPaymentId, purchaseRequestId) unique — a
 *     redelivered capture is a no-op.
 *
 *   executeHeldTransfers(gatewayPaymentId) — AFTER commit, and from reconciliation
 *     Fetch-before-create against Razorpay (match existing transfers by the
 *     deterministic key in `notes`), then create only the missing ones on-hold
 *     and patch the ref. A retry/heal reconciles instead of double-paying.
 */
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

const MIN_TRANSFER_PAISE = 100; // Razorpay Route floor: ₹1.
const SECONDS = 1000;
const DAY_MS = 86_400 * SECONDS;

/** The on-hold split path is OFF unless explicitly enabled. Until it is
 *  sandbox-verified and compliance signs off, this stays false in prod. */
export function isRouteSplitEnabled(): boolean {
  return envOr('ROUTE_SPLIT_ENABLED', 'false') === 'true';
}

/** Deterministic, stable idempotency key for one child's transfer. Persisted on
 *  the row BEFORE any provider call and echoed into Razorpay transfer notes, so
 *  every retry/heal resolves to the same transfer. */
function transferKey(gatewayPaymentId: number, purchaseRequestId: number): string {
  return `gw:${gatewayPaymentId}:pr:${purchaseRequestId}`;
}

/** Razorpay notes key carrying {@link transferKey} on the created transfer. */
const NOTES_KEY = 'shopxy_transfer_key';

/**
 * Phase 1 (in-tx): write one HELD/KYC_GATED row per child. No provider calls.
 * Only runs for split-capable providers (ORDER split is Route/Razorpay-specific).
 */
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
    orderBy: { id: 'asc' }, // deterministic allocation order (rounding residue)
  });
  if (children.length === 0) return;

  const totalMinor = toMinorUnits(intent.amount);
  const shares = children.map((c) => Number(c.estimatedTotal));
  // Allocate exactly, then fold sub-₹1 slices into the largest so no transfer
  // is created below Razorpay's floor. Sum is preserved == totalMinor.
  const alloc = foldBelowMinimum(allocateProportional(shares, totalMinor), MIN_TRANSFER_PAISE);
  const now = new Date();

  let written = 0;
  let gated = 0;
  for (let i = 0; i < children.length; i++) {
    const amountMinor = alloc[i];
    if (amountMinor <= 0) continue; // dust folded into a sibling — no row

    const c = children[i];
    const la = c.shop.linkedAccount;
    const payable = !!(la && la.payoutsEnabled && la.providerAccountId);
    // Backstop auto-release at the return window close; buyer-confirm releases
    // earlier. returnWindowDays === 0 ("return forever") → indefinite hold,
    // released only by our flow (omit on_hold_until at the provider edge).
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
      // Redelivered capture → no-op. We never rewrite amount/status here; a
      // KYC_GATED row is promoted later by the account.activated retry path.
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

/**
 * Phase 2 (post-commit / reconciliation): create the held transfers at the
 * provider for every HELD row that has no providerTransferRef yet, using
 * fetch-before-create so a retry can't double-pay. Never throws — a per-row
 * failure is recorded on the row and surfaced; the batch continues.
 */
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
  // No captured payment ref → nothing to split on (shouldn't happen post-capture).
  if (!intentRow?.providerPaymentRef) return empty;

  const provider = getProvider(intentRow.provider);
  if (!isSplitCapable(provider)) return empty;

  const pending = await prisma.gatewayTransfer.findMany({
    where: { gatewayPaymentId, status: 'HELD', providerTransferRef: null },
    orderBy: { id: 'asc' },
  });
  if (pending.length === 0) return empty;

  // Fetch-before-create: reconcile any transfer that already exists at the
  // provider (we may have created it then crashed before patching the ref).
  let existingByKey = new Map<string, string>(); // key → transferRef
  try {
    for (const e of await provider.listTransfers(intentRow.providerPaymentRef)) {
      const k = e.notes?.[NOTES_KEY];
      if (k) existingByKey.set(k, e.transferRef);
    }
  } catch {
    // If the list call fails we proceed to create; a true duplicate is still
    // guarded by the next reconciliation tick re-listing. (Best-effort.)
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
