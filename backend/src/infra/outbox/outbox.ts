import type { Prisma } from '@prisma/client';
import prisma from '../db/prisma.js';
import type { OutboxInput } from './types.js';

/// Record a domain event on the transactional outbox.
///
/// Pass the surrounding `tx` so the event row is written in the SAME atomic
/// unit as the business change — that atomicity is the whole point: there can
/// be no confirmed invoice without its `invoice.confirmed` event, and no event
/// without the confirm. Mirrors the `db = tx ?? prisma` convention used across
/// the numbering/ledger helpers. Calling without a `tx` (autocommit) is allowed
/// but only correct when there is no business write to be atomic with.
///
/// Cheap by design — a single INSERT. It can only fail if the transaction is
/// already failing (DB down / connection lost), in which case rolling the
/// business write back is exactly what we want.
export async function enqueueOutbox(
  event: OutboxInput,
  tx?: Prisma.TransactionClient,
): Promise<void> {
  const db = tx ?? prisma;
  await db.outboxEvent.create({
    data: {
      aggregateType: event.aggregateType,
      aggregateId: String(event.aggregateId),
      eventType: event.eventType,
      shopId: event.shopId ?? null,
      payload: event.payload,
    },
    select: { id: true },
  });
}
