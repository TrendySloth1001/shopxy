import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import { round2 } from '../../shared/numbering/decimal.js';

export type WalletSource =
  | 'REFUND'
  | 'COUPON'
  | 'REFERRAL'
  | 'LOYALTY'
  | 'MANUAL'
  | 'CHECKOUT'
  /// Customer-funded wallet top-up via a payment gateway (Razorpay etc.).
  /// Written by the payment-gateway settlement handler on webhook capture;
  /// keyed (`gw:<intentId>`) so a redelivered webhook can't double-credit.
  | 'TOPUP'
  /// Refund for a per-shop child order the customer cancelled before
  /// the merchant acted. Distinct from REFUND (which is post-return).
  | 'CANCEL';

/// Append-only wallet primitive. Refunds (Phase 3), coupons / manual
/// platform credits (Phase 4), and loyalty / referral payouts (Phase 5)
/// all flow through this module. Reads stay cheap because the
/// per-user balance is denormalised on `users.wallet_balance` and
/// updated inside the same transaction that writes the ledger row.
///
/// The service intentionally exposes a single `credit()` (positive
/// amount = credit, negative = debit) so callers can't accidentally
/// post a positive amount as a debit by flipping a flag — sign is the
/// only state.
export class WalletService {
  /// Applies a signed amount to the denormalised balance and returns the
  /// new total. Credits (amount ≥ 0) increment unconditionally. Debits
  /// (amount < 0) use a gated `updateMany` with a `walletBalance >= |amount|`
  /// predicate so two concurrent spends can't each read-then-write and
  /// drive the balance negative — `count===0` means the funds weren't
  /// there at write time → reject. (The idempotency key only stops the
  /// *same* debit double-applying; it doesn't serialise *different* spends.)
  private async applyBalance(
    db: Prisma.TransactionClient,
    userId: number,
    amount: number,
  ): Promise<number> {
    if (amount < 0) {
      const upd = await db.user.updateMany({
        where: { id: userId, walletBalance: { gte: Math.abs(amount) } },
        data: { walletBalance: { increment: amount } },
      });
      if (upd.count === 0) {
        throw new HttpError(
          400,
          'INSUFFICIENT_WALLET_BALANCE',
          'Insufficient wallet balance.',
        );
      }
      const u = await db.user.findUniqueOrThrow({
        where: { id: userId },
        select: { walletBalance: true },
      });
      return Number(u.walletBalance);
    }
    const u = await db.user.update({
      where: { id: userId },
      data: { walletBalance: { increment: amount } },
      select: { walletBalance: true },
    });
    return Number(u.walletBalance);
  }

  /// Posts a ledger entry + bumps the denorm. The entry's
  /// `balanceAfter` is the new running total — lets the customer-facing
  /// ledger render without a window-function recompute.
  ///
  /// `idempotencyKey` is enforced via the partial unique index on
  /// `(user_id, idempotency_key)` so a retried RPC doesn't double-credit.
  /// When the key matches an existing row, this returns the original
  /// entry without writing.
  ///
  /// Pass `tx` to enrol in an outer transaction (e.g. the return-refund
  /// service does this so a refund + status flip + ledger entry all
  /// commit together).
  async credit(opts: {
    userId: number;
    amount: number;
    source: WalletSource;
    sourceId?: number | null;
    description: string;
    idempotencyKey?: string | null;
    tx?: Prisma.TransactionClient;
  }): Promise<{
    id: number;
    amount: number;
    balanceAfter: number;
    source: WalletSource;
    description: string;
    createdAt: Date;
    deduplicated?: boolean;
  }> {
    const run = async (db: Prisma.TransactionClient) => {
      // Insert-first idempotency: the unique index on
      // (user_id, idempotency_key) is the only safe lock against two
      // concurrent retries with the same key. We try to claim the row
      // first; only after that succeeds do we touch the balance. If the
      // insert fails with P2002 another caller already credited — we
      // return their entry without re-incrementing.
      if (opts.idempotencyKey) {
        try {
          const placeholder = await db.walletEntry.create({
            data: {
              userId: opts.userId,
              amount: opts.amount,
              balanceAfter: 0,
              source: opts.source,
              sourceId: opts.sourceId ?? null,
              description: opts.description,
              idempotencyKey: opts.idempotencyKey,
            },
          });
          const balanceAfter = await this.applyBalance(
            db,
            opts.userId,
            opts.amount,
          );
          const entry = await db.walletEntry.update({
            where: { id: placeholder.id },
            data: { balanceAfter },
          });
          return {
            id: entry.id,
            amount: Number(entry.amount),
            balanceAfter,
            source: entry.source as WalletSource,
            description: entry.description,
            createdAt: entry.createdAt,
          };
        } catch (e) {
          if ((e as { code?: string }).code === 'P2002') {
            const original = await db.walletEntry.findUnique({
              where: {
                wallet_entries_user_idempotency: {
                  userId: opts.userId,
                  idempotencyKey: opts.idempotencyKey,
                },
              },
            });
            if (original) {
              return {
                id: original.id,
                amount: Number(original.amount),
                balanceAfter: Number(original.balanceAfter),
                source: original.source as WalletSource,
                description: original.description,
                createdAt: original.createdAt,
                deduplicated: true,
              };
            }
          }
          throw e;
        }
      }

      // No idempotency key — straightforward signed apply + insert.
      const balanceAfter = await this.applyBalance(db, opts.userId, opts.amount);
      const entry = await db.walletEntry.create({
        data: {
          userId: opts.userId,
          amount: opts.amount,
          balanceAfter,
          source: opts.source,
          sourceId: opts.sourceId ?? null,
          description: opts.description,
          idempotencyKey: null,
        },
      });
      return {
        id: entry.id,
        amount: Number(entry.amount),
        balanceAfter,
        source: entry.source as WalletSource,
        description: entry.description,
        createdAt: entry.createdAt,
      };
    };

    return opts.tx ? run(opts.tx) : prisma.$transaction(run);
  }

