import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { enqueueOutbox } from '../../infra/outbox/outbox.js';
import { nextPaymentRef } from '../../shared/numbering/sequences.js';
import { toNumber } from '../../shared/numbering/decimal.js';

export type PaymentType = 'RECEIPT' | 'PAYMENT';
export type PaymentMode =
  | 'CASH'
  | 'UPI'
  | 'NEFT'
  | 'RTGS'
  | 'CHEQUE'
  | 'CARD'
  | 'OTHER';

export interface CreatePaymentInput {
  shopId: number;
  type: PaymentType;
  amount: number;
  mode: PaymentMode;
  modeReference?: string | null;
  paymentDate?: Date;
  partyId?: number | null;
  vendorId?: number | null;
  invoiceId?: number | null;
  note?: string | null;
  createdById?: number | null;
  idempotencyKey?: string | null;
}

export class PaymentsService {
  private round2(v: number): number {
    return Math.round((v + Number.EPSILON) * 100) / 100;
  }

  async createPayment(input: CreatePaymentInput) {
    const {
      shopId,
      type,
      amount,
      mode,
      modeReference,
      paymentDate,
      partyId,
      vendorId,
      invoiceId,
      note,
      createdById,
      idempotencyKey,
    } = input;

    if (idempotencyKey) {
      const replay = await prisma.payment.findFirst({
        where: { shopId, type, idempotencyKey },
        include: {
          party: { select: { id: true, name: true } },
          vendor: { select: { id: true, name: true } },
          invoice: {
            select: { id: true, invoiceNo: true, total: true, status: true },
          },
        },
      });
      if (replay) {
        const amountMatches =
          Math.abs(toNumber(replay.amount) - amount) <= 0.005;
        const partyMatches = (replay.partyId ?? null) === (partyId ?? null);
        const vendorMatches = (replay.vendorId ?? null) === (vendorId ?? null);
        const invoiceMatches =
          (replay.invoiceId ?? null) === (invoiceId ?? null);
        if (
          !amountMatches ||
          !partyMatches ||
          !vendorMatches ||
          !invoiceMatches
        ) {
          throw new Error(
            'IDEMPOTENCY_CONFLICT: payload differs from the original payment',
          );
        }
        return replay;
      }
    }

    if (type !== 'RECEIPT' && type !== 'PAYMENT') {
      throw new Error('Invalid payment type');
    }
    if (!(amount > 0)) {
      throw new Error('Amount must be positive');
    }
    const hasParty = partyId != null;
    const hasVendor = vendorId != null;
    if (hasParty === hasVendor) {
      throw new Error('Exactly one of partyId / vendorId must be set');
    }
    if (type === 'RECEIPT' && !hasParty) {
      throw new Error('RECEIPT payments must reference a party');
    }
    if (type === 'PAYMENT' && !hasVendor) {
      throw new Error('PAYMENT payments must reference a vendor');
    }

    if (hasParty) {
      const owns = await prisma.party.findFirst({
        where: { id: partyId!, shopId },
        select: { id: true },
      });
      if (!owns) throw new Error('Party not found');
    } else {
      const owns = await prisma.vendor.findFirst({
        where: { id: vendorId!, shopId },
        select: { id: true },
      });
      if (!owns) throw new Error('Vendor not found');
    }

    return prisma.$transaction(
      async (tx) => {
        if (invoiceId != null) {
          const invoice = await tx.invoice.findFirst({
            where: { id: invoiceId, shopId },
            select: {
              id: true,
              partyId: true,
              vendorId: true,
              total: true,
              type: true,
              status: true,
              documentType: true,
            },
          });
          if (!invoice) throw new Error('Invoice not found');
          if (
            invoice.documentType === 'ESTIMATE' ||
            invoice.documentType === 'PROFORMA' ||
            invoice.documentType === 'CREDIT_NOTE'
          ) {
            throw new Error(
              `Cannot record a payment against a ${invoice.documentType.toLowerCase().replace('_', ' ')}`,
            );
          }
          if (invoice.status !== 'CONFIRMED') {
            throw new Error('Cannot record a payment against a non-confirmed invoice');
          }
          if (type === 'RECEIPT' && invoice.type !== 'SALE') {
            throw new Error('Receipts can only be applied to sale invoices');
          }
          if (type === 'PAYMENT' && invoice.type !== 'PURCHASE') {
            throw new Error('Payments can only be applied to purchase invoices');
          }
          if (type === 'RECEIPT' && invoice.partyId !== partyId) {
            throw new Error('Invoice does not belong to this party');
          }
          if (type === 'PAYMENT' && invoice.vendorId !== vendorId) {
            throw new Error('Invoice does not belong to this vendor');
          }

          const allocated = await tx.payment.aggregate({
            where: { invoiceId, shopId, voidedAt: null },
            _sum: { amount: true },
          });
          const alreadyApplied = toNumber(allocated._sum.amount);
          const outstanding = this.round2(toNumber(invoice.total) - alreadyApplied);
          if (this.round2(amount - outstanding) > 0) {
            throw new Error(
              `Amount exceeds outstanding (${outstanding.toFixed(2)}) on invoice`,
            );
          }
        }

        const { referenceNo } = await nextPaymentRef(
          shopId,
          type,
          paymentDate ?? new Date(),
          tx,
        );
        const payment = await tx.payment.create({
          data: {
            shopId,
            type,
            referenceNo,
            amount: new Prisma.Decimal(amount),
            mode,
            modeReference: modeReference ?? null,
            paymentDate: paymentDate ?? new Date(),
            partyId: partyId ?? null,
            vendorId: vendorId ?? null,
            invoiceId: invoiceId ?? null,
            note: note ?? null,
            createdById: createdById ?? null,
            idempotencyKey: idempotencyKey ?? null,
          },
          include: {
            party: { select: { id: true, name: true } },
            vendor: { select: { id: true, name: true } },
            invoice: {
              select: { id: true, invoiceNo: true, total: true, status: true },
            },
          },
        });
        await enqueueOutbox(
          {
            aggregateType: 'payment',
            aggregateId: payment.id,
            eventType: 'payment.recorded',
            shopId,
            payload: { paymentId: payment.id, occurredAt: payment.paymentDate.toISOString() },
          },
          tx,
        );
        return payment;
      },
      { isolationLevel: 'Serializable' },
    );
  }

