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
import { recordOperatorWithholding } from './operator-withholding.js';
import { settlePosTransfer } from './pos-split.js';
import * as posService from '../../pos/pos.service.js';
import { saleBus } from '../../pos/pos.bus.js';
import { getProvider } from '../providers/registry.js';
import { isQrCapable } from '../ports/payment-provider.port.js';

export interface SettlementHandler {
  onPaid(intent: GatewayPaymentRecord, tx?: Prisma.TransactionClient): Promise<void>;
  afterCommit?(intent: GatewayPaymentRecord): Promise<void>;
  onAbandon?(intent: GatewayPaymentRecord): Promise<void>;
}

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
      idempotencyKey: `gw:${intent.id}`,
      tx,
    });
  },
};

const orderPayment: SettlementHandler = {
  async onPaid(intent, tx) {
    const db = tx ?? prisma;
    await db.customerOrder.updateMany({
      where: { id: intent.target.id },
      data: { paymentStatus: 'PAID' },
    });
    await ensureOrderInvoiceReceipts(intent.target.id, db);
    if (tx) {
      await recordOperatorWithholding(intent, tx);
    }
    if (isRouteSplitEnabled() && tx) {
      await writeHeldTransferRows(intent, tx);
    }
  },
  async afterCommit(intent) {
    if (isRouteSplitEnabled()) {
      await executeHeldTransfers(intent.id);
    }
  },
};

const posSale: SettlementHandler = {
  async onPaid(intent, tx) {
    if (intent.shopId == null) {
      throw Object.assign(new Error('POS settlement requires shopId'), { status: 400 });
    }
    const settle = (t: Prisma.TransactionClient) =>
      posService.settlePaidSaleInTx(t, {
        shopId: intent.shopId!,
        saleId: intent.target.id,
        modeReference: intent.providerPaymentRef,
      });
    if (tx) await settle(tx);
    else await prisma.$transaction(settle);
  },
  async afterCommit(intent) {
    await settlePosTransfer(intent);
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
    if (intent.providerOrderRef?.startsWith('qr_')) {
      const provider = getProvider(intent.provider);
      if (isQrCapable(provider)) {
        try {
          await provider.closeQr(intent.providerOrderRef);
        } catch {
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
  POS: posSale,
};

export function settlementFor(type: SettlementTargetType): SettlementHandler {
  return handlers[type];
}
