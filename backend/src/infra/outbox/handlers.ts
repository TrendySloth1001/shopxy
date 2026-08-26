import { recomputeDay } from '../../modules/analytics-rollup/aggregates.recompute.js';
import { logger } from '../../shared/logging/logger.js';
import type { OutboxEnvelope, OutboxHandler } from './types.js';

const registry = new Map<string, OutboxHandler[]>();

export function onOutbox(eventType: string, handler: OutboxHandler): void {
  const list = registry.get(eventType) ?? [];
  list.push(handler);
  registry.set(eventType, list);
}

export function handlersFor(eventType: string): OutboxHandler[] {
  return registry.get(eventType) ?? [];
}

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function istDayMidnightUtc(ts: Date): Date {
  const ist = new Date(ts.getTime() + IST_OFFSET_MS);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

async function recomputeDayFromEvent(event: OutboxEnvelope): Promise<void> {
  const { shopId } = event;
  const occurredAt = event.payload.occurredAt;
  if (shopId == null || typeof occurredAt !== 'string') {
    logger.warn(
      { id: Number(event.id), eventType: event.eventType },
      'outbox: event missing shopId/occurredAt — skipping roll-up',
    );
    return;
  }
  await recomputeDay(shopId, istDayMidnightUtc(new Date(occurredAt)));
}

onOutbox('invoice.confirmed', recomputeDayFromEvent);
onOutbox('invoice.cancelled', recomputeDayFromEvent);
onOutbox('payment.recorded', recomputeDayFromEvent);
onOutbox('payment.voided', recomputeDayFromEvent);
onOutbox('stock.adjusted', recomputeDayFromEvent);
onOutbox('return.refunded', recomputeDayFromEvent);