  async recordReceiptInTx(
    tx: Prisma.TransactionClient,
    input: {
      shopId: number;
      amount: number;
      mode: string;
      modeReference?: string | null;
      invoiceId: number;
      partyId?: number | null;
      createdById?: number | null;
      idempotencyKey?: string | null;
    },
  ) {
    const { referenceNo } = await nextPaymentRef(input.shopId, 'RECEIPT', new Date(), tx);
    const payment = await tx.payment.create({
      data: {
        shopId: input.shopId,
        type: 'RECEIPT',
        referenceNo,
        amount: new Prisma.Decimal(input.amount),
        mode: input.mode,
        modeReference: input.modeReference ?? null,
        paymentDate: new Date(),
        partyId: input.partyId ?? null,
        vendorId: null,
        invoiceId: input.invoiceId,
        createdById: input.createdById ?? null,
        idempotencyKey: input.idempotencyKey ?? null,
      },
    });
    await enqueueOutbox(
      {
        aggregateType: 'payment',
        aggregateId: payment.id,
        eventType: 'payment.recorded',
        shopId: input.shopId,
        payload: { paymentId: payment.id, occurredAt: payment.paymentDate.toISOString() },
      },
      tx,
    );
    return payment;
  }

  async listPayments(
    shopId: number,
    options: {
      partyId?: number | null;
      vendorId?: number | null;
      invoiceId?: number | null;
      page: number;
      limit: number;
      skip: number;
    },
  ) {
    const where: Prisma.PaymentWhereInput = { shopId, voidedAt: null };
    if (options.partyId != null) where.partyId = options.partyId;
    if (options.vendorId != null) where.vendorId = options.vendorId;
    if (options.invoiceId != null) where.invoiceId = options.invoiceId;

    const [payments, total] = await Promise.all([
      prisma.payment.findMany({
        where,
        orderBy: [{ paymentDate: 'desc' }, { id: 'desc' }],
        skip: options.skip,
        take: options.limit,
        include: {
          party: { select: { id: true, name: true } },
          vendor: { select: { id: true, name: true } },
          invoice: { select: { id: true, invoiceNo: true } },
        },
      }),
      prisma.payment.count({ where }),
    ]);

    return { payments, total };
  }

  async getPaymentById(shopId: number, id: number) {
    return prisma.payment.findFirst({
      where: { id, shopId },
      include: {
        party: { select: { id: true, name: true } },
        vendor: { select: { id: true, name: true } },
        invoice: {
          select: { id: true, invoiceNo: true, total: true, status: true },
        },
      },
    });
  }

