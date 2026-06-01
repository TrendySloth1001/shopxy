/**
 * Persistence ports. The core service depends on these interfaces, never on
 * Prisma directly — so it compiles and is testable before the `GatewayPayment`
 * / `GatewayWebhookEvent` tables exist, and so persistence can be swapped or
 * mocked. The Prisma-backed implementation lives in
 * ../persistence/prisma-gateway.repository.ts (a stub until the migration lands).
 */
import type { Prisma } from '@prisma/client';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  SettlementTarget,
} from './types.js';

export interface CreateIntentInput {
  provider: string;
  amount: number;
  currency: string;
  target: SettlementTarget;
  shopId: number | null;
  customerUserId: number | null;
  idempotencyKey: string | null;
}

export interface GatewayPaymentRepository {
  create(input: CreateIntentInput): Promise<GatewayPaymentRecord>;
  findById(id: number): Promise<GatewayPaymentRecord | null>;
  /** Replay lookup: an intent already created with this (customer, key). */
  findByIdempotencyKey(
    customerUserId: number | null,
    key: string,
  ): Promise<GatewayPaymentRecord | null>;
  /** Webhook → intent resolution. */
  findByProviderOrderRef(
    provider: string,
    providerOrderRef: string,
  ): Promise<GatewayPaymentRecord | null>;
  /** Fallback webhook → intent resolution when only a payment ref is present. */
  findByProviderPaymentRef(
    provider: string,
    providerPaymentRef: string,
  ): Promise<GatewayPaymentRecord | null>;
  /**
   * Reconciliation sweep source: still-open intents (CREATED|PENDING) created
   * before `createdBefore`, oldest first, capped at `limit`. The scheduled
   * intent-reconciliation job re-checks these against the provider to heal
   * missed webhooks (→ CAPTURED) and retire abandoned checkouts (→ FAILED).
   */
  findStaleOpenIntents(input: {
    createdBefore: Date;
    limit: number;
  }): Promise<GatewayPaymentRecord[]>;
  attachProviderRefs(
    id: number,
    refs: { providerOrderRef?: string; providerPaymentRef?: string },
  ): Promise<void>;
  updateStatus(
    id: number,
    status: GatewayPaymentStatus,
    tx?: Prisma.TransactionClient,
  ): Promise<void>;
}

export interface WebhookEventRepository {
  /**
   * Atomically record (provider, eventId). Returns false if it was already
   * recorded — the dedupe gate that makes webhook processing exactly-once.
   * Backed by the unique (provider, event_id) index on GatewayWebhookEvent.
   */
  claim(provider: string, eventId: string, payload: unknown): Promise<boolean>;
  markProcessed(provider: string, eventId: string): Promise<void>;
}
