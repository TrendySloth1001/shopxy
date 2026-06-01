/**
 * Prisma-backed persistence for the gateway module. Maps DB rows ↔ the neutral
 * `GatewayPaymentRecord` so the core never sees a Prisma type. Amounts are
 * stored as Decimal(12,2) and surfaced as plain numbers (rupees).
 */
import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { toNumber } from '../../../shared/numbering/decimal.js';
import type {
  CreateIntentInput,
  GatewayPaymentRepository,
  WebhookEventRepository,
} from '../ports/repository.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  SettlementTargetType,
} from '../ports/types.js';

type Row = {
  id: number;
  provider: string;
  status: string;
  amount: Prisma.Decimal;
  currency: string;
  targetType: string;
  targetId: number;
  shopId: number | null;
  customerUserId: number | null;
  providerOrderRef: string | null;
  providerPaymentRef: string | null;
  idempotencyKey: string | null;
  createdAt: Date;
  updatedAt: Date;
};

function toRecord(row: Row): GatewayPaymentRecord {
  return {
    id: row.id,
    provider: row.provider,
    status: row.status as GatewayPaymentStatus,
    amount: toNumber(row.amount),
    currency: row.currency,
    target: { type: row.targetType as SettlementTargetType, id: row.targetId },
    shopId: row.shopId,
    customerUserId: row.customerUserId,
    providerOrderRef: row.providerOrderRef,
    providerPaymentRef: row.providerPaymentRef,
    idempotencyKey: row.idempotencyKey,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

class PrismaGatewayPaymentRepository implements GatewayPaymentRepository {
  async create(input: CreateIntentInput): Promise<GatewayPaymentRecord> {
    const row = await prisma.gatewayPayment.create({
      data: {
        provider: input.provider,
        amount: new Prisma.Decimal(input.amount),
        currency: input.currency,
        targetType: input.target.type,
        targetId: input.target.id,
        shopId: input.shopId,
        customerUserId: input.customerUserId,
        idempotencyKey: input.idempotencyKey,
      },
    });
    return toRecord(row);
  }

  async findById(id: number): Promise<GatewayPaymentRecord | null> {
    const row = await prisma.gatewayPayment.findUnique({ where: { id } });
    return row ? toRecord(row) : null;
  }

  async findByIdempotencyKey(
    customerUserId: number | null,
    key: string,
  ): Promise<GatewayPaymentRecord | null> {
    // findFirst (not findUnique): the composite unique includes a nullable
    // customerUserId, and Postgres treats NULLs as distinct — findFirst gives a
    // correct lookup for both the keyed-customer and (rare) null-customer cases.
    const row = await prisma.gatewayPayment.findFirst({
      where: { customerUserId, idempotencyKey: key },
      orderBy: { id: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async findByProviderOrderRef(
    provider: string,
    providerOrderRef: string,
  ): Promise<GatewayPaymentRecord | null> {
    const row = await prisma.gatewayPayment.findFirst({
      where: { provider, providerOrderRef },
      orderBy: { id: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async findByProviderPaymentRef(
    provider: string,
    providerPaymentRef: string,
  ): Promise<GatewayPaymentRecord | null> {
    const row = await prisma.gatewayPayment.findFirst({
      where: { provider, providerPaymentRef },
      orderBy: { id: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async findStaleOpenIntents(input: {
    createdBefore: Date;
    limit: number;
  }): Promise<GatewayPaymentRecord[]> {
    // Open = not yet terminal. CAPTURED/REFUNDED/FAILED need no re-check.
    // Oldest first so a backlog drains deterministically and the abandon
    // window is applied to the longest-waiting intents first.
    const rows = await prisma.gatewayPayment.findMany({
      where: {
        status: { in: ['CREATED', 'PENDING'] },
        createdAt: { lt: input.createdBefore },
      },
      orderBy: { createdAt: 'asc' },
      take: input.limit,
    });
    return rows.map(toRecord);
  }

  async attachProviderRefs(
    id: number,
    refs: { providerOrderRef?: string; providerPaymentRef?: string },
  ): Promise<void> {
    await prisma.gatewayPayment.update({
      where: { id },
      data: {
        ...(refs.providerOrderRef !== undefined && { providerOrderRef: refs.providerOrderRef }),
        ...(refs.providerPaymentRef !== undefined && {
          providerPaymentRef: refs.providerPaymentRef,
        }),
      },
    });
  }

  async updateStatus(
    id: number,
    status: GatewayPaymentStatus,
    tx?: Prisma.TransactionClient,
  ): Promise<void> {
    const db = tx ?? prisma;
    await db.gatewayPayment.update({ where: { id }, data: { status } });
  }
}

class PrismaWebhookEventRepository implements WebhookEventRepository {
  async claim(provider: string, eventId: string, payload: unknown): Promise<boolean> {
    try {
      await prisma.gatewayWebhookEvent.create({
        data: { provider, eventId, payload: payload as Prisma.InputJsonValue },
      });
      return true;
    } catch (e) {
      // Unique (provider, event_id) violation = already seen → not fresh.
      if ((e as { code?: string }).code === 'P2002') return false;
      throw e;
    }
  }

  async markProcessed(provider: string, eventId: string): Promise<void> {
    await prisma.gatewayWebhookEvent.updateMany({
      where: { provider, eventId },
      data: { processedAt: new Date() },
    });
  }
}

export const gatewayPaymentRepository: GatewayPaymentRepository =
  new PrismaGatewayPaymentRepository();
export const webhookEventRepository: WebhookEventRepository =
  new PrismaWebhookEventRepository();