  async voidPayment(
    shopId: number,
    id: number,
    voidedById?: number | null,
    reason?: string | null,
    opts?: { allowPlatformCollected?: boolean },
  ): Promise<boolean | 'PLATFORM_COLLECTED'> {
    const owned = await prisma.payment.findFirst({
      where: { id, shopId },
      select: {
        id: true,
        type: true,
        mode: true,
        modeReference: true,
        idempotencyKey: true,
        voidedAt: true,
        paymentDate: true,
      },
    });
    if (!owned) return false;
    if (owned.voidedAt) return true;

    if (owned.type === 'RECEIPT' && !opts?.allowPlatformCollected) {
      const key = owned.idempotencyKey ?? '';
      const isOrderReconciled =
        owned.mode === 'OTHER' &&
        (key.startsWith('wltrcpt:') || key.startsWith('gwrcpt:'));

      let backedByCapture = false;
      if (!isOrderReconciled && owned.modeReference) {
        const capture = await prisma.gatewayPayment.findFirst({
          where: {
            shopId,
            status: 'CAPTURED',
            providerPaymentRef: owned.modeReference,
          },
          select: { id: true },
        });
        backedByCapture = capture != null;
      }

      if (isOrderReconciled || backedByCapture) {
        return 'PLATFORM_COLLECTED';
      }
    }

    const voidData = {
      voidedAt: new Date(),
      voidedById: voidedById ?? null,
      voidReason: reason ?? null,
    };

    await prisma.$transaction(async (tx) => {
      await tx.payment.update({ where: { id }, data: voidData });
      await enqueueOutbox(
        {
          aggregateType: 'payment',
          aggregateId: id,
          eventType: 'payment.voided',
          shopId,
          payload: { paymentId: id, occurredAt: owned.paymentDate.toISOString() },
        },
        tx,
      );
    });
    return true;
  }

