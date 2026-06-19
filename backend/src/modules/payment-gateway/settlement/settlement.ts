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
import { nextCautionRef } from '../../../shared/numbering/sequences.js';
import {
  isRouteSplitEnabled,
  writeHeldTransferRows,
  executeHeldTransfers,
} from './order-split.js';
import { settlePosTransfer } from './pos-split.js';
import * as posService from '../../pos/pos.service.js';
import { saleBus } from '../../pos/pos.bus.js';
import { getProvider } from '../providers/registry.js';
import { isQrCapable } from '../ports/payment-provider.port.js';

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
  /**
   * Optional: tear down an intent that was abandoned (never paid past the
   * recheck window, or cancelled at the till). Lets a target undo any provider-
   * side artefact and release its domain lock — e.g. POS closes the QR and
   * unlocks the cart. Best-effort + idempotent; the core calls it before FAILING
   * the intent.
   */
  onAbandon?(intent: GatewayPaymentRecord): Promise<void>;
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

// CAUTION: a linked customer paid their own caution-deposit request online.
// target.id IS the CautionRequest id. Capturing the payment is what approves
// the request — no merchant review step (the merchant is RECEIVING money) —
// so this mints the DEPOSIT CautionTxn exactly like the merchant approve path
// (caution-requests.service.approveCautionRequest), but with channel GATEWAY
// and the provider payment ref as the mode reference. The logic lives here
// (raw prisma) rather than calling that service to keep the settlement module
// free of an import cycle through paymentGatewayService.
//
// Edge the manual path doesn't have: the request can be REJECTED/CANCELLED
// while the customer's checkout sheet is open. The capture is real money with
// nowhere to land — refund it to the customer's wallet rather than silently
// keeping it.
const cautionDeposit: SettlementHandler = {
  async onPaid(intent, tx) {
    const db = tx ?? prisma;
    const requestId = intent.target.id;
    const refundCapturedToWallet = async (why: string) => {
      if (intent.customerUserId == null) return; // no wallet to land in; reconciliation will surface it
      await walletService.credit({
        userId: intent.customerUserId,
        amount: intent.amount,
        source: 'REFUND',
        sourceId: requestId,
        description: why,
        idempotencyKey: `gw:caution-fallback:${intent.id}`,
        tx,
      });
    };

    const req = await db.cautionRequest.findUnique({
      where: { id: requestId },
      select: {
        id: true,
        shopId: true,
        partyId: true,
        amount: true,
        note: true,
        status: true,
        cautionTxnId: true,
        requestedById: true,
        shop: { select: { ownerUserId: true } },
        party: { select: { name: true } },
      },
    });
    if (!req) {
      await refundCapturedToWallet(
        'Caution payment captured for a deleted request — refunded to wallet',
      );
      return;
    }

    // Claim PENDING → APPROVED. Lost claim = redelivery (already settled →
    // no-op) or the request closed underneath the checkout (→ wallet refund).
    const claimed = await db.cautionRequest.updateMany({
      where: { id: requestId, status: 'PENDING' },
      data: {
        status: 'APPROVED',
        reviewedAt: new Date(),
        channel: 'GATEWAY',
        provider: intent.provider,
        providerRef:
          intent.providerPaymentRef ?? intent.providerOrderRef ?? `intent:${intent.id}`,
      },
    });
    if (claimed.count === 0) {
      if (req.status === 'APPROVED') return; // redelivered webhook — already minted
      await refundCapturedToWallet(
        'Caution payment captured after the request was closed — refunded to wallet',
      );
      return;
    }

    const receiptNo = await nextCautionRef(req.shopId, new Date(), tx);
    const txn = await db.cautionTxn.create({
      data: {
        shopId: req.shopId,
        partyId: req.partyId,
        type: 'DEPOSIT',
        amount: req.amount,
        mode: 'GATEWAY',
        modeReference: intent.providerPaymentRef ?? intent.providerOrderRef ?? null,
        receiptNo,
        note: req.note ?? 'Caution deposit paid online',
        createdById: req.requestedById,
      },
    });
    await db.cautionRequest.update({
      where: { id: requestId },
      data: { cautionTxnId: txn.id },
    });

    // Notify both sides. Inside the settlement tx so a crash can't mint the
    // deposit silently.
    if (req.requestedById != null) {
      await db.notification.create({
        data: {
          userId: req.requestedById,
          kind: 'CAUTION_REQUEST_APPROVED',
          title: 'Your caution deposit is confirmed',
          body: `₹${Number(req.amount).toFixed(2)} paid online (receipt ${receiptNo})`,
          data: { cautionRequestId: requestId, partyId: req.partyId },
        },
      });
    }
    await db.notification.create({
      data: {
        userId: req.shop.ownerUserId,
        kind: 'CAUTION_DEPOSIT_RECEIVED',
        title: `${req.party.name} paid a caution deposit online`,
        body: `₹${Number(req.amount).toFixed(2)} received via ${intent.provider} (receipt ${receiptNo})`,
        data: { cautionRequestId: requestId, partyId: req.partyId },
      },
    });
  },
};

// POS: an in-store customer paid a sale via a Razorpay UPI-QR. target.id IS the
// Sale id. Capturing the QR is what turns the locked cart into a confirmed sale
// — so onPaid runs the SAME money path manual checkout uses (invoice + stock +
// UPI receipt) inside the settlement tx, idempotent on sale.invoiceId. The Route
// transfer to the merchant's linked account + the till "paid ✓" nudge run after
// commit. An abandoned/cancelled QR is closed and the cart unlocked.
const posSale: SettlementHandler = {
  async onPaid(intent, tx) {
    if (intent.shopId == null) {
      throw Object.assign(new Error('POS settlement requires shopId'), { status: 400 });
    }
    const settle = (t: Prisma.TransactionClient) =>
      posService.settlePaidSaleInTx(t, {
        shopId: intent.shopId!,
        saleId: intent.target.id,
        // The Razorpay payment id is the receipt's mode reference.
        modeReference: intent.providerPaymentRef,
      });
    // confirm() always passes a tx; the branch is a defensive fallback only.
    if (tx) await settle(tx);
    else await prisma.$transaction(settle);
  },
  async afterCommit(intent) {
    // Route the captured amount to the shop's linked account (gated by
    // ROUTE_SPLIT_ENABLED + payoutsEnabled; fetch-before-create idempotent).
    await settlePosTransfer(intent);
    // Flip both tills to the receipt (no cart/PII on the wire — just the ids).
    const sale = await prisma.sale.findUnique({
      where: { id: intent.target.id },
      select: { invoiceId: true },
    });
    if (intent.shopId != null && sale?.invoiceId != null) {
      saleBus.publish(intent.shopId, {
        type: 'pos.checkout',
        saleId: intent.target.id,
        invoiceId: sale.invoiceId,
      });
    }
  },
  async onAbandon(intent) {
    // Close a standalone QR (qr_…) so a late scan can't pay an abandoned sale.
    // An online-order intent (order_…) has no QR — the Razorpay order just
    // expires — so we only unlock the cart. Both best-effort.
    if (intent.providerOrderRef?.startsWith('qr_')) {
      const provider = getProvider(intent.provider);
      if (isQrCapable(provider)) {
        try {
          await provider.closeQr(intent.providerOrderRef);
        } catch {
          /* best-effort — a single-use QR may already be closed */
        }
      }
    }
    if (intent.shopId != null) {
      await posService.unlockSale(intent.shopId, intent.target.id);
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
  CAUTION: cautionDeposit,
  POS: posSale,
};

export function settlementFor(type: SettlementTargetType): SettlementHandler {
  return handlers[type];
}
