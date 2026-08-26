import type { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import {
  type LedgerDirection,
  type LedgerReasonCode,
  type LedgerSourceType,
  type PurchasePriceMode,
} from '../../shared/constants/index.js';
import { notificationsService } from '../notifications/notifications.service.js';

export interface PostLineInput {
  productId: number;
  quantity: number;
  unitPrice?: number;
  sourceLineId?: number;
  note?: string;
}

export interface PostInput {
  shopId: number;
  direction: LedgerDirection;
  reasonCode: LedgerReasonCode;
  sourceType: LedgerSourceType;
  sourceId?: number;
  lines: PostLineInput[];
  createdById?: number;
  idempotencyKey?: string;

  vendorId?: number;
  supplierName?: string;
  purchasePriceMode?: PurchasePriceMode;
  note?: string;

  counterpartyName?: string;
  counterpartyGstin?: string;
}

export interface PostResult {
  entries: PostedEntry[];
}

export interface PostedEntry {
  id: number;
  productId: number;
  direction: LedgerDirection;
  reasonCode: LedgerReasonCode;
  quantity: number;
  unitCost: number | null;
  totalValue: number | null;
  stockBefore: number;
  stockAfter: number;
}

export type PostError =
  | { error: 'Product not found'; productId: number }
  | { error: 'Product is inactive'; productId: number }
  | { error: 'Insufficient stock'; productId: number; available: number; requested: number }
  | { error: 'Unit price required for stock-in'; productId: number }
  | { error: 'Reversal not allowed: layer already consumed'; layerId: number }
  | { error: 'Idempotency key already used' };

const ROUND_COST = (v: number) => Math.round((v + Number.EPSILON) * 10000) / 10000;
const ROUND_VALUE = (v: number) => Math.round((v + Number.EPSILON) * 100) / 100;

function mapEntry(e: {
  id: number;
  productId: number;
  direction: string;
  reasonCode: string;
  quantity: Prisma.Decimal | number;
  unitCost: Prisma.Decimal | number | null;
  totalValue: Prisma.Decimal | number | null;
  stockBefore: Prisma.Decimal | number | null;
  stockAfter: Prisma.Decimal | number | null;
}): PostedEntry {
  return {
    id: e.id,
    productId: e.productId,
    direction: e.direction as LedgerDirection,
    reasonCode: e.reasonCode as LedgerReasonCode,
    quantity: Number(e.quantity),
    unitCost: e.unitCost === null ? null : Number(e.unitCost),
    totalValue: e.totalValue === null ? null : Number(e.totalValue),
    stockBefore: Number(e.stockBefore ?? 0),
    stockAfter: Number(e.stockAfter ?? 0),
  };
}

export class LedgerService {
  async post(
    input: PostInput,
    tx?: Prisma.TransactionClient,
  ): Promise<PostResult | PostError> {
    if (input.lines.length === 0) {
      return { entries: [] };
    }

    const db: Prisma.TransactionClient | typeof prisma = tx ?? prisma;

    if (input.idempotencyKey) {
      const existing = await db.stockTransaction.findMany({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (existing.length > 0) {
        return {
          entries: existing.map((e) => ({
            id: e.id,
            productId: e.productId,
            direction: e.direction as LedgerDirection,
            reasonCode: e.reasonCode as LedgerReasonCode,
            quantity: Number(e.quantity),
            unitCost: e.unitCost === null ? null : Number(e.unitCost),
            totalValue: e.totalValue === null ? null : Number(e.totalValue),
            stockBefore: Number(e.stockBefore ?? 0),
            stockAfter: Number(e.stockAfter ?? 0),
          })),
        };
      }
    }

    const runPosting = async (txClient: Prisma.TransactionClient): Promise<PostResult> => {
      const entries: PostedEntry[] = [];
      const sortedLines = [...input.lines].sort((a, b) => a.productId - b.productId);

      for (const line of sortedLines) {
        try {
          const posted = await this.postLine(txClient, input, line);
          if ('error' in posted) throw posted;
          entries.push(posted);
        } catch (err) {
          if (
            input.idempotencyKey &&
            err && typeof err === 'object' && 'code' in err &&
            (err as { code?: string }).code === 'P2002'
          ) {
            const existing = await txClient.stockTransaction.findMany({
              where: { idempotencyKey: input.idempotencyKey },
            });
            if (existing.length > 0) {
              return {
                entries: existing.map((e) => ({
                  id: e.id,
                  productId: e.productId,
                  direction: e.direction as LedgerDirection,
                  reasonCode: e.reasonCode as LedgerReasonCode,
                  quantity: Number(e.quantity),
                  unitCost: e.unitCost === null ? null : Number(e.unitCost),
                  totalValue: e.totalValue === null ? null : Number(e.totalValue),
                  stockBefore: Number(e.stockBefore ?? 0),
                  stockAfter: Number(e.stockAfter ?? 0),
                })),
              };
            }
          }
          throw err;
        }
      }
      return { entries };
    };

    try {
      const result = tx ? await runPosting(tx) : await prisma.$transaction(runPosting);
      void this.notifyLowStock(input.shopId, result.entries).catch(() => {});
      return result;
    } catch (err) {
      if (err && typeof err === 'object' && 'error' in err) return err as PostError;
      throw err;
    }
  }

  private async notifyLowStock(shopId: number, entries: PostedEntry[]): Promise<void> {
    const outEntries = entries.filter((e) => e.direction === 'OUT');
    if (outEntries.length === 0) return;

    const productIds = [...new Set(outEntries.map((e) => e.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, name: true, unit: true, lowStockThreshold: true },
    });
    const byId = new Map(products.map((p) => [p.id, p]));

    const crossed = outEntries.filter((e) => {
      const product = byId.get(e.productId);
      if (!product) return false;
      const threshold = Number(product.lowStockThreshold);
      return e.stockBefore > threshold && e.stockAfter <= threshold;
    });
    if (crossed.length === 0) return;

    const shop = await prisma.shop.findUnique({ where: { id: shopId }, select: { ownerUserId: true } });
    if (!shop) return;

    for (const e of crossed) {
      const product = byId.get(e.productId)!;
      await notificationsService
        .create({
          userId: shop.ownerUserId,
          kind: 'LOW_STOCK',
          title: 'Low stock alert',
          body: `${product.name} is running low — ${e.stockAfter} ${product.unit} left.`,
          data: { productId: e.productId, stockAfter: e.stockAfter },
        })
        .catch(() => {});
    }
  }

  async reverse(
    originalEntryId: number,
    opts: {
      reasonCode: LedgerReasonCode;
      sourceType: LedgerSourceType;
      sourceId?: number;
      createdById?: number;
      note?: string;
    },
    txClient?: Prisma.TransactionClient,
  ): Promise<PostResult | PostError | { error: 'Entry not found' } | { error: 'Already reversed' }> {
    const work = async (tx: Prisma.TransactionClient) => {
        const original = await tx.stockTransaction.findUnique({
          where: { id: originalEntryId },
          include: { costConsumptions: true, costLayer: true },
        });
        if (!original) throw { error: 'Entry not found' as const };

        const alreadyReversed = await tx.stockTransaction.findFirst({
          where: { reversesId: originalEntryId },
          select: { id: true },
        });
        if (alreadyReversed) throw { error: 'Already reversed' as const };

        const product = await this.lockProduct(tx, original.productId, original.shopId);
        if (!product) throw { error: 'Product not found' as const, productId: original.productId };

        const reverseDirection: LedgerDirection = original.direction === 'IN' ? 'OUT' : 'IN';
        const quantity = Number(original.quantity);
        const stockBefore = Number(product.stockQuantity);

        if (reverseDirection === 'IN') {
          for (const c of original.costConsumptions) {
            await tx.costLayer.update({
              where: { id: c.layerId },
              data: { qtyRemaining: { increment: Number(c.qtyConsumed) } },
            });
          }
        } else {
          if (original.costLayer) {
            const layer = original.costLayer;
            if (Number(layer.qtyRemaining) < Number(layer.qtyReceived)) {
              throw { error: 'Reversal not allowed: layer already consumed' as const, layerId: layer.id };
            }
            await tx.costLayer.delete({ where: { id: layer.id } });
          }
        }

        const stockAfter = reverseDirection === 'IN' ? stockBefore + quantity : stockBefore - quantity;
        if (stockAfter < 0) {
          throw {
            error: 'Insufficient stock' as const,
            productId: original.productId,
            available: stockBefore,
            requested: quantity,
          };
        }

        const reversal = await tx.stockTransaction.create({
          data: {
            shopId: original.shopId,
            productId: original.productId,
            direction: reverseDirection,
            reasonCode: opts.reasonCode,
            sourceType: opts.sourceType,
            sourceId: opts.sourceId,
            quantity,
            unitCost: original.unitCost ?? undefined,
            totalValue: original.totalValue ?? undefined,
            stockBefore,
            stockAfter,
            type: reverseDirection === 'IN' ? 'STOCK_IN' : 'STOCK_OUT',
            reversesId: original.id,
            createdById: opts.createdById,
            note: opts.note ?? `Reversal of #${original.id}`,
            counterpartyName: original.counterpartyName ?? undefined,
            counterpartyGstin: original.counterpartyGstin ?? undefined,
          },
        });

        await tx.product.update({
          where: { id: original.productId },
          data: { stockQuantity: stockAfter },
        });

        return {
          entries: [
            {
              id: reversal.id,
              productId: reversal.productId,
              direction: reverseDirection,
              reasonCode: opts.reasonCode,
              quantity,
              unitCost: reversal.unitCost === null ? null : Number(reversal.unitCost),
              totalValue: reversal.totalValue === null ? null : Number(reversal.totalValue),
              stockBefore,
              stockAfter,
            },
          ],
        };
    };
    try {
      if (txClient) {
        return await work(txClient);
      }
      return await prisma.$transaction(work);
    } catch (err) {
      if (err && typeof err === 'object' && 'error' in err)
        return err as PostError | { error: 'Entry not found' } | { error: 'Already reversed' };
      throw err;
    }
  }

  async restockReturnAtCost(
    input: {
      shopId: number;
      originalInvoiceId: number;
      sourceType: LedgerSourceType;
      sourceId: number;
      idempotencyKey?: string;
      createdById?: number;
      counterpartyName?: string;
      counterpartyGstin?: string;
      note?: string;
      lines: Array<{ productId: number; quantity: number; sourceLineId?: number }>;
    },
    tx?: Prisma.TransactionClient,
  ): Promise<PostResult | PostError | { error: 'No original consumption'; productId: number }> {
    if (input.lines.length === 0) return { entries: [] };
    const db: Prisma.TransactionClient | typeof prisma = tx ?? prisma;

    if (input.idempotencyKey) {
      const existing = await db.stockTransaction.findMany({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (existing.length > 0) {
        return { entries: existing.map(mapEntry) };
      }
    }

    const work = async (t: Prisma.TransactionClient): Promise<PostResult | PostError | { error: 'No original consumption'; productId: number }> => {
      const entries: PostedEntry[] = [];
      const sorted = [...input.lines].sort((a, b) => a.productId - b.productId);

      for (const line of sorted) {
        const product = await this.lockProduct(t, line.productId, input.shopId);
        if (!product) return { error: 'Product not found', productId: line.productId };
        const qty = line.quantity;
        if (!(qty > 0)) continue;

        const saleOut = await t.stockTransaction.findFirst({
          where: {
            shopId: input.shopId,
            productId: line.productId,
            sourceType: 'INVOICE',
            sourceId: input.originalInvoiceId,
            direction: 'OUT',
            reversesId: null,
          },
          include: {
            costConsumptions: { orderBy: { id: 'desc' } },
          },
          orderBy: { id: 'desc' },
        });
        if (!saleOut || saleOut.costConsumptions.length === 0) {
          return { error: 'No original consumption', productId: line.productId };
        }

        let remaining = qty;
        let restoredValue = 0;
        for (const c of saleOut.costConsumptions) {
          if (remaining <= 0) break;
          const consumed = Number(c.qtyConsumed);
          const take = Math.min(consumed, remaining);
          if (!(take > 0)) continue;
          await t.costLayer.update({
            where: { id: c.layerId },
            data: { qtyRemaining: { increment: take } },
          });
          restoredValue += take * Number(c.unitCost);
          remaining -= take;
        }
        const restoredQty = qty - remaining;
        if (!(restoredQty > 0)) {
          return { error: 'No original consumption', productId: line.productId };
        }

        const stockBefore = Number(product.stockQuantity);
        const stockAfter = stockBefore + restoredQty;
        const unitCost = ROUND_COST(restoredValue / restoredQty);
        const totalValue = ROUND_VALUE(restoredValue);

        const layerAgg = await t.costLayer.aggregate({
          where: { productId: line.productId, qtyRemaining: { gt: 0 } },
          _sum: { qtyRemaining: true },
        });
        const layers = await t.costLayer.findMany({
          where: { productId: line.productId, qtyRemaining: { gt: 0 } },
          select: { qtyRemaining: true, unitCost: true },
        });
        const totalRemainingQty = Number(layerAgg._sum.qtyRemaining ?? 0);
        let purchasePriceAfter: number | undefined;
        if (totalRemainingQty > 0) {
          const totalRemainingValue = layers.reduce(
            (s, l) => s + Number(l.qtyRemaining) * Number(l.unitCost),
            0,
          );
          purchasePriceAfter = ROUND_VALUE(totalRemainingValue / totalRemainingQty);
        }

        const entry = await t.stockTransaction.create({
          data: {
            shopId: input.shopId,
            productId: line.productId,
            direction: 'IN',
            reasonCode: 'RETURN_IN',
            sourceType: input.sourceType,
            sourceId: input.sourceId,
            sourceLineId: line.sourceLineId,
            quantity: restoredQty,
            unitCost,
            totalValue,
            stockBefore,
            stockAfter,
            type: 'STOCK_IN',
            unitPrice: unitCost,
            purchasePriceBefore: ROUND_VALUE(Number(product.purchasePrice)),
            purchasePriceAfter,
            counterpartyName: input.counterpartyName,
            counterpartyGstin: input.counterpartyGstin,
            note: input.note,
            createdById: input.createdById,
            idempotencyKey:
              input.idempotencyKey !== undefined
                ? `${input.idempotencyKey}:${line.productId}:${line.sourceLineId ?? '_'}`
                : undefined,
          },
        });

        await t.product.update({
          where: { id: line.productId },
          data: {
            stockQuantity: stockAfter,
            ...(purchasePriceAfter !== undefined ? { purchasePrice: purchasePriceAfter } : {}),
          },
        });

        entries.push({
          id: entry.id,
          productId: line.productId,
          direction: 'IN',
          reasonCode: 'RETURN_IN',
          quantity: restoredQty,
          unitCost,
          totalValue,
          stockBefore,
          stockAfter,
        });
      }
      return { entries };
    };

    try {
      if (tx) return await work(tx);
      return await prisma.$transaction(work);
    } catch (err) {
      if (
        input.idempotencyKey &&
        err && typeof err === 'object' && 'code' in err &&
        (err as { code?: string }).code === 'P2002'
      ) {
        const existing = await db.stockTransaction.findMany({
          where: { idempotencyKey: input.idempotencyKey },
        });
        if (existing.length > 0) return { entries: existing.map(mapEntry) };
      }
      if (err && typeof err === 'object' && 'error' in err) return err as PostError;
      throw err;
    }
  }

  private async postLine(
    tx: Prisma.TransactionClient,
    parent: PostInput,
    line: PostLineInput,
  ): Promise<PostedEntry | PostError> {
    const product = await this.lockProduct(tx, line.productId, parent.shopId);
    if (!product) return { error: 'Product not found', productId: line.productId };

    if (
      !product.isActive &&
      parent.reasonCode !== 'OPENING' &&
      parent.reasonCode !== 'RECOUNT'
    ) {
      return { error: 'Product is inactive', productId: line.productId };
    }

    const stockBefore = Number(product.stockQuantity);
    const qty = line.quantity;

    if (parent.direction === 'OUT' && stockBefore < qty) {
      return { error: 'Insufficient stock', productId: line.productId, available: stockBefore, requested: qty };
    }

    let unitCost: number | null = null;
    let totalValue: number | null = null;
    let stockAfter: number;
    let purchasePriceBefore: number | undefined;
    let purchasePriceAfter: number | undefined;

    if (parent.direction === 'IN') {
      if (line.unitPrice === undefined) {
        return { error: 'Unit price required for stock-in', productId: line.productId };
      }
      unitCost = ROUND_COST(line.unitPrice);
      totalValue = ROUND_VALUE(qty * unitCost);
      stockAfter = stockBefore + qty;

      purchasePriceBefore = ROUND_VALUE(Number(product.purchasePrice));
      purchasePriceAfter = this.computeNextPurchasePrice({
        mode: parent.purchasePriceMode ?? 'WEIGHTED_AVERAGE',
        currentPurchasePrice: Number(product.purchasePrice),
        currentStock: stockBefore,
        incomingQuantity: qty,
        incomingUnitPrice: unitCost,
      });
    } else {
      stockAfter = stockBefore - qty;
    }

    const legacyType = parent.direction === 'IN' ? 'STOCK_IN' : 'STOCK_OUT';

    const entry = await tx.stockTransaction.create({
      data: {
        shopId: parent.shopId,
        productId: line.productId,
        direction: parent.direction,
        reasonCode: parent.reasonCode,
        sourceType: parent.sourceType,
        sourceId: parent.sourceId,
        sourceLineId: line.sourceLineId,
        quantity: qty,
        unitCost: unitCost === null ? undefined : unitCost,
        totalValue: totalValue === null ? undefined : totalValue,
        stockBefore,
        stockAfter,
        type: legacyType,
        unitPrice: line.unitPrice,
        supplierName: parent.supplierName,
        vendorId: parent.vendorId,
        purchasePriceMode: parent.direction === 'IN' ? parent.purchasePriceMode ?? 'WEIGHTED_AVERAGE' : undefined,
        purchasePriceBefore,
        purchasePriceAfter,
        counterpartyName: parent.counterpartyName,
        counterpartyGstin: parent.counterpartyGstin,
        note: line.note ?? parent.note,
        createdById: parent.createdById,
        idempotencyKey:
          parent.idempotencyKey !== undefined
            ? `${parent.idempotencyKey}:${line.productId}:${line.sourceLineId ?? '_'}`
            : undefined,
      },
    });

    if (parent.direction === 'IN') {
      await tx.costLayer.create({
        data: {
          productId: line.productId,
          qtyReceived: qty,
          qtyRemaining: qty,
          unitCost: unitCost!,
          sourceType: parent.sourceType,
          sourceId: parent.sourceId,
          ledgerEntryId: entry.id,
        },
      });
    } else {
      const consumption = await this.consumeFifoLayers(tx, line.productId, qty, entry.id);
      unitCost = consumption.weightedAvgCost;
      totalValue = consumption.totalValue;
      await tx.stockTransaction.update({
        where: { id: entry.id },
        data: { unitCost, totalValue },
      });
    }

    await tx.product.update({
      where: { id: line.productId },
      data: {
        stockQuantity: stockAfter,
        ...(purchasePriceAfter !== undefined ? { purchasePrice: purchasePriceAfter } : {}),
      },
    });

    return {
      id: entry.id,
      productId: line.productId,
      direction: parent.direction,
      reasonCode: parent.reasonCode,
      quantity: qty,
      unitCost,
      totalValue,
      stockBefore,
      stockAfter,
    };
  }

  private async lockProduct(
    tx: Prisma.TransactionClient,
    productId: number,
    shopId: number,
  ) {
    const rows = await tx.$queryRaw<
      Array<{
        id: number;
        shop_id: number;
        stock_quantity: string;
        purchase_price: string;
        is_active: boolean;
      }>
    >`SELECT id, shop_id, stock_quantity, purchase_price, is_active
        FROM products WHERE id = ${productId} AND shop_id = ${shopId} FOR UPDATE`;
    if (rows.length === 0) return null;
    return {
      id: rows[0].id,
      shopId: rows[0].shop_id,
      stockQuantity: rows[0].stock_quantity,
      purchasePrice: rows[0].purchase_price,
      isActive: rows[0].is_active,
    };
  }

  private async consumeFifoLayers(
    tx: Prisma.TransactionClient,
    productId: number,
    qty: number,
    ledgerEntryId: number,
  ): Promise<{ weightedAvgCost: number | null; totalValue: number | null }> {
    let remaining = qty;
    let totalValue = 0;
    let touchedAnyLayer = false;

    while (remaining > 0) {
      const layer = await tx.costLayer.findFirst({
        where: { productId, qtyRemaining: { gt: 0 } },
        orderBy: { createdAt: 'asc' },
      });
      if (!layer) break;

      const take = Math.min(Number(layer.qtyRemaining), remaining);
      const layerCost = Number(layer.unitCost);

      await tx.costConsumption.create({
        data: { layerId: layer.id, ledgerEntryId, qtyConsumed: take, unitCost: layerCost },
      });
      await tx.costLayer.update({
        where: { id: layer.id },
        data: { qtyRemaining: { decrement: take } },
      });

      totalValue += take * layerCost;
      remaining -= take;
      touchedAnyLayer = true;
    }

    if (!touchedAnyLayer) {
      return { weightedAvgCost: null, totalValue: null };
    }

    const consumed = qty - remaining;
    return {
      weightedAvgCost: consumed > 0 ? ROUND_COST(totalValue / consumed) : null,
      totalValue: ROUND_VALUE(totalValue),
    };
  }

  private computeNextPurchasePrice(args: {
    mode: PurchasePriceMode;
    currentPurchasePrice: number;
    currentStock: number;
    incomingQuantity: number;
    incomingUnitPrice: number;
  }): number {
    const { mode, currentPurchasePrice, currentStock, incomingQuantity, incomingUnitPrice } = args;
    if (mode === 'KEEP_CURRENT') return ROUND_VALUE(currentPurchasePrice);
    if (mode === 'USE_LATEST') return ROUND_VALUE(incomingUnitPrice);
    const nextStock = currentStock + incomingQuantity;
    if (nextStock <= 0) return ROUND_VALUE(incomingUnitPrice);
    return ROUND_VALUE(
      (currentStock * currentPurchasePrice + incomingQuantity * incomingUnitPrice) / nextStock,
    );
  }

  async listForProduct(
    shopId: number,
    productId: number,
    options: { limit: number; skip: number },
  ) {
    const where = { shopId, productId };
    const [entries, total] = await Promise.all([
      prisma.stockTransaction.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        include: {
          vendor: { select: { id: true, name: true } },
          createdBy: { select: { id: true, name: true } },
        },
      }),
      prisma.stockTransaction.count({ where }),
    ]);
    return { entries, total };
  }
}

export const ledgerService = new LedgerService();
