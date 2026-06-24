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
  GatewayRefundRecord,
  GatewayRefundStatus,
  SettlementTarget,
  SettlementTargetType,
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
  /**
   * Release an intent's idempotency key (sets it NULL) so a fresh intent can
   * be minted under the same (customer, key). Used when a still-open intent
   * outlives the idempotency window — the stale row is retired, not reused.
   */
  detachIdempotencyKey(id: number): Promise<void>;
  updateStatus(
    id: number,
    status: GatewayPaymentStatus,
    tx?: Prisma.TransactionClient,
  ): Promise<void>;
  /**
   * Refund engine: the CAPTURED online payment that settles a given domain
   * target (ORDER → CustomerOrder id, POS → Sale id…). This is what we reverse
   * money against. Returns null when the target was paid by COD / wallet /
   * never captured online — the caller then knows there is nothing to refund to
   * source. Most-recent CAPTURED row wins if (impossibly) more than one exists.
   */
  findCapturedByTarget(
    targetType: SettlementTargetType,
    targetId: number,
  ): Promise<GatewayPaymentRecord | null>;
  /**
   * Atomically add `amount` (rupees) to the capture's amount_refunded and, when
   * the capture is now fully reversed, flip its status to REFUNDED. Runs inside
   * the refund-recording tx so the cap and the child refund row commit together.
   */
  addRefundedAmount(
    id: number,
    amount: number,
    markFullyRefunded: boolean,
    tx?: Prisma.TransactionClient,
  ): Promise<void>;
  /**
   * Release a reservation: subtract `amount` from amount_refunded and set the
   * capture's status (REFUNDED if still fully reversed by other refunds, else
   * CAPTURED). Used when a refund that had reserved the cap (a PENDING row)
   * later turns out to have FAILED at the provider, so the reserved amount must
   * not stay consumed (which would under-refund a future return on the order).
   */
  releaseRefundedAmount(
    id: number,
    amount: number,
    stillFullyRefunded: boolean,
    tx?: Prisma.TransactionClient,
  ): Promise<void>;
}

/** Persistence for real-money refunds-to-source (the `GatewayRefund` table). */
export interface GatewayRefundRepository {
  /** Idempotent replay lookup — the refund already issued for this trigger. */
  findByIdempotencyKey(key: string): Promise<GatewayRefundRecord | null>;
  /** webhook (refund.processed/failed) → resolve the row to transition. */
  findByProviderRef(
    provider: string,
    providerRefundRef: string,
  ): Promise<GatewayRefundRecord | null>;
  /**
   * Reconciliation sweep source: non-terminal refunds (PENDING — webhook may
   * have been missed; FAILED — needs a re-drive) last touched before
   * `updatedBefore`, oldest first, capped at `limit`. The scheduled refund
   * sweep heals these so a refund the law requires always eventually settles.
   */
  findStaleForReconcile(input: {
    updatedBefore: Date;
    limit: number;
  }): Promise<GatewayRefundRecord[]>;
  create(
    input: {
      gatewayPaymentId: number;
      provider: string;
      amount: number;
      currency: string;
      status: GatewayRefundStatus;
      providerRefundRef: string | null;
      sourceType: string;
      sourceId: number;
      reason: string | null;
      idempotencyKey: string;
    },
    tx?: Prisma.TransactionClient,
  ): Promise<GatewayRefundRecord>;
  update(
    id: number,
    data: { status?: GatewayRefundStatus; providerRefundRef?: string },
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
