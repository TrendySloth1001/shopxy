import { Request, Response } from 'express';
import { dashboardService, type DashboardPeriod } from './dashboard.service.js';
import { hasRight, viewRight } from '../../shared/http/permissions.js';

const PERIODS: readonly DashboardPeriod[] = ['today', 'week', 'month'];

function parsePeriod(value: unknown): DashboardPeriod {
  return PERIODS.includes(value as DashboardPeriod) ? (value as DashboardPeriod) : 'today';
}

export class DashboardController {
  async stats(req: Request, res: Response): Promise<void> {
    const includeFinancials = hasRight(
      req.user?.shopRole,
      req.user?.shopPermissions,
      viewRight('reports'),
    );
    const stats = await dashboardService.getStats(req.shopId!, {
      userId: req.user?.sub,
      includeFinancials,
      period: parsePeriod(req.query.period),
    });
    res.json(stats);
  }

  async receivables(req: Request, res: Response): Promise<void> {
    if (!this.canViewFinancials(req)) {
      res.status(403).json({ error: 'You do not have permission to view reports.' });
      return;
    }
    res.json(await dashboardService.receivablesBreakdown(req.shopId!));
  }

  async payables(req: Request, res: Response): Promise<void> {
    if (!this.canViewFinancials(req)) {
      res.status(403).json({ error: 'You do not have permission to view reports.' });
      return;
    }
    res.json(await dashboardService.payablesBreakdown(req.shopId!));
  }

  private canViewFinancials(req: Request): boolean {
    return hasRight(req.user?.shopRole, req.user?.shopPermissions, viewRight('reports'));
  }
}

export const dashboardController = new DashboardController();
