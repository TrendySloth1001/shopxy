import type { Prisma } from '@prisma/client';

export interface OutboxInput {
  aggregateType: string;
  aggregateId: string | number;
  eventType: string;
  shopId?: number | null;
  payload: Prisma.InputJsonValue;
}

export interface OutboxEnvelope {
  id: bigint;
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  shopId: number | null;
  payload: Record<string, unknown>;
}

export type OutboxHandler = (event: OutboxEnvelope) => Promise<void>;
