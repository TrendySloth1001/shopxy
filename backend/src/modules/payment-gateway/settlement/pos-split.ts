import prisma from '../../../infra/db/prisma.js';
import { getProvider } from '../providers/registry.js';
import { isSplitCapable } from '../ports/payment-provider.port.js';
import { toMinorUnits } from '../helpers.js';
import { isRouteSplitEnabled } from './order-split.js';
import { tracker } from '../tracker.js';
import type { GatewayPaymentRecord } from '../ports/types.js';

const POS_NOTES_KEY = 'shopxy_pos_sale';

export async function settlePosTransfer(intent: GatewayPaymentRecord): Promise<void> {
  if (!isRouteSplitEnabled()) return;
  if (intent.shopId == null || !intent.providerPaymentRef) return;

  const la = await prisma.linkedAccount.findUnique({
    where: { shopId: intent.shopId },
    select: { providerAccountId: true, payoutsEnabled: true },
  });
  if (!la?.payoutsEnabled || !la.providerAccountId) return;

  const provider = getProvider(intent.provider);
  if (!isSplitCapable(provider)) return;

  const key = `pos:${intent.target.id}`;
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
