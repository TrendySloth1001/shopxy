import { randomBytes } from 'node:crypto';
import type { Request, Response } from 'express';
import { z } from 'zod';
import { productsService } from '../products/products.service.js';
import {
  issueScanTicket,
  scanConsoleHub,
  type ScanItem,
} from './scan-console.service.js';

const scanBodySchema = z.object({
  // Raw value off the barcode/QR symbol — matched against sku OR barcode.
  code: z.string().trim().min(1).max(128),
});

class ScanConsoleController {
  /**
   * Mint a single-use, short-lived ticket for the web console's WebSocket
   * handshake. Cookie-authed via the BFF; the browser never sees the JWT.
   */
  async ticket(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const userId = req.user!.sub;
    const ticket = issueScanTicket(shopId, userId, Date.now());
    res.json({ ticket, path: '/ws/scan-console', expiresInMs: 30_000 });
  }

  /**
   * Phone publishes a scan. We resolve the code to a product in the caller's
   * shop and fan the resolved item out to every live console for that shop.
   */
  async scan(req: Request, res: Response): Promise<void> {
    const parsed = scanBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'A scanned "code" is required' });
      return;
    }

    const shopId = req.shopId!;
    const product = await productsService.lookupProduct(shopId, parsed.data.code);
    if (!product) {
      res.status(404).json({ error: 'No product matches that code' });
      return;
    }

    const scan: ScanItem = {
      scanId: randomBytes(8).toString('hex'),
      productId: product.id,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode ?? null,
      sellingPrice: product.sellingPrice.toString(),
      mrp: product.mrp != null ? product.mrp.toString() : null,
      imageUrl: product.images[0]?.url ?? null,
      scannedAt: new Date().toISOString(),
      scannedBy: req.user!.sub,
    };

    const consoles = scanConsoleHub.broadcast(shopId, { type: 'scan', scan });
    res.json({ scan, consoles });
  }

  /** Tell every console for this shop to reset its list. */
  async clear(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    scanConsoleHub.broadcast(shopId, { type: 'clear', by: req.user!.sub });
    res.json({ ok: true });
  }
}

export const scanConsoleController = new ScanConsoleController();
