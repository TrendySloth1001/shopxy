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
  findByIdempotencyKey(
    customerUserId: number | null,
    key: string,
  ): Promise<GatewayPaymentRecord | null>;
  findByProviderOrderRef(
    provider: string,
    providerOrderRef: string,
  ): Promise<GatewayPaymentRecord | null>;
  findByProviderPaymentRef(
    provider: string,
    providerPaymentRef: string,
  ): Promise<GatewayPaymentRecord | null>;
  findStaleOpenIntents(input: {
    createdBefore: Date;
    limit: number;
  }): Promise<GatewayPaymentRecord[]>;
  attachProviderRefs(
    id: number,
    refs: { providerOrderRef?: string; providerPaymentRef?: string },
  ): Promise<void>;
  detachIdempotencyKey(id: number): Promise<void>;
  updateStatus(
    id: number,
    status: GatewayPaymentStatus,
    tx?: Prisma.TransactionClient,
  ): Promise<void>;
  findCapturedByTarget(
    targetType: SettlementTargetType,
    targetId: number,
  ): Promise<GatewayPaymentRecord | null>;
  reserveRefundable(
    id: number,
    requested: number,
    tx: Prisma.TransactionClient,
  ): Promise<{ granted: number; fullyRefunded: boolean }>;
  releaseRefundable(
    id: number,
    amount: number,
    tx: Prisma.TransactionClient,
  ): Promise<void>;
}

export interface GatewayRefundRepository {
  findByIdempotencyKey(key: string): Promise<GatewayRefundRecord | null>;
  findByProviderRef(
    provider: string,
    providerRefundRef: string,
  ): Promise<GatewayRefundRecord | null>;
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
  claim(provider: string, eventId: string, payload: unknown): Promise<boolean>;
  markProcessed(provider: string, eventId: string): Promise<void>;
  release(provider: string, eventId: string): Promise<void>;
}
