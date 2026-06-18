import { WebSocket } from 'ws';
import { z } from 'zod';
import * as pos from './pos.service.js';
import type { WsAuthCtx } from '../scan-console/scan-console.service.js';
import { hasRight, manageRight } from '../../shared/http/permissions.js';
import { logger } from '../../shared/logging/logger.js';

/// POS over WebSocket — the till sends `{ t:'cmd', reqId, op, saleId?, … }` and
/// gets back `{ t:'res', reqId, ok, data | error }`. The socket is already
/// authed (ticket → shopId/userId/perms); cart-change broadcasts to the other
/// tills are emitted by pos.service via the SaleBus. Functional, no classes.

const TENDER_MODES = ['CASH', 'UPI', 'CARD', 'NEFT', 'RTGS', 'CHEQUE', 'OTHER'] as const;

// ── command arg schemas ──────────────────────────────────────────────────────
const qty = z.number().positive().max(100_000);
const opId = z.string().trim().min(1).max(64).optional();
const saleId = z.number().int().positive();

const schemas = {
  open: z.object({ partyId: z.number().int().positive().optional(), customerName: z.string().trim().max(120).optional(), customerPhone: z.string().trim().max(20).optional() }),
  snapshot: z.object({ saleId }),
  listOpen: z.object({}),
  scan: z.object({ saleId, code: z.string().trim().min(1).max(128), opId }),
  addItem: z.object({ saleId, productId: z.number().int().positive(), quantity: qty.default(1), opId }),
  setQty: z.object({ saleId, productId: z.number().int().positive(), quantity: z.number().min(0).max(100_000) }),
  setLineDiscount: z.object({ saleId, productId: z.number().int().positive(), discount: z.number().min(0) }),
  setUnitPrice: z.object({ saleId, productId: z.number().int().positive(), unitPrice: z.number().min(0) }),
  removeLine: z.object({ saleId, productId: z.number().int().positive() }),
  setHeaderDiscount: z.object({ saleId, discount: z.number().min(0) }),
  quickAdd: z.object({
    saleId,
    code: z.string().trim().min(1).max(128),
    name: z.string().trim().min(1).max(200),
    sellingPrice: z.number().positive().max(10_000_000),
    costPrice: z.number().positive().optional(),
    taxPercent: z.number().min(0).max(28).optional(),
    openingStock: z.number().positive().max(1_000_000).optional(),
  }),
  checkout: z.object({
    saleId,
    tender: z.object({ mode: z.enum(TENDER_MODES), modeReference: z.string().trim().max(120).optional() }),
    customer: z.object({ name: z.string().trim().max(120).optional(), phone: z.string().trim().max(20).optional() }).optional(),
  }),
  void: z.object({ saleId }),
} as const;

function send(ws: WebSocket, payload: Record<string, unknown>): void {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}

const isError = (r: unknown): r is { error: string; detail?: unknown } =>
  typeof r === 'object' && r !== null && 'error' in r && typeof (r as { error?: unknown }).error === 'string';

/// Run a service call and reply with its result (or its `{error}`) under reqId.
async function reply(ws: WebSocket, reqId: string, run: () => Promise<unknown>): Promise<void> {
  try {
    const data = await run();
    if (isError(data)) {
      send(ws, { t: 'res', reqId, ok: false, error: data.error, detail: data.detail });
    } else {
      send(ws, { t: 'res', reqId, ok: true, data });
    }
  } catch (e) {
    logger.warn({ err: e }, 'pos.ws: command failed');
    send(ws, { t: 'res', reqId, ok: false, error: 'Something went wrong. Please retry.' });
  }
}

export function handlePosCommand(ws: WebSocket, ctx: WsAuthCtx, msg: Record<string, unknown>): void {
  const reqId = typeof msg.reqId === 'string' ? msg.reqId : null;
  const op = typeof msg.op === 'string' ? msg.op : null;
  if (!reqId || !op || !(op in schemas)) return;
  const { shopId, userId } = ctx;

  const parsed = schemas[op as keyof typeof schemas].safeParse(msg);
  if (!parsed.success) {
    send(ws, { t: 'res', reqId, ok: false, error: 'Invalid command' });
    return;
  }
  const a = parsed.data as Record<string, never> & { [k: string]: number & string };

  switch (op) {
    case 'open':
      void reply(ws, reqId, () => pos.openSale(shopId, userId, parsed.data as object));
      return;
    case 'snapshot':
      void reply(ws, reqId, () => pos.snapshot(shopId, a.saleId));
      return;
    case 'listOpen':
      void reply(ws, reqId, () => pos.listOpenSales(shopId));
      return;
    case 'scan':
      void reply(ws, reqId, () => pos.addScan(shopId, a.saleId, a.code, userId, a.opId));
      return;
    case 'addItem':
      void reply(ws, reqId, () => pos.addProduct(shopId, a.saleId, a.productId, a.quantity, userId, a.opId));
      return;
    case 'setQty':
      void reply(ws, reqId, () => pos.setQty(shopId, a.saleId, a.productId, a.quantity));
      return;
    case 'setLineDiscount':
      void reply(ws, reqId, () => pos.setLineDiscount(shopId, a.saleId, a.productId, a.discount));
      return;
    case 'setUnitPrice':
      void reply(ws, reqId, () => pos.setUnitPrice(shopId, a.saleId, a.productId, a.unitPrice));
      return;
    case 'removeLine':
      void reply(ws, reqId, () => pos.removeLine(shopId, a.saleId, a.productId));
      return;
    case 'setHeaderDiscount':
      void reply(ws, reqId, () => pos.setHeaderDiscount(shopId, a.saleId, a.discount));
      return;
    case 'quickAdd':
      // Creating catalogue is products:manage — beyond the POS area's invoices gate.
      if (!hasRight(ctx.shopRole as never, ctx.permissions, manageRight('products'))) {
        send(ws, { t: 'res', reqId, ok: false, error: 'You need product management access to add new products' });
        return;
      }
      void reply(ws, reqId, () =>
        pos.quickAddProduct(shopId, a.saleId, parsed.data as Parameters<typeof pos.quickAddProduct>[2], userId),
      );
      return;
    case 'checkout':
      void reply(ws, reqId, () =>
        pos.checkout(shopId, a.saleId, parsed.data as Parameters<typeof pos.checkout>[2], userId),
      );
      return;
    case 'void':
      void reply(ws, reqId, () => pos.voidSale(shopId, a.saleId));
      return;
  }
}
