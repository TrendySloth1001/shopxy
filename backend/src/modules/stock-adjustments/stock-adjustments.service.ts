import prisma from '../../infra/db/prisma.js';
import {
  ADJUSTMENT_REASONS,
  IN_REASON_CODES,
  type LedgerDirection,
  type LedgerReasonCode,
} from '../../shared/constants/index.js';
import { ledgerService } from '../ledger/ledger.service.js';

interface AdjustmentItemInput {
  productId: number;
  quantity: number;
  unitCost?: number;
  note?: string;
}

interface CreateAdjustmentInput {
  reasonCode: LedgerReasonCode;
  direction?: LedgerDirection;
  note?: string;
  items: AdjustmentItemInput[];
  createdById?: number;
}

export class StockAdjustmentsService {
  async create(input: CreateAdjustmentInput) {
    if (!ADJUSTMENT_REASONS.includes(input.reasonCode)) {
      return { error: 'Invalid reason code for adjustment' as const };
    }
    if (input.items.length === 0) {
      return { error: 'Adjustment must have at least one item' as const };
    }

    // Direction defaults: OPENING/RECOUNT can be either side; everything
    // else is an OUT (damage, expired, shrinkage).
    const direction: LedgerDirection =
      input.direction ?? (IN_REASON_CODES.has(input.reasonCode) ? 'IN' : 'OUT');

    const productIds = [...new Set(input.items.map((i) => i.productId))];
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: { id: true, name: true, sku: true, unit: true, purchasePrice: true },
    });
    const productMap = new Map(products.map((p) => [p.id, p]));
    for (const item of input.items) {
      if (!productMap.has(item.productId)) {
        return { error: `Product ${item.productId} not found` as const };
      }
    }

    const adjustmentNo = await this.nextAdjustmentNo();

    // Create header first so we have an id to attach to ledger rows.
    const header = await prisma.stockAdjustment.create({
      data: {
        adjustmentNo,
        reasonCode: input.reasonCode,
        direction,
        note: input.note ?? null,
        createdById: input.createdById,
        items: {
          create: input.items.map((item) => {
            const product = productMap.get(item.productId)!;
            return {
              productId: item.productId,
              productName: product.name,
              productSku: product.sku,
              unit: product.unit,
              quantity: item.quantity,
              unitCost: item.unitCost ?? null,
              note: item.note ?? null,
            };
          }),
        },
      },
      include: { items: true },
    });

    // Post each item to the ledger.
    const result = await ledgerService.post({
      direction,
      reasonCode: input.reasonCode,
      sourceType: 'ADJUSTMENT',
      sourceId: header.id,
      lines: header.items.map((it) => {
        const product = productMap.get(it.productId)!;
        const fallbackCost = Number(product.purchasePrice);
        return {
          productId: it.productId,
          quantity: Number(it.quantity),
          unitPrice:
            direction === 'IN' ? Number(it.unitCost ?? fallbackCost) : undefined,
          sourceLineId: it.id,
          note: it.note ?? undefined,
        };
      }),
      createdById: input.createdById,
      note: input.note ?? undefined,
    });

    if ('error' in result) {
      // Rollback header — keeps the database clean if posting failed.
      await prisma.stockAdjustment.delete({ where: { id: header.id } });
      return result;
    }

    return { adjustment: header, entries: result.entries };
  }

  async list(options: { reasonCode?: string; page: number; limit: number; skip: number }) {
    const where: Record<string, unknown> = {};
    if (options.reasonCode) where.reasonCode = options.reasonCode;
    const [adjustments, total] = await Promise.all([
      prisma.stockAdjustment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.skip,
        take: options.limit,
        include: {
          createdBy: { select: { id: true, name: true } },
          _count: { select: { items: true } },
        },
      }),
      prisma.stockAdjustment.count({ where }),
    ]);
    return { adjustments, total };
  }

  getById(id: number) {
    return prisma.stockAdjustment.findUnique({
      where: { id },
      include: {
        items: { orderBy: { id: 'asc' } },
        createdBy: { select: { id: true, name: true } },
      },
    });
  }

  /// Post a counter-entry for every ledger row this adjustment created.
  /// The adjustment itself stays around as an audit trail; the ledger
  /// effect is what gets unwound.
  async reverse(id: number, opts: { createdById?: number; note?: string } = {}) {
    const adjustment = await prisma.stockAdjustment.findUnique({
      where: { id },
      include: { _count: { select: { items: true } } },
    });
    if (!adjustment) return { error: 'Adjustment not found' as const };

    const entries = await prisma.stockTransaction.findMany({
      where: { sourceType: 'ADJUSTMENT', sourceId: id, reversesId: null },
      select: { id: true, direction: true },
    });
    if (entries.length === 0) {
      return { error: 'Nothing to reverse on this adjustment' as const };
    }

    const reversedEntries: number[] = [];
    for (const entry of entries) {
      const reverseReason: LedgerReasonCode =
        entry.direction === 'OUT' ? 'RETURN_IN' : 'RETURN_OUT';
      const result = await ledgerService.reverse(entry.id, {
        reasonCode: reverseReason,
        sourceType: 'ADJUSTMENT',
        sourceId: id,
        createdById: opts.createdById,
        note: opts.note ?? `Reversal of ${adjustment.adjustmentNo}`,
      });
      if ('error' in result) {
        return { error: `Reversal failed: ${result.error}` as const };
      }
      reversedEntries.push(...result.entries.map((e) => e.id));
    }
    return { adjustmentId: id, reversedEntries };
  }

  private async nextAdjustmentNo(): Promise<string> {
    const count = await prisma.stockAdjustment.count();
    const seq = String(count + 1).padStart(5, '0');
    const ym = new Date().toISOString().slice(0, 7).replace('-', '');
    return `ADJ-${ym}-${seq}`;
  }
}

export const stockAdjustmentsService = new StockAdjustmentsService();