  async partyLedger(shopId: number, partyId: number) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: {
        id: true,
        name: true,
        contactName: true,
        phone: true,
        email: true,
        gstin: true,
        isActive: true,
      },
    });
    if (!party) return null;

    const [invoices, payments] = await Promise.all([
      prisma.invoice.findMany({
        where: {
          partyId,
          shopId,
          type: 'SALE',
          status: 'CONFIRMED',
          documentType: { notIn: ['ESTIMATE', 'PROFORMA'] },
        },
        orderBy: [{ invoiceDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          invoiceNo: true,
          invoiceDate: true,
          total: true,
          status: true,
          documentType: true,
        },
      }),
      prisma.payment.findMany({
        where: { partyId, shopId, type: 'RECEIPT', voidedAt: null },
        orderBy: [{ paymentDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          referenceNo: true,
          amount: true,
          mode: true,
          modeReference: true,
          paymentDate: true,
          note: true,
          invoiceId: true,
        },
      }),
    ]);

    type Entry =
      | {
          kind: 'invoice';
          id: number;
          date: Date;
          label: string;
          debit: number;
          credit: number;
          runningBalance: number;
          documentType?: string;
          status?: string;
        }
      | {
          kind: 'payment';
          id: number;
          date: Date;
          label: string;
          debit: number;
          credit: number;
          runningBalance: number;
          mode?: string;
          modeReference?: string | null;
          note?: string | null;
          invoiceId?: number | null;
        };

    const merged: Array<{
      kind: 'invoice' | 'payment';
      date: Date;
      id: number;
      payload:
        | (typeof invoices)[number]
        | (typeof payments)[number];
    }> = [
      ...invoices.map((i) => ({
        kind: 'invoice' as const,
        date: i.invoiceDate,
        id: i.id,
        payload: i,
      })),
      ...payments.map((p) => ({
        kind: 'payment' as const,
        date: p.paymentDate,
        id: p.id,
        payload: p,
      })),
    ].sort((a, b) => {
      const cmp = a.date.getTime() - b.date.getTime();
      if (cmp !== 0) return cmp;
      if (a.kind !== b.kind) return a.kind === 'invoice' ? -1 : 1;
      return a.id - b.id;
    });

    let running = 0;
    const entries: Entry[] = merged.map((row) => {
      if (row.kind === 'invoice') {
        const inv = row.payload as (typeof invoices)[number];
        const amount = toNumber(inv.total);
        const isCreditNote = inv.documentType === 'CREDIT_NOTE';
        const debit = isCreditNote ? 0 : amount;
        const credit = isCreditNote ? amount : 0;
        running = this.round2(running + debit - credit);
        return {
          kind: 'invoice',
          id: inv.id,
          date: inv.invoiceDate,
          label: inv.invoiceNo,
          debit,
          credit,
          runningBalance: running,
          documentType: inv.documentType,
          status: inv.status,
        };
      }
      const pay = row.payload as (typeof payments)[number];
      const credit = toNumber(pay.amount);
      running = this.round2(running - credit);
      return {
        kind: 'payment',
        id: pay.id,
        date: pay.paymentDate,
        label: pay.referenceNo,
        debit: 0,
        credit,
        runningBalance: running,
        mode: pay.mode,
        modeReference: pay.modeReference,
        note: pay.note,
        invoiceId: pay.invoiceId,
      };
    });

    return {
      party,
      openingBalance: 0,
      balance: this.round2(running),
      entries,
    };
  }

  async vendorLedger(shopId: number, vendorId: number) {
    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, shopId },
      select: {
        id: true,
        name: true,
        contactName: true,
        phone: true,
        email: true,
        gstin: true,
        isActive: true,
      },
    });
    if (!vendor) return null;

    const [invoices, payments] = await Promise.all([
      prisma.invoice.findMany({
        where: {
          vendorId,
          shopId,
          type: 'PURCHASE',
          status: 'CONFIRMED',
          documentType: { notIn: ['ESTIMATE', 'PROFORMA'] },
        },
        orderBy: [{ invoiceDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          invoiceNo: true,
          invoiceDate: true,
          total: true,
          status: true,
          documentType: true,
        },
      }),
      prisma.payment.findMany({
        where: { vendorId, shopId, type: 'PAYMENT', voidedAt: null },
        orderBy: [{ paymentDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          referenceNo: true,
          amount: true,
          mode: true,
          modeReference: true,
          paymentDate: true,
          note: true,
          invoiceId: true,
        },
      }),
    ]);

    type Entry =
      | {
          kind: 'invoice';
          id: number;
          date: Date;
          label: string;
          debit: number;
          credit: number;
          runningBalance: number;
          documentType?: string;
          status?: string;
        }
      | {
          kind: 'payment';
          id: number;
          date: Date;
          label: string;
          debit: number;
          credit: number;
          runningBalance: number;
          mode?: string;
          modeReference?: string | null;
          note?: string | null;
          invoiceId?: number | null;
        };

    const merged = [
      ...invoices.map((i) => ({
        kind: 'invoice' as const,
        date: i.invoiceDate,
        id: i.id,
        payload: i,
      })),
      ...payments.map((p) => ({
        kind: 'payment' as const,
        date: p.paymentDate,
        id: p.id,
        payload: p,
      })),
    ].sort((a, b) => {
      const cmp = a.date.getTime() - b.date.getTime();
      if (cmp !== 0) return cmp;
      if (a.kind !== b.kind) return a.kind === 'invoice' ? -1 : 1;
      return a.id - b.id;
    });

    let running = 0;
    const entries: Entry[] = merged.map((row) => {
      if (row.kind === 'invoice') {
        const inv = row.payload as (typeof invoices)[number];
        const amount = toNumber(inv.total);
        const isCreditNote = inv.documentType === 'CREDIT_NOTE';
        const debit = isCreditNote ? 0 : amount;
        const credit = isCreditNote ? amount : 0;
        running = this.round2(running + debit - credit);
        return {
          kind: 'invoice',
          id: inv.id,
          date: inv.invoiceDate,
          label: inv.invoiceNo,
          debit,
          credit,
          runningBalance: running,
          documentType: inv.documentType,
          status: inv.status,
        };
      }
      const pay = row.payload as (typeof payments)[number];
      const credit = toNumber(pay.amount);
      running = this.round2(running - credit);
      return {
        kind: 'payment',
        id: pay.id,
        date: pay.paymentDate,
        label: pay.referenceNo,
        debit: 0,
        credit,
        runningBalance: running,
        mode: pay.mode,
        modeReference: pay.modeReference,
        note: pay.note,
        invoiceId: pay.invoiceId,
      };
    });

    return {
      vendor,
      openingBalance: 0,
      balance: this.round2(running),
      entries,
    };
  }
}

export const paymentsService = new PaymentsService();
