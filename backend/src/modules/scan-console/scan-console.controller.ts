import type { Request, Response } from 'express';
import { z } from 'zod';
import { issueScanTicket, resolveScan, scanConsoleHub } from './scan-console.service.js';

const scanBodySchema = z.object({
  code: z.string().trim().min(1).max(128),
});

class ScanConsoleController {
  async ticket(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const userId = req.user!.sub;
    const ticket = issueScanTicket(shopId, userId, Date.now());
    res.json({ ticket, path: '/ws/scan-console', expiresInMs: 30_000 });
  }

  async scan(req: Request, res: Response): Promise<void> {
    const parsed = scanBodySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'A scanned "code" is required' });
      return;
    }

    const shopId = req.shopId!;
    const scan = await resolveScan(shopId, parsed.data.code, req.user!.sub);
    if (!scan) {
      res.json({ matched: false });
      return;
    }

    const consoles = scanConsoleHub.broadcast(shopId, { type: 'scan', scan }, { role: 'console' });
    res.json({ matched: true, scan, consoles });
  }

  async clear(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    scanConsoleHub.broadcast(shopId, { type: 'clear', by: req.user!.sub });
    res.json({ ok: true });
  }
}

export const scanConsoleController = new ScanConsoleController();
