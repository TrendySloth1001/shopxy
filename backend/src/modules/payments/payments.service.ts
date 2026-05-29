import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
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
  | 'OTHER'
  // System-only: set on the Payment created by a caution set-off.
  | 'CAUTION';

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
  /// Client-supplied retry-safe key. Unique per (shopId, type, key).
  /// When set, a replay returns the original row instead of inserting.
  idempotencyKey?: string | null;
}

/// Decimal helper — Prisma returns Decimal, the front-end wants double.
export class PaymentsService {
  /// Create a payment row, atomically allocating the next reference
  /// number. Caller passes the merchant's userId in `createdById` so we
  /// can attribute the row.
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

    // Idempotency replay: if this (shop, type, key) tuple already
    // exists, validate the caller's other params match the row we'd
    // return — without that check, a bug or attacker could reuse a
    // key with a different amount/party/invoice and silently get the
    // original row back, masking the mismatch.
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
    // Exactly one of partyId / vendorId is set, matching the `type`.
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

    // Validate the counterparty belongs to this shop. Without this an
    // authenticated merchant could `POST /payments` with another shop's
    // partyId/vendorId — the row would be inserted with their own
    // shopId, silently falsifying the attacker's ledger and reports.
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

    // Invoice over-allocation must be race-safe: two concurrent
    // payments both reading `alreadyApplied` before either insert lets
    // an invoice be paid down twice. We solve it by doing the aggregate
    // check + insert inside a single transaction at Serializable
    // isolation. The DB rejects one of the racing transactions with
    // SQLSTATE 40001, which Prisma surfaces and we re-throw as the
    // user-facing over-allocation error.
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
            },
          });
          if (!invoice) throw new Error('Invoice not found');
          if (type === 'RECEIPT' && invoice.partyId !== partyId) {
            throw new Error('Invoice does not belong to this party');
          }
          if (type === 'PAYMENT' && invoice.vendorId !== vendorId) {
            throw new Error('Invoice does not belong to this vendor');
          }

          const allocated = await tx.payment.aggregate({
            where: { invoiceId, shopId },
            _sum: { amount: true },
          });
          const alreadyApplied = toNumber(allocated._sum.amount);
          const outstanding = toNumber(invoice.total) - alreadyApplied;
          if (amount - outstanding > 0.001) {
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
        return tx.payment.create({
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
      },
      { isolationLevel: 'Serializable' },
    );
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
    const where: Prisma.PaymentWhereInput = { shopId };
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

  /// Hard delete — keeps schema simple. Audit history lives in the
  /// `note` field on the response so callers can show "Deleted by …"
  /// snackbars without an extra column. (Tradeoff: no recovery.)
  async deletePayment(shopId: number, id: number) {
    const owned = await prisma.payment.findFirst({
      where: { id, shopId },
      select: { id: true, mode: true },
    });
    if (!owned) return false;

    // A mode='CAUTION' payment is a caution set-off with a matching ADJUSTMENT
    // CautionTxn that dropped the caution balance. The CautionTxn→Payment link
    // is onDelete:SetNull, so deleting the payment alone would leave the
    // ADJUSTMENT in place (caution balance stays spent) while the invoice's
    // outstanding silently reopens. Reverse both atomically. The ADJUSTMENT
    // must go first, while paymentId still points at the payment.
    if (owned.mode === 'CAUTION') {
      await prisma.$transaction(async (tx) => {
        await tx.cautionTxn.deleteMany({
          where: { shopId, paymentId: id, type: 'ADJUSTMENT' },
        });
        await tx.payment.delete({ where: { id } });
      });
      return true;
    }

    await prisma.payment.delete({ where: { id } });
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
        where: { partyId, shopId, type: 'SALE', status: 'CONFIRMED' },
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
        where: { partyId, shopId, type: 'RECEIPT' },
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

    // Interleave invoices and payments into a single timeline. The
    // running balance is recomputed in one pass so debit/credit columns
    // line up with the displayed total.
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
      // Stable secondary sort on (kind, id) — invoices before payments on
      // the same instant so a same-day receipt nets against its bill.
      if (a.kind !== b.kind) return a.kind === 'invoice' ? -1 : 1;
      return a.id - b.id;
    });

    let running = 0;
    const entries: Entry[] = merged.map((row) => {
      if (row.kind === 'invoice') {
        const inv = row.payload as (typeof invoices)[number];
        const debit = toNumber(inv.total);
        running += debit;
        return {
          kind: 'invoice',
          id: inv.id,
          date: inv.invoiceDate,
          label: inv.invoiceNo,
          debit,
          credit: 0,
          runningBalance: running,
          documentType: inv.documentType,
          status: inv.status,
        };
      }
      const pay = row.payload as (typeof payments)[number];
      const credit = toNumber(pay.amount);
      running -= credit;
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
      balance: running,
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
        where: { vendorId, shopId, type: 'PURCHASE', status: 'CONFIRMED' },
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
        where: { vendorId, shopId, type: 'PAYMENT' },
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
        const debit = toNumber(inv.total);
        running += debit;
        return {
          kind: 'invoice',
          id: inv.id,
          date: inv.invoiceDate,
          label: inv.invoiceNo,
          debit,
          credit: 0,
          runningBalance: running,
          documentType: inv.documentType,
          status: inv.status,
        };
      }
      const pay = row.payload as (typeof payments)[number];
      const credit = toNumber(pay.amount);
      running -= credit;
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
      balance: running,
      entries,
    };
  }
}

export const paymentsService = new PaymentsService();
