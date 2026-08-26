import type { Prisma } from '@prisma/client';
import prisma from '../db/prisma.js';
import type { OutboxInput } from './types.js';

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
