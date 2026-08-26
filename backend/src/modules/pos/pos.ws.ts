import { WebSocket } from 'ws';
import { z } from 'zod';
import * as pos from './pos.service.js';
import * as posPay from './pos.payments.js';
import { openShiftIdFor } from '../cashier/cashier.service.js';
import { verifyOverride, type OverrideOp } from '../cashier/override.js';
import type { WsAuthCtx } from '../scan-console/scan-console.service.js';
import { hasRight, manageRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';
import { resolveMembershipForUser } from '../../shared/http/requireAuth.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { logger } from '../../shared/logging/logger.js';

const TENDER_MODES = ['CASH', 'UPI', 'CARD', 'NEFT', 'RTGS', 'CHEQUE', 'OTHER'] as const;

const SHIFT_CACHE_TTL_MS = 10_000;

const qty = z.number().positive().max(100_000);
const opId = z.string().trim().min(1).max(64).optional();
const saleId = zPublicId;
const productId = zPublicId;

const schemas = {
  open: z.object({ partyId: zPublicId.optional(), customerName: z.string().trim().max(120).optional(), customerPhone: z.string().trim().max(20).optional() }),
  snapshot: z.object({ saleId }),
  listOpen: z.object({}),
  search: z.object({ term: z.string().trim().min(1).max(80) }),
  scan: z.object({ saleId, code: z.string().trim().min(1).max(128), opId, quantity: qty.optional() }),
  addItem: z.object({ saleId, productId, quantity: qty.default(1), opId }),
  setQty: z.object({ saleId, productId, quantity: z.number().min(0).max(100_000) }),
  setLineDiscount: z.object({ saleId, productId, discount: z.number().min(0), override: z.string().optional() }),
  setUnitPrice: z.object({ saleId, productId, unitPrice: z.number().min(0), override: z.string().optional() }),
  removeLine: z.object({ saleId, productId }),
  setHeaderDiscount: z.object({ saleId, discount: z.number().min(0), override: z.string().optional() }),
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
  void: z.object({ saleId, override: z.string().optional() }),
  payOnline: z.object({ saleId }),
  syncOnline: z.object({ saleId }),
  cancelOnline: z.object({ saleId }),
} as const;

function send(ws: WebSocket, payload: Record<string, unknown>): void {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(payload));
}

const isError = (r: unknown): r is { error: string; detail?: unknown } =>
  typeof r === 'object' && r !== null && 'error' in r && typeof (r as { error?: unknown }).error === 'string';

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

  const requireShift = async <T>(run: () => Promise<T>): Promise<T | { error: string }> => {
    const now = Date.now();
    if (ctx._shiftId != null && ctx._shiftCheckedAt != null && now - ctx._shiftCheckedAt < SHIFT_CACHE_TTL_MS) {
      return run();
    }
    const sid = await openShiftIdFor(shopId, userId);
    if (sid == null) {
      ctx._shiftId = null;
      ctx._shiftCheckedAt = undefined;
      return { error: 'Open a shift before you can scan or sell.' };
    }
    ctx._shiftId = sid;
    ctx._shiftCheckedAt = now;
    return run();
  };

  const liveRights = async (): Promise<{ shopRole?: string; permissions: string[] }> => {
    const m = await resolveMembershipForUser(userId);
    if (m && m.shopId === shopId) return { shopRole: m.shopRole, permissions: m.permissions };
    if (m) return { shopRole: undefined, permissions: [] };
    return { shopRole: ctx.shopRole, permissions: ctx.permissions ?? [] };
  };

  const requireOverride = async <T>(
    overrideOp: OverrideOp,
    run: () => Promise<T>,
  ): Promise<T | { error: string; detail: { code: string } }> => {
    const rights = await liveRights();
    if (hasRight(rights.shopRole as never, rights.permissions, POS_OVERRIDE_RIGHT)) return run();
    const grant = typeof msg.override === 'string' ? msg.override : undefined;
    const targetSaleId = a.saleId;
    if (await verifyOverride(grant, shopId, targetSaleId, overrideOp)) return run();
    return { error: 'Manager authorisation required for this action.', detail: { code: 'OVERRIDE_REQUIRED' } };
  };

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
    case 'search':
      void reply(ws, reqId, () => pos.searchProducts(shopId, (parsed.data as { term: string }).term));
      return;
    case 'scan':
      void reply(ws, reqId, () => requireShift(() => pos.addScan(shopId, a.saleId, a.code, userId, a.opId, a.quantity)));
      return;
    case 'addItem':
      void reply(ws, reqId, () => requireShift(() => pos.addProduct(shopId, a.saleId, a.productId, a.quantity, userId, a.opId)));
      return;
    case 'setQty':
      void reply(ws, reqId, () => requireShift(() => pos.setQty(shopId, a.saleId, a.productId, a.quantity)));
      return;
    case 'setLineDiscount':
      void reply(ws, reqId, () => requireShift(() => requireOverride('setLineDiscount', () => pos.setLineDiscount(shopId, a.saleId, a.productId, a.discount))));
      return;
    case 'setUnitPrice':
      void reply(ws, reqId, () => requireShift(() => requireOverride('setUnitPrice', () => pos.setUnitPrice(shopId, a.saleId, a.productId, a.unitPrice))));
      return;
    case 'removeLine':
      void reply(ws, reqId, () => requireShift(() => pos.removeLine(shopId, a.saleId, a.productId)));
      return;
    case 'setHeaderDiscount':
      void reply(ws, reqId, () => requireShift(() => requireOverride('setHeaderDiscount', () => pos.setHeaderDiscount(shopId, a.saleId, a.discount))));
      return;
    case 'quickAdd':
      void reply(ws, reqId, async () => {
        const rights = await liveRights();
        if (!hasRight(rights.shopRole as never, rights.permissions, manageRight('products'))) {
          return { error: 'You need product management access to add new products' };
        }
        return requireShift(() => pos.quickAddProduct(shopId, a.saleId, parsed.data as Parameters<typeof pos.quickAddProduct>[2], userId));
      });
      return;
    case 'checkout':
      void reply(ws, reqId, () =>
        requireShift(() => pos.checkout(shopId, a.saleId, parsed.data as Parameters<typeof pos.checkout>[2], userId)),
      );
      return;
    case 'void':
      void reply(ws, reqId, () => requireShift(() => requireOverride('void', () => pos.voidSale(shopId, a.saleId))));
      return;
    case 'payOnline':
      void reply(ws, reqId, () => requireShift(() => posPay.payOnline(shopId, a.saleId)));
      return;
    case 'syncOnline':
      void reply(ws, reqId, () => posPay.syncOnline(shopId, a.saleId));
      return;
    case 'cancelOnline':
      void reply(ws, reqId, () => posPay.cancelOnline(shopId, a.saleId));
      return;
  }
}
