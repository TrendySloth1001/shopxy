import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import { round2 } from '../../shared/numbering/decimal.js';
import { logger } from '../../shared/logging/logger.js';

export type WalletSource =
  | 'REFUND'
  | 'COUPON'
  | 'REFERRAL'
  | 'LOYALTY'
  | 'MANUAL'
  | 'CHECKOUT'
  | 'TOPUP'
  | 'CANCEL';

export class WalletService {
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
    const drifted = denorm !== ledgerBalance;
    if (drifted) {
      logger.error(
        { event: 'wallet_balance_drift', userId, denorm, ledgerBalance, drift: round2(denorm - ledgerBalance) },
        'wallet balance drift detected — serving ledger SUM; run walletService.reconcile(userId, { heal: true })',
      );
    }
    return {
      balance: drifted ? ledgerBalance : Number(user.walletBalance),
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
