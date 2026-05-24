import { Request, Response } from 'express';
import { trendingService } from './trending.service.js';

function parseIntOrNull(v: unknown): number | null {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  return Number.isInteger(n) && n > 0 ? n : null;
}

export class TrendingController {
  /// GET /products/trending?categoryId=&limit=
  /// Public — anyone can hit this. categoryId omitted → global bucket.
  async listTrending(req: Request, res: Response): Promise<void> {
    const categoryId = parseIntOrNull(req.query.categoryId);
    const limitRaw = req.query.limit ? Number(req.query.limit) : undefined;
    const take = Number.isInteger(limitRaw) ? (limitRaw as number) : undefined;
    const data = await trendingService.listTrending({ categoryId, take });
    res.json({ data });
  }

  /// GET /products/recommended?slot=for_you
  /// Auth-only. Per-user cache, falls back to trending for cold start.
  async listRecommendations(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const slot = (req.query.slot as string | undefined) ?? 'for_you';
    const data = await trendingService.listRecommendations(userId, slot);
    res.json({ data });
  }
}

export const trendingController = new TrendingController();
