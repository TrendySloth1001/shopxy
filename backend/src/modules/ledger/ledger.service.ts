import type { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import {
  type LedgerDirection,
  type LedgerReasonCode,
  type LedgerSourceType,
  type PurchasePriceMode,
} from '../../shared/constants/index.js';

export interface PostLineInput {
  productId: number;
  /// Always positive. Direction is on the parent.
  quantity: number;
  /// For IN: required (cost basis of arriving goods).
  /// For OUT: ignored — FIFO determines cost.
  unitPrice?: number;
  /// FK back to invoice_item / challan_item / adjustment_item.
  sourceLineId?: number;
  note?: string;
}

export interface PostInput {
  /// Owning shop. Every ledger row carries it for cheap per-shop
  /// stock-report queries — and so cross-tenant posts are physically
  /// impossible: the shopId must match the products being mutated.
  shopId: number;
  direction: LedgerDirection;
  reasonCode: LedgerReasonCode;
  sourceType: LedgerSourceType;
  sourceId?: number;
  lines: PostLineInput[];
  createdById?: number;
  idempotencyKey?: string;

  // Legacy / pass-through metadata (preserved on ledger rows)
  vendorId?: number;
  supplierName?: string;
  purchasePriceMode?: PurchasePriceMode;
  note?: string;

  /// Snapshot of who's on the other side of this movement (vendor for
  /// IN, customer/party for OUT). Survives deletion of the source record.
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

export class LedgerService {
  /// Post a ledger entry (one row per line). Wraps everything in a
  /// serializable transaction and locks each product row before touching
  /// stock. Returns either { entries } or { error, … }.
  ///
  /// Accepts an optional `tx` so callers that are already inside a
  /// `$transaction` can post atomically with their parent work (e.g.
  /// invoice creation + ledger post must succeed or fail together).
  async post(
    input: PostInput,
    tx?: Prisma.TransactionClient,
  ): Promise<PostResult | PostError> {
    if (input.lines.length === 0) {
      return { entries: [] };
    }

    const db: Prisma.TransactionClient | typeof prisma = tx ?? prisma;

    // Idempotency: if the same key has been posted before, return the
    // already-posted entries instead of duplicating.
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
      // Sequential — locks must be acquired in deterministic order to
      // avoid deadlocks when posting multi-line documents.
      const sortedLines = [...input.lines].sort((a, b) => a.productId - b.productId);

      for (const line of sortedLines) {
        try {
          const posted = await this.postLine(txClient, input, line);
          if ('error' in posted) throw posted;
          entries.push(posted);
        } catch (err) {
          // Idempotency unique-violation: another concurrent post won
          // the race. Fall back to returning the existing rows for this
          // idempotency key.
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
      if (tx) {
        return await runPosting(tx);
      }
      return await prisma.$transaction(runPosting);
    } catch (err) {
      if (err && typeof err === 'object' && 'error' in err) return err as PostError;
      throw err;
    }
  }

  /// Reverse a previously-posted entry. Restores cost-layer state for
  /// OUT reversals and refuses IN reversals if the layer has been
  /// (partially) consumed.
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
          // Reversing an OUT — restore qty to the layers we consumed.
          for (const c of original.costConsumptions) {
            await tx.costLayer.update({
              where: { id: c.layerId },
              data: { qtyRemaining: { increment: Number(c.qtyConsumed) } },
            });
          }
        } else {
          // Reversing an IN — the layer it created must be untouched.
          if (original.costLayer) {
            const layer = original.costLayer;
            if (Number(layer.qtyRemaining) < Number(layer.qtyReceived)) {
              throw { error: 'Reversal not allowed: layer already consumed' as const, layerId: layer.id };
            }
            // Drop the layer entirely.
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
            // Reversal inherits the original row's shopId — guarantees
            // a cross-tenant reverse cannot land in the wrong ledger.
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

  // ─────────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────────

  private async postLine(
    tx: Prisma.TransactionClient,
    parent: PostInput,
    line: PostLineInput,
  ): Promise<PostedEntry | PostError> {
    const product = await this.lockProduct(tx, line.productId, parent.shopId);
    if (!product) return { error: 'Product not found', productId: line.productId };

    // Inactive products can only receive OPENING/RECOUNT writes from the
    // reconciliation path — anything else (sales, purchases, damage, etc.)
    // should be impossible because the product was archived. RECOUNT is
    // allowed both ways so admins can correct counts before re-activating.
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
      // OUT — consume layers FIFO.
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

  /// Locks the product row using SELECT … FOR UPDATE so concurrent
  /// postings serialize. Returns null if the product doesn't exist OR
  /// doesn't belong to the requesting shop — that null bubbles back as
  /// a "Product not found" error to the caller, which is the right
  /// 404-shaped response for a cross-tenant attempt.
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

  /// Consume `qty` from the oldest cost layers that still have qtyRemaining.
  /// Inserts one cost_consumption row per layer touched, decrements layer
  /// qtyRemaining, and returns the weighted-average unit cost and total
  /// value of the consumption for ledger snapshotting.
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
      if (!layer) break; // out of layers — stock-out exceeds FIFO history (legacy data)

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
      // No layers existed for this product (legacy migration gap).
      return { weightedAvgCost: null, totalValue: null };
    }

    const consumed = qty - remaining;
    return {
      weightedAvgCost: consumed > 0 ? ROUND_COST(totalValue / consumed) : null,
      totalValue: ROUND_VALUE(totalValue),
    };
  }

  /// Replicates the legacy stock service price-mode logic so manual
  /// stock-in flows behave identically.
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

  // ─────────────────────────────────────────────────────────────────
  // Read APIs
  // ─────────────────────────────────────────────────────────────────

  async listForProduct(productId: number, options: { limit: number; skip: number }) {
    const [entries, total] = await Promise.all([
      prisma.stockTransaction.findMany({
        where: { productId },
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        include: {
          vendor: { select: { id: true, name: true } },
          createdBy: { select: { id: true, name: true } },
        },
      }),
      prisma.stockTransaction.count({ where: { productId } }),
    ]);
    return { entries, total };
  }
}

export const ledgerService = new LedgerService();
