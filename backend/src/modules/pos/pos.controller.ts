import { Request, Response } from 'express';
import { issueScanTicket } from '../scan-console/scan-console.service.js';

/// The POS is driven entirely over the WebSocket (see pos.ws.ts). The only REST
/// endpoint is the ticket mint that bootstraps the socket — it carries the
/// caller's shopId + role + permissions so WS commands can be authorised
/// (e.g. quick-add still needs products:manage). Cookie/Bearer-authed via the
/// /me/pos mount (invoices area), so req.shopId/req.user are set.
export const posController = {
  ticket(req: Request, res: Response): void {
    const token = issueScanTicket(req.shopId!, req.user!.sub, Date.now(), {
      shopRole: req.user!.shopRole,
      permissions: req.user!.shopPermissions,
    });
    res.json({ ticket: token, path: '/ws/scan-console', expiresInMs: 30_000 });
  },
};
