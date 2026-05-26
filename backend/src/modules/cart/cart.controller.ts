import type { Request, Response } from 'express';
import { cartService } from './cart.service.js';

function parseId(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || !Number.isInteger(n)) return null;
  return n;
}

function parseQuantity(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return null;
  return n;
}

export class CartController {
  async list(req: Request, res: Response): Promise<void> {
    const data = await cartService.list(req.user!.sub);
    res.json({ data });
  }

  async setQuantity(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.productId);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const body = (req.body ?? {}) as { quantity?: unknown };
    const quantity = parseQuantity(body.quantity);
    if (quantity === null) {
      res.status(400).json({ error: 'quantity must be a non-negative number' });
      return;
    }

    const result = await cartService.setQuantity(req.user!.sub, productId, quantity);
    if (result && 'error' in result) {
      const status = result.error === 'PRODUCT_NOT_FOUND' ? 404 : 409;
      res.status(status).json({ error: result.error });
      return;
    }
    if (result === null) {
      res.status(204).send();
      return;
    }
    res.json(result);
  }

  async remove(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.productId);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    await cartService.remove(req.user!.sub, productId);
    res.status(204).send();
  }

  async clear(req: Request, res: Response): Promise<void> {
    await cartService.clear(req.user!.sub);
    res.status(204).send();
  }

  async merge(req: Request, res: Response): Promise<void> {
    const body = (req.body ?? {}) as { items?: unknown };
    if (!Array.isArray(body.items)) {
      res.status(400).json({ error: 'items must be an array' });
      return;
    }
    const items: { productId: number; quantity: number }[] = [];
    for (const raw of body.items) {
      if (raw === null || typeof raw !== 'object') continue;
      const row = raw as { productId?: unknown; quantity?: unknown };
      const productId = parseId(String(row.productId ?? ''));
      const quantity = parseQuantity(row.quantity);
      if (productId && quantity !== null && quantity > 0) {
        items.push({ productId, quantity });
      }
    }
    const data = await cartService.merge(req.user!.sub, items);
    res.json({ data });
  }
}

export const cartController = new CartController();
