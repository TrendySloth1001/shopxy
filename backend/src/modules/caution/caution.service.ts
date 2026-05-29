import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { nextPaymentRef, nextCautionRef } from '../../shared/numbering/sequences.js';
import { toNumber } from '../../shared/numbering/decimal.js';
import { HttpError } from '../../shared/http/errorHandler.js';

export type CautionTxnType = 'DEPOSIT' | 'REFUND' | 'ADJUSTMENT' | 'FORFEIT';
/// FORFEIT only: 'NONE' = pure default penalty (no GST) | 'SUPPLY' =
/// cancelled supply (GST at the goods rate). See Circular 178/2022.
export type CautionForfeitGst = 'NONE' | 'SUPPLY';
export type CautionMode =
  | 'CASH'
  | 'UPI'
  | 'NEFT'
  | 'RTGS'
  | 'CHEQUE'
  | 'CARD'
  | 'OTHER';

/// Caution / security deposit ledger, scoped per shop. A deposit is a
/// liability the shop owes back to the party, so it lives in its own table
/// rather than the revenue-bearing `payments`. A set-off ("adjust") is the
/// one place the two meet: it spends caution by creating a `mode='CAUTION'`
/// Payment against an invoice so the invoice's computed outstanding
/// (total − SUM(payments)) drops, and records a matching ADJUSTMENT row.
///
///   balance = SUM(DEPOSIT) − SUM(REFUND) − SUM(ADJUSTMENT)   per (shop, party)
export class CautionService {
  /// Signed balance held against a party. Computed from the three txn types
  /// in a single grouped aggregate.
  async balance(shopId: number, partyId: number): Promise<number> {
    const grouped = await prisma.cautionTxn.groupBy({
      by: ['type'],
      where: { shopId, partyId },
      _sum: { amount: true },
    });
    let bal = 0;
    for (const row of grouped) {
      const sum = toNumber(row._sum.amount);
      bal += row.type === 'DEPOSIT' ? sum : -sum;
    }
    return bal;
  }

  /// Live balance computed inside a transaction client, so a cap check and the
  /// txn that depends on it can't be split by a concurrent writer.
  private async balanceInTx(
    tx: Prisma.TransactionClient,
    shopId: number,
    partyId: number,
  ): Promise<number> {
    const grouped = await tx.cautionTxn.groupBy({
      by: ['type'],
      where: { shopId, partyId },
      _sum: { amount: true },
    });
    let bal = 0;
    for (const row of grouped) {
      bal += (row.type === 'DEPOSIT' ? 1 : -1) * toNumber(row._sum.amount);
    }
    return bal;
  }

  /// Balances for many parties at once (avoids an N+1 in the party list).
  /// Returns a Map keyed by partyId; absent parties have an implicit 0.
  async balancesFor(
    shopId: number,
    partyIds: number[],
  ): Promise<Map<number, number>> {
    const out = new Map<number, number>();
    if (partyIds.length === 0) return out;
    const grouped = await prisma.cautionTxn.groupBy({
      by: ['partyId', 'type'],
      where: { shopId, partyId: { in: partyIds } },
      _sum: { amount: true },
    });
    for (const row of grouped) {
      const signed =
        (row.type === 'DEPOSIT' ? 1 : -1) * toNumber(row._sum.amount);
      out.set(row.partyId, (out.get(row.partyId) ?? 0) + signed);
    }
    return out;
  }

