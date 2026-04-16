import { Request, Response } from 'express';
import { dashboardService } from './dashboard.service.js';

export class DashboardController {
  async stats(_req: Request, res: Response): Promise<void> {
    const stats = await dashboardService.getStats();
    res.json(stats);
  }
}

export const dashboardController = new DashboardController();
