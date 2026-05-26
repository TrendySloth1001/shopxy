import { Request, Response } from 'express';
import { walletService } from './wallet.service.js';

export class WalletController {
  /// GET /me/wallet → { balance, entries: [...] }
  async snapshot(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const data = await walletService.snapshot(userId);
    res.json(data);
  }
}

export const walletController = new WalletController();
