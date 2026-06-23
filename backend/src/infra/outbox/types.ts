import type { Prisma } from '@prisma/client';

/// The shape a producer hands to `enqueueOutbox`. `aggregateId` is accepted as
/// number or string (ids are ints today) and stored as text so the log stays
/// polymorphic across aggregate types.
export interface OutboxInput {
  aggregateType: string;
  aggregateId: string | number;
  eventType: string;
  shopId?: number | null;
  payload: Prisma.InputJsonValue;
}

/// What a handler receives off the log. `id` is a bigint (BIGSERIAL) — never
/// surfaced to clients, only used by the relay for bookkeeping.
export interface OutboxEnvelope {
  id: bigint;
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  shopId: number | null;
  payload: Record<string, unknown>;
}

/// A consumer of one event type. Throwing signals failure: the relay applies
/// backoff and retries, escalating to terminal FAILED after maxAttempts. A
/// handler MUST therefore be idempotent — it can run more than once for the
/// same event (at-least-once delivery).
export type OutboxHandler = (event: OutboxEnvelope) => Promise<void>;