  /// Current balance + the most recent N entries — single round-trip
  /// for the wallet page header. Also re-sums the ledger as a drift
  /// guard: the denormalised `users.wallet_balance` is money, and a
  /// silent divergence from SUM(wallet_entries.amount) means a credit
  /// or debit escaped its transaction — that must be loud, not trusted.
  async snapshot(userId: number, recentLimit = 30) {
    const [user, entries, ledgerSum] = await Promise.all([
      prisma.user.findUniqueOrThrow({
        where: { id: userId },
        select: { walletBalance: true },
      }),
      prisma.walletEntry.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: recentLimit,
        select: {
          id: true,
          amount: true,
          balanceAfter: true,
          source: true,
          sourceId: true,
          description: true,
          createdAt: true,
        },
      }),
      prisma.walletEntry.aggregate({
        where: { userId },
        _sum: { amount: true },
      }),
    ]);
    const ledgerBalance = round2(Number(ledgerSum._sum.amount ?? 0));
    const denorm = round2(Number(user.walletBalance));
    if (denorm !== ledgerBalance) {
      console.error(
        `[wallet] balance drift for user ${userId}: denorm ${denorm.toFixed(2)} vs ledger ${ledgerBalance.toFixed(2)} — run walletService.reconcile(${userId}, { heal: true })`,
      );
    }
    return {
      balance: Number(user.walletBalance),
      /// SUM of every ledger entry — equals `balance` unless drifted.
      ledgerBalance,
      entries: entries.map((e) => ({
        id: e.id,
        amount: Number(e.amount),
        balanceAfter: Number(e.balanceAfter),
        source: e.source,
        sourceId: e.sourceId,
        description: e.description,
        createdAt: e.createdAt,
      })),
    };
  }

  /// Compare the denormalised balance against the ledger SUM. With
  /// `heal: true`, resets the denorm to the ledger figure (the entries
  /// are append-only and idempotency-keyed, so the SUM is the truth).
  /// Serializable so a concurrent credit can't interleave between the
  /// re-sum and the heal write.
  async reconcile(userId: number, opts?: { heal?: boolean }) {
    return prisma.$transaction(
      async (tx) => {
        const [user, sum] = await Promise.all([
          tx.user.findUniqueOrThrow({
            where: { id: userId },
            select: { walletBalance: true },
          }),
          tx.walletEntry.aggregate({ where: { userId }, _sum: { amount: true } }),
        ]);
        const ledger = round2(Number(sum._sum.amount ?? 0));
        const denorm = round2(Number(user.walletBalance));
        const drift = round2(denorm - ledger);
        let healed = false;
        if (drift !== 0 && opts?.heal) {
          await tx.user.update({
            where: { id: userId },
            data: { walletBalance: new Prisma.Decimal(ledger) },
          });
          healed = true;
        }
        return { userId, denorm, ledger, drift, healed };
      },
      { isolationLevel: 'Serializable' },
    );
  }
}

export const walletService = new WalletService();
