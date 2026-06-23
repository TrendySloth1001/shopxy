import { recomputeDay } from '../../modules/analytics-rollup/aggregates.recompute.js';
import { logger } from '../../shared/logging/logger.js';
import type { OutboxEnvelope, OutboxHandler } from './types.js';

/// Event-type → handlers registry. Handlers register themselves at import time
/// (side effects below); the relay imports this module, so wiring happens once
/// at boot. A new derived consumer is added by calling `onOutbox` here — it does
/// NOT touch any producer or the write path.
const registry = new Map<string, OutboxHandler[]>();

export function onOutbox(eventType: string, handler: OutboxHandler): void {
  const list = registry.get(eventType) ?? [];
  list.push(handler);
  registry.set(eventType, list);
}

export function handlersFor(eventType: string): OutboxHandler[] {
  return registry.get(eventType) ?? [];
}

// ── Derived read model: analytics roll-ups ────────────────────────────────
//
// Recompute the (shop, day) bucket the instant an invoice's money-affecting
// status changes, instead of waiting for the per-minute polling changefeed.
// `recomputeDay` is a delete-then-insert, so running it here AND from the
// changefeed/nightly reconcile is safe (idempotent) — that overlap is the
// belt-and-braces that lets a dropped or failed event self-heal.

/// IST is a fixed UTC+5:30 offset (no DST). Returns the UTC-midnight Date of the
/// IST calendar day containing `ts` — exactly the value the changefeed builds
/// from `to_char(date_trunc('day', ... AT TIME ZONE 'Asia/Kolkata'))`, so both
/// paths bucket identically. See [[project_analytics_rollups_jun2026]].
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function istDayMidnightUtc(ts: Date): Date {
  const ist = new Date(ts.getTime() + IST_OFFSET_MS);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

/// Every money-affecting event carries `shopId` + an `occurredAt` business
/// timestamp, and the roll-up only needs those two to know which (shop, day)
/// bucket to rebuild — so one handler serves every producer. `occurredAt` is
/// the date the change should be ATTRIBUTED to, which the producer chooses:
/// the invoice/credit-note date, the payment date, the adjustment date, or —
/// for a return — the ORIGINAL sale's date (returned COGS is booked against the
/// day it was sold, matching the changefeed's join).
async function recomputeDayFromEvent(event: OutboxEnvelope): Promise<void> {
  const { shopId } = event;
  const occurredAt = event.payload.occurredAt;
  if (shopId == null || typeof occurredAt !== 'string') {
    // Malformed event — log and let it mark PUBLISHED (the nightly reconcile
    // is the backstop). Throwing would only retry a permanently-bad row.
    logger.warn(
      { id: Number(event.id), eventType: event.eventType },
      'outbox: event missing shopId/occurredAt — skipping roll-up',
    );
    return;
  }
  await recomputeDay(shopId, istDayMidnightUtc(new Date(occurredAt)));
}

// The full set of source changes the analytics roll-up depends on — the same
// surface the polling changefeed watches (invoices, payments, stock
// adjustments, refunded returns), now event-driven.
onOutbox('invoice.confirmed', recomputeDayFromEvent);
onOutbox('invoice.cancelled', recomputeDayFromEvent);
onOutbox('payment.recorded', recomputeDayFromEvent);
onOutbox('payment.voided', recomputeDayFromEvent);
onOutbox('stock.adjusted', recomputeDayFromEvent);
onOutbox('return.refunded', recomputeDayFromEvent);
