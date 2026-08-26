import { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import { round2, toNumber } from '../../../shared/numbering/decimal.js';
import type {
  CreateIntentInput,
  GatewayPaymentRepository,
  GatewayRefundRepository,
  WebhookEventRepository,
} from '../ports/repository.port.js';
import type {
  GatewayPaymentRecord,
  GatewayPaymentStatus,
  GatewayRefundRecord,
  GatewayRefundStatus,
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
  amountRefunded: Prisma.Decimal;
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
    amountRefunded: toNumber(row.amountRefunded),
    idempotencyKey: row.idempotencyKey,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

type RefundRow = {
  id: number;
  gatewayPaymentId: number;
  provider: string;
  status: string;
  amount: Prisma.Decimal;
  currency: string;
  providerRefundRef: string | null;
  sourceType: string;
  sourceId: number;
  reason: string | null;
  idempotencyKey: string;
  createdAt: Date;
  updatedAt: Date;
};

function toRefundRecord(row: RefundRow): GatewayRefundRecord {
  return {
    id: row.id,
    gatewayPaymentId: row.gatewayPaymentId,
    provider: row.provider,
    status: row.status as GatewayRefundStatus,
    amount: toNumber(row.amount),
    currency: row.currency,
    providerRefundRef: row.providerRefundRef,
    sourceType: row.sourceType,
    sourceId: row.sourceId,
    reason: row.reason,
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
    const row = await prisma.gatewayPayment.findFirst({
      where: { customerUserId, idempotencyKey: key },
      orderBy: { id: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async detachIdempotencyKey(id: number): Promise<void> {
    await prisma.gatewayPayment.update({
      where: { id },
      data: { idempotencyKey: null },
    });
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

  async findCapturedByTarget(
    targetType: SettlementTargetType,
    targetId: number,
  ): Promise<GatewayPaymentRecord | null> {
    const row = await prisma.gatewayPayment.findFirst({
      where: { targetType, targetId, status: 'CAPTURED' },
      orderBy: { id: 'desc' },
    });
    return row ? toRecord(row) : null;
  }

  async reserveRefundable(
    id: number,
    requested: number,
    tx: Prisma.TransactionClient,
  ): Promise<{ granted: number; fullyRefunded: boolean }> {
    const locked = await tx.$queryRaw<Array<{ amount: string; amount_refunded: string }>>`
      SELECT amount, amount_refunded FROM gateway_payments WHERE id = ${id} FOR UPDATE
    `;
    const row = locked[0];
    if (!row) return { granted: 0, fullyRefunded: false };

    const amount = Number(row.amount);
    const alreadyRefunded = Number(row.amount_refunded);
    const granted = round2(Math.min(requested, round2(amount - alreadyRefunded)));
    if (!(granted > 0)) return { granted: 0, fullyRefunded: false };

    const fullyRefunded = round2(alreadyRefunded + granted) >= amount;
    await tx.gatewayPayment.update({
      where: { id },
      data: {
        amountRefunded: { increment: new Prisma.Decimal(granted) },
        ...(fullyRefunded ? { status: 'REFUNDED' } : {}),
      },
    });
    return { granted, fullyRefunded };
  }

  async releaseRefundable(
    id: number,
    amount: number,
    tx: Prisma.TransactionClient,
  ): Promise<void> {
    const locked = await tx.$queryRaw<Array<{ amount: string; amount_refunded: string }>>`
      SELECT amount, amount_refunded FROM gateway_payments WHERE id = ${id} FOR UPDATE
    `;
    const row = locked[0];
    if (!row) return;

    const remainingRefunded = round2(Number(row.amount_refunded) - amount);
    await tx.gatewayPayment.update({
      where: { id },
      data: {
        amountRefunded: { decrement: new Prisma.Decimal(amount) },
        status: remainingRefunded >= Number(row.amount) ? 'REFUNDED' : 'CAPTURED',
      },
    });
  }
}

class PrismaGatewayRefundRepository implements GatewayRefundRepository {
  async findByIdempotencyKey(key: string): Promise<GatewayRefundRecord | null> {
    const row = await prisma.gatewayRefund.findUnique({
      where: { idempotencyKey: key },
    });
    return row ? toRefundRecord(row) : null;
  }

  async findByProviderRef(
    provider: string,
    providerRefundRef: string,
  ): Promise<GatewayRefundRecord | null> {
    const row = await prisma.gatewayRefund.findFirst({
      where: { provider, providerRefundRef },
      orderBy: { id: 'desc' },
    });
    return row ? toRefundRecord(row) : null;
  }

  async findStaleForReconcile(input: {
    updatedBefore: Date;
    limit: number;
  }): Promise<GatewayRefundRecord[]> {
    const rows = await prisma.gatewayRefund.findMany({
      where: {
        status: { in: ['PENDING', 'FAILED'] },
        updatedAt: { lt: input.updatedBefore },
      },
      orderBy: { updatedAt: 'asc' },
      take: input.limit,
    });
    return rows.map(toRefundRecord);
  }

  async create(
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
  ): Promise<GatewayRefundRecord> {
    const db = tx ?? prisma;
    const row = await db.gatewayRefund.create({
      data: {
        gatewayPaymentId: input.gatewayPaymentId,
        provider: input.provider,
        amount: new Prisma.Decimal(input.amount),
        currency: input.currency,
        status: input.status,
        providerRefundRef: input.providerRefundRef,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        reason: input.reason,
        idempotencyKey: input.idempotencyKey,
      },
    });
    return toRefundRecord(row);
  }

  async update(
    id: number,
    data: { status?: GatewayRefundStatus; providerRefundRef?: string },
    tx?: Prisma.TransactionClient,
  ): Promise<void> {
    const db = tx ?? prisma;
    await db.gatewayRefund.update({
      where: { id },
      data: {
        ...(data.status !== undefined && { status: data.status }),
        ...(data.providerRefundRef !== undefined && {
          providerRefundRef: data.providerRefundRef,
        }),
      },
    });
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

  async release(provider: string, eventId: string): Promise<void> {
    await prisma.gatewayWebhookEvent.deleteMany({
      where: { provider, eventId, processedAt: null },
    });
  }
}

export const gatewayPaymentRepository: GatewayPaymentRepository =
  new PrismaGatewayPaymentRepository();
export const gatewayRefundRepository: GatewayRefundRepository =
  new PrismaGatewayRefundRepository();
export const webhookEventRepository: WebhookEventRepository =
  new PrismaWebhookEventRepository();