  /// Paginated history (most recent first) plus the current balance.
  /// Returns null when the party is not in this shop.
  async history(
    shopId: number,
    partyId: number,
    opts: { skip: number; take: number },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { id: true, name: true },
    });
    if (!party) return null;

    const [rows, total, balance] = await Promise.all([
      prisma.cautionTxn.findMany({
        where: { shopId, partyId },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: opts.skip,
        take: opts.take,
        select: {
          id: true,
          type: true,
          amount: true,
          mode: true,
          modeReference: true,
          receiptNo: true,
          gstTreatment: true,
          note: true,
          createdAt: true,
          invoiceId: true,
          invoice: { select: { id: true, invoiceNo: true } },
        },
      }),
      prisma.cautionTxn.count({ where: { shopId, partyId } }),
      this.balance(shopId, partyId),
    ]);

    const entries = rows.map((r) => ({
      id: r.id,
      type: r.type as CautionTxnType,
      amount: toNumber(r.amount),
      mode: r.mode,
      modeReference: r.modeReference,
      receiptNo: r.receiptNo,
      gstTreatment: r.gstTreatment,
      note: r.note,
      createdAt: r.createdAt,
      invoiceId: r.invoiceId,
      invoiceNo: r.invoice?.invoiceNo ?? null,
    }));

    return { party, balance, entries, total };
  }

  /// Record money coming in (DEPOSIT) or going back out (REFUND). Refunds
  /// are capped at the live balance so a deposit can never be over-drawn.
  async record(
    shopId: number,
    partyId: number,
    input: {
      type: 'DEPOSIT' | 'REFUND';
      amount: number;
      mode: CautionMode;
      modeReference?: string | null;
      note?: string | null;
      createdById?: number | null;
    },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { id: true },
    });
    if (!party) return null;

    // Serializable so the refund cap check and the txn that consumes the
    // balance can't be interleaved with a concurrent refund/set-off — same
    // guarantee adjust() relies on. The receipt number is allocated inside
    // the txn so a rollback doesn't burn it.
    return prisma.$transaction(
      async (tx) => {
        const before = await this.balanceInTx(tx, shopId, partyId);
        if (input.type === 'REFUND' && input.amount - before > 0.001) {
          throw new HttpError(
            400,
            'CAUTION_REFUND_EXCEEDS_BALANCE',
            `Refund exceeds caution balance (${before.toFixed(2)})`,
          );
        }

        // Ordinary money-receipt number — a deposit/refund of a goods security
        // deposit attracts no GST, so this is a plain receipt, not a voucher.
        const receiptNo = await nextCautionRef(shopId, new Date(), tx);
        const txn = await tx.cautionTxn.create({
          data: {
            shopId,
            partyId,
            type: input.type,
            amount: new Prisma.Decimal(input.amount),
            mode: input.mode,
            modeReference: input.modeReference ?? null,
            receiptNo,
            note: input.note ?? null,
            createdById: input.createdById ?? null,
          },
        });
        const balance =
          input.type === 'DEPOSIT' ? before + input.amount : before - input.amount;
        return { txn, balance };
      },
      { isolationLevel: 'Serializable' },
    );
  }

  /// Forfeit (keep) part or all of a deposit on the party's default. Unlike
  /// a refund this money stays with the shop — and is **taxable business
  /// income** (Income Tax Sec 28/41), so it carries a `gstTreatment` flag for
  /// downstream reporting. It does NOT create a `Payment`: forfeiture income
  /// is not a customer payment against an invoice. Capped at the live balance.
  async forfeit(
    shopId: number,
    partyId: number,
    input: {
      amount: number;
      gstTreatment: CautionForfeitGst;
      note?: string | null;
      createdById?: number | null;
    },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { id: true },
    });
    if (!party) return null;

    // Serializable for the same reason as record()/adjust(): the cap check
    // and the txn that spends the balance must be one atomic step.
    return prisma.$transaction(
      async (tx) => {
        const before = await this.balanceInTx(tx, shopId, partyId);
        if (input.amount - before > 0.001) {
          throw new HttpError(
            400,
            'CAUTION_FORFEIT_EXCEEDS_BALANCE',
            `Forfeit exceeds caution balance (${before.toFixed(2)})`,
          );
        }

        const txn = await tx.cautionTxn.create({
          data: {
            shopId,
            partyId,
            type: 'FORFEIT',
            amount: new Prisma.Decimal(input.amount),
            gstTreatment: input.gstTreatment,
            note: input.note ?? null,
            createdById: input.createdById ?? null,
          },
        });
        return { txn, balance: before - input.amount };
      },
      { isolationLevel: 'Serializable' },
    );
  }

  /// Set off caution against an open invoice. Atomic + Serializable so two
  /// concurrent set-offs can't both spend the same balance or over-pay the
  /// invoice. Creates a `mode='CAUTION'` Payment (drops the invoice's
  /// outstanding) and a matching ADJUSTMENT txn (drops the caution balance).
  async adjust(
    shopId: number,
    partyId: number,
    input: { invoiceId: number; amount: number; note?: string | null; createdById?: number | null },
  ) {
    const party = await prisma.party.findFirst({
      where: { id: partyId, shopId },
      select: { id: true },
    });
    if (!party) return null;

    return prisma.$transaction(
      async (tx) => {
        const invoice = await tx.invoice.findFirst({
          where: { id: input.invoiceId, shopId },
          select: { id: true, partyId: true, total: true },
        });
        if (!invoice) {
          throw new HttpError(404, 'INVOICE_NOT_FOUND', 'Invoice not found');
        }
        if (invoice.partyId !== partyId) {
          throw new HttpError(
            400,
            'INVOICE_PARTY_MISMATCH',
            'Invoice does not belong to this party',
          );
        }

        // Live caution balance inside the txn.
        const balance = await this.balanceInTx(tx, shopId, partyId);
        if (input.amount - balance > 0.001) {
          throw new HttpError(
            400,
            'CAUTION_ADJUST_EXCEEDS_BALANCE',
            `Amount exceeds caution balance (${balance.toFixed(2)})`,
          );
        }

        // Live invoice outstanding (total − payments already applied).
        const allocated = await tx.payment.aggregate({
          where: { invoiceId: invoice.id, shopId },
          _sum: { amount: true },
        });
        const outstanding =
          toNumber(invoice.total) - toNumber(allocated._sum.amount);
        if (input.amount - outstanding > 0.001) {
          throw new HttpError(
            400,
            'CAUTION_ADJUST_EXCEEDS_OUTSTANDING',
            `Amount exceeds outstanding (${outstanding.toFixed(2)}) on invoice`,
          );
        }

        const { referenceNo } = await nextPaymentRef(
          shopId,
          'RECEIPT',
          new Date(),
          tx,
        );
        const payment = await tx.payment.create({
          data: {
            shopId,
            type: 'RECEIPT',
            referenceNo,
            amount: new Prisma.Decimal(input.amount),
            mode: 'CAUTION',
            paymentDate: new Date(),
            partyId,
            invoiceId: invoice.id,
            note: input.note ?? 'Caution set-off',
            createdById: input.createdById ?? null,
          },
        });

        const txn = await tx.cautionTxn.create({
          data: {
            shopId,
            partyId,
            type: 'ADJUSTMENT',
            amount: new Prisma.Decimal(input.amount),
            invoiceId: invoice.id,
            paymentId: payment.id,
            note: input.note ?? null,
            createdById: input.createdById ?? null,
          },
        });

        return { txn, payment, balance: balance - input.amount };
      },
      { isolationLevel: 'Serializable' },
    );
  }
}

export const cautionService = new CautionService();
