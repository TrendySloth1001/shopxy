import { Request, Response } from 'express';
import { dashboardService, type DashboardPeriod } from './dashboard.service.js';
import { hasRight, viewRight } from '../../shared/http/permissions.js';

const PERIODS: readonly DashboardPeriod[] = ['today', 'week', 'month'];

function parsePeriod(value: unknown): DashboardPeriod {
  return PERIODS.includes(value as DashboardPeriod) ? (value as DashboardPeriod) : 'today';
}

export class DashboardController {
  async stats(req: Request, res: Response): Promise<void> {
    // Money sections (KPIs, trend, insights, GST, payables) require reports:view
    // — a teammate granted the dashboard but not reports gets the operational
    // view without the financials.
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
}

export const dashboardController = new DashboardController();
