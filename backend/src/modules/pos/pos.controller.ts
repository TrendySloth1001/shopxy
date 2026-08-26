import { Request, Response } from 'express';
import { issueScanTicket } from '../scan-console/scan-console.service.js';

export const posController = {
  ticket(req: Request, res: Response): void {
    const token = issueScanTicket(req.shopId!, req.user!.sub, Date.now(), {
      shopRole: req.user!.shopRole,
      permissions: req.user!.shopPermissions,
    });
    res.json({ ticket: token, path: '/ws/scan-console', expiresInMs: 30_000 });
  },
};
