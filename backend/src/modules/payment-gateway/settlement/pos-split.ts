/**
 * Route settlement for a captured POS UPI-QR sale.
 *
 * A POS sale is single-merchant, so there's no proportional split — exactly one
 * Route transfer per sale, for the full captured amount, to the shop's linked
 * account. Unlike the ORDER split this is NOT on-hold (in-store money settles
 * immediately) and there is no hold/release/reverse lifecycle.
 *
 * Same legal framing as order-split.ts: this is Razorpay Route, never escrow.
 *
 * Gating (two independent checks, both must pass to move money):
 *   - ROUTE_SPLIT_ENABLED — the global kill-switch. While off, the captured QR
 *     funds simply stay in the platform account and the sale is still fully
 *     recorded; the merchant just isn't routed to yet. Protects live keys until
 *     the Route flow is sandbox-verified and signed off.
 *   - the shop's LinkedAccount.payoutsEnabled — the QR tender is only OFFERED
 *     when this is true (pos.payments), but we re-check here at settlement time.
 *
 * Idempotent via fetch-before-create: a redelivered webhook or a reconcile heal
 * matches the existing transfer by the deterministic key stamped into Razorpay
 * transfer notes, so the merchant is never paid twice for one sale.
 */
import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import { isSplitCapable } from '../ports/payment-provider.port.js';
import { toMinorUnits } from '../helpers.js';
import { isRouteSplitEnabled } from './order-split.js';
import { tracker } from '../tracker.js';
import type { GatewayPaymentRecord } from '../ports/types.js';

/** Razorpay notes key carrying the per-sale idempotency token on the transfer. */
const POS_NOTES_KEY = 'shopxy_pos_sale';

export async function settlePosTransfer(intent: GatewayPaymentRecord): Promise<void> {
  if (!isRouteSplitEnabled()) return; // platform-collect until the flag is set
  if (intent.shopId == null || !intent.providerPaymentRef) return;

  const la = await prisma.linkedAccount.findUnique({
    where: { shopId: intent.shopId },
    select: { providerAccountId: true, payoutsEnabled: true },
  });
  if (!la?.payoutsEnabled || !la.providerAccountId) return; // not settle-able yet

  const provider = getProvider(intent.provider);
  if (!isSplitCapable(provider)) return;

  const key = `pos:${intent.target.id}`;
  // Fetch-before-create: never mint a second transfer for the same sale.
  try {
    const existing = await provider.listTransfers(intent.providerPaymentRef);
    if (existing.some((e) => e.notes?.[POS_NOTES_KEY] === key)) {
      tracker.track({
        step: 'ROUTE_SPLIT_RECONCILED',
        provider: intent.provider,
        intentId: intent.id,
        meta: { pos: key, reason: 'transfer already exists' },
      });
      return;
    }
  } catch {
    // List failed — fall through to create; a true duplicate is caught by the
    // next reconcile re-list. (Best-effort, same discipline as executeHeldTransfers.)
  }

  await provider.createTransfers(intent.providerPaymentRef, [
    {
      destinationAccount: la.providerAccountId,
      amountMinor: toMinorUnits(intent.amount),
      onHold: false,
      notes: {
        [POS_NOTES_KEY]: key,
        gateway_payment_id: String(intent.id),
        app: 'shopxy',
      },
    },
  ]);
  tracker.track({
    step: 'ROUTE_SPLIT_EXECUTED',
    provider: intent.provider,
    intentId: intent.id,
    meta: { pos: key },
  });
}
