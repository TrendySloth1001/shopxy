import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { invoicesService, PosInvoiceError } from '../invoices/invoices.service.js';

export type RefundMode = 'CASH' | 'UPI' | 'CARD' | 'OTHER';

export interface ReturnableLineDto {
  productId: number;
  name: string;
  sku: string;
  unitPrice: number;
  taxPercent: number;
  soldQty: number;
  returnedQty: number;
  returnableQty: number;
}

export interface ReturnableInvoiceDto {
  invoiceId: number;
  invoiceNo: string;
  invoiceDate: Date;
  total: number;
  customerName: string | null;
  lines: ReturnableLineDto[];
}

export interface ReturnResultDto {
  creditNoteId: number;
  creditNoteNo: string;
  refundAmount: number;
  refundMode: RefundMode;
  cashDrawerAdjusted: boolean;
}

export interface CashierError {
  error: string;
}

const num = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : Number(d);

type Db = Prisma.TransactionClient | typeof prisma;

async function returnedQtyByProduct(originalInvoiceId: number, db: Db = prisma): Promise<Map<number, number>> {
  const creditNotes = await db.invoice.findMany({
    where: { originalInvoiceId, documentType: 'CREDIT_NOTE' },
    select: { items: { select: { productId: true, quantity: true } } },
  });
  const map = new Map<number, number>();
  for (const cn of creditNotes) {
    for (const it of cn.items) {
      map.set(it.productId, (map.get(it.productId) ?? 0) + num(it.quantity));
    }
  }
  return map;
}

export async function getReturnable(
  shopId: number,
  invoiceId: number,
): Promise<ReturnableInvoiceDto | CashierError> {
  const invoice = await prisma.invoice.findFirst({
    where: { id: invoiceId, shopId, type: 'SALE' },
    select: {
      id: true,
      invoiceNo: true,
      invoiceDate: true,
      total: true,
      documentType: true,
      status: true,
      customerName: true,
      items: {
        select: { productId: true, productName: true, productSku: true, quantity: true, unitPrice: true, taxPercent: true },
      },
    },
  });
  if (!invoice) return { error: 'Sale not found' };
  if (invoice.documentType === 'CREDIT_NOTE') return { error: 'Cannot return a credit note' };
  if (invoice.status !== 'CONFIRMED') return { error: 'Only a confirmed sale can be returned' };

  const returned = await returnedQtyByProduct(invoiceId);
  const lines: ReturnableLineDto[] = invoice.items.map((it) => {
    const sold = num(it.quantity);
    const prev = returned.get(it.productId) ?? 0;
    return {
      productId: it.productId,
      name: it.productName,
      sku: it.productSku,
      unitPrice: num(it.unitPrice),
      taxPercent: num(it.taxPercent),
      soldQty: sold,
      returnedQty: prev,
      returnableQty: Math.max(0, sold - prev),
    };
  });
  return {
    invoiceId: invoice.id,
    invoiceNo: invoice.invoiceNo,
    invoiceDate: invoice.invoiceDate,
    total: num(invoice.total),
    customerName: invoice.customerName,
    lines,
  };
}

export async function returnSale(
  shopId: number,
  userId: number,
  input: {
    originalInvoiceId: number;
    lines: Array<{ productId: number; quantity: number }>;
    refundMode: RefundMode;
  },
): Promise<ReturnResultDto | CashierError> {
  if (input.lines.length === 0) return { error: 'Select at least one item to return' };

  const original = await prisma.invoice.findFirst({
    where: { id: input.originalInvoiceId, shopId, type: 'SALE' },
    select: {
      id: true,
      documentType: true,
      status: true,
      partyId: true,
      customerName: true,
      customerPhone: true,
      placeOfSupplyStateCode: true,
      items: { select: { productId: true, quantity: true, unitPrice: true, discount: true, taxPercent: true, cessRate: true } },
    },
  });
  if (!original) return { error: 'Sale not found' };
  if (original.documentType === 'CREDIT_NOTE') return { error: 'Cannot return a credit note' };
  if (original.status !== 'CONFIRMED') return { error: 'Only a confirmed sale can be returned' };

  const byProduct = new Map(original.items.map((it) => [it.productId, it]));

  try {
    const result = await prisma.$transaction(async (tx) => {
      const returned = await returnedQtyByProduct(original.id, tx);
      const items: Array<{ productId: number; quantity: number; unitPrice: number; discount: number; taxPercent: number; cessRate: number }> = [];
      for (const req of input.lines) {
        if (req.quantity <= 0) throw new PosInvoiceError('Return quantity must be positive');
        const orig = byProduct.get(req.productId);
        if (!orig) throw new PosInvoiceError('Item was not on the original sale');
        const sold = num(orig.quantity);
        const already = returned.get(req.productId) ?? 0;
        if (req.quantity > sold - already) {
          throw new PosInvoiceError(`Cannot return more than sold (max ${sold - already} for one item)`);
        }
        const proportion = req.quantity / sold;
        items.push({
          productId: req.productId,
          quantity: req.quantity,
          unitPrice: num(orig.unitPrice),
          discount: num(orig.discount) * proportion,
          taxPercent: num(orig.taxPercent),
          cessRate: num(orig.cessRate),
        });
      }

      const shift = await tx.cashierShift.findFirst({
        where: { shopId, openedById: userId, status: 'OPEN' },
        orderBy: { id: 'desc' },
        select: { id: true },
      });
      if (input.refundMode === 'CASH' && !shift) {
        throw new PosInvoiceError('Open a shift to issue a cash refund');
      }

      const creditNote = await invoicesService.createSalesReturnInTx(
        tx,
        {
          shopId,
          type: 'SALE',
          originalInvoiceId: original.id,
          partyId: original.partyId ?? undefined,
          customerName: original.customerName ?? undefined,
          customerPhone: original.customerPhone ?? undefined,
          placeOfSupplyStateCode: original.placeOfSupplyStateCode ?? undefined,
          items,
        },
        userId,
        shift?.id,
      );

      let cashDrawerAdjusted = false;
      if (input.refundMode === 'CASH' && shift) {
        await tx.cashMovement.create({
          data: {
            shopId,
            shiftId: shift.id,
            type: 'REFUND',
            amount: creditNote.total,
            reason: `Refund · credit note ${creditNote.invoiceNo}`,
            createdById: userId,
          },
        });
        cashDrawerAdjusted = true;
      }

      return {
        creditNoteId: creditNote.id,
        creditNoteNo: creditNote.invoiceNo,
        refundAmount: num(creditNote.total),
        cashDrawerAdjusted,
      };
    }, { isolationLevel: 'Serializable' });

    return { ...result, refundMode: input.refundMode };
  } catch (e) {
    if (e instanceof PosInvoiceError) return { error: e.message };
    if ((e as { code?: string }).code === 'P2034') {
      return { error: 'Another return for this sale is in progress — please retry.' };
    }
    throw e;
  }
}
