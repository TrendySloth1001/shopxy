/**
 * Settlement bridge — the seam where a confirmed gateway payment meets the
 * existing domain. Keyed by SettlementTargetType. Every provider funnels into
 * the SAME handlers, so money logic is single-sourced (not copied per gateway).
 *
 * Handlers MUST be idempotent — the core may retry and webhooks redeliver. The
 * WALLET handler gets idempotency for free via walletService's keyed credit.
 */
import type { Prisma } from '@prisma/client';
import prisma from '../../../infra/db/prisma.js';
import type { GatewayPaymentRecord, SettlementTargetType } from '../ports/types.js';
import { walletService, type WalletSource } from '../../wallet/wallet.service.js';
import { ensureOrderInvoiceReceipts } from '../order-receipts.js';
import {
  isRouteSplitEnabled,
  writeHeldTransferRows,
  executeHeldTransfers,
} from './order-split.js';

export interface SettlementHandler {
  /**
   * Apply a CAPTURED intent to the domain, INSIDE the settlement transaction.
   * Idempotent (the core may retry; webhooks redeliver). Do only DB work here —
   * external provider calls belong in afterCommit so a crash can't move money
   * without a committed row.
   */
  onPaid(intent: GatewayPaymentRecord, tx?: Prisma.TransactionClient): Promise<void>;
  /**
   * Optional side effects to run AFTER the settlement tx commits — external
   * calls (e.g. creating Route transfers) that must not run inside the tx.
   * Best-effort: the core swallows failures here because the rows written in
   * onPaid are healable by reconciliation. Idempotent.
   */
  afterCommit?(intent: GatewayPaymentRecord): Promise<void>;
}

// Dedicated source for gateway-funded wallet top-ups (added to WalletSource).
const WALLET_TOPUP_SOURCE: WalletSource = 'TOPUP';

const walletTopUp: SettlementHandler = {
  async onPaid(intent, tx) {
    if (intent.customerUserId == null) {
      throw Object.assign(new Error('WALLET settlement requires customerUserId'), {
        status: 400,
      });
    }
    await walletService.credit({
      userId: intent.customerUserId,
      amount: intent.amount,
      source: WALLET_TOPUP_SOURCE,
      sourceId: intent.id,
      description: `Wallet top-up (${intent.provider})`,
      // Stable key → a redelivered webhook can't double-credit.
      idempotencyKey: `gw:${intent.id}`,
      tx,
    });
  },
};

// ORDER: a customer paid the online-payable remainder of a CustomerOrder at
// checkout. The intent's target.id IS the CustomerOrder id. We flip the order's
// paymentStatus to PAID; merchant confirmation/fulfilment is unchanged (the
// order still flows through the normal inbox).
//
// CURRENT STATE — read this before describing the system to anyone: there is NO
// Route split and NO on-hold settlement here yet. The full captured amount lands
// in the PLATFORM's own Razorpay account and settles to our bank on the normal
// schedule; sellers are not paid out by this code at all. That is a plain
// platform-collection model, not held funds — do not call it "escrow". The
// per-shop on-hold split (funds parked in Razorpay's balance, released on
// delivery) is the next increment, designed in ROUTE_SPLIT_DESIGN.md but NOT
// built: it will create on-hold transfers here per child shop.
const orderPayment: SettlementHandler = {
  async onPaid(intent, tx) {
    const db = tx ?? prisma;
    // updateMany (not update): idempotent on webhook redelivery, and a missing
    // order can't throw and wedge the webhook into a retry loop.
    await db.customerOrder.updateMany({
      where: { id: intent.target.id },
      data: { paymentStatus: 'PAID' },
    });
    // Confirm-then-pay: if the merchant already confirmed (invoices exist),
    // post the gateway receipt onto each per-shop invoice now so the merchant
    // ledger reflects the payment. Idempotent; a no-op when no invoice exists
    // yet (pay-then-confirm — confirmRequest reconciles at confirm time).
    await ensureOrderInvoiceReceipts(intent.target.id, db);
    // Route on-hold split (OFF by default). Phase 1 only: write the per-shop
    // HELD/KYC_GATED transfer rows in this tx. The provider calls run in
    // afterCommit. Until ROUTE_SPLIT_ENABLED is set (post sandbox + sign-off),
    // this is a no-op and the captured money stays in the platform account.
    if (isRouteSplitEnabled() && tx) {
      await writeHeldTransferRows(intent, tx);
    }
  },
  async afterCommit(intent) {
    // Phase 2: create the held transfers at Razorpay (fetch-before-create,
    // idempotent). Reconciliation re-runs this for any null-ref HELD row, so a
    // failure here is recoverable — that's why the core can swallow it.
    if (isRouteSplitEnabled()) {
      await executeHeldTransfers(intent.id);
    }
  },
};

function notWired(type: string): SettlementHandler {
  return {
    async onPaid() {
      throw Object.assign(new Error(`Settlement target ${type} not wired yet`), {
        status: 501,
      });
    },
  };
}

const handlers: Record<SettlementTargetType, SettlementHandler> = {
  WALLET: walletTopUp,
  ORDER: orderPayment,
  INVOICE: notWired('INVOICE'),
  CAUTION: notWired('CAUTION'),
};

export function settlementFor(type: SettlementTargetType): SettlementHandler {
  return handlers[type];
}
