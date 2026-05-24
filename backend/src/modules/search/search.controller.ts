import { Request, Response } from 'express';
import { z } from 'zod';
import { searchService } from './search.service.js';

const searchSchema = z.object({
  q: z.string().min(1).max(80),
  filters: z
    .object({
      categoryId: z.number().int().positive().nullable().optional(),
      shopId: z.number().int().positive().nullable().optional(),
    })
    .optional(),
  sessionId: z.string().max(80).optional(),
});

export class SearchController {
  /// POST /search — body { q, filters?, sessionId? }
  /// Public endpoint; userId is taken from the JWT when present so
  /// unauthenticated visitors still get results and contribute to
  /// SearchEvent stats (just without user attribution).
  async search(req: Request, res: Response): Promise<void> {
    const payload = searchSchema.parse(req.body);
    const result = await searchService.search(
      payload.q,
      {
        categoryId: payload.filters?.categoryId ?? null,
        shopId: payload.filters?.shopId ?? null,
      },
      {
        userId: req.user?.sub ?? null,
        sessionId: payload.sessionId ?? null,
      },
    );
    res.json(result);
  }

  /// GET /search/autocomplete?q=…
  async autocomplete(req: Request, res: Response): Promise<void> {
    const q = (req.query.q as string | undefined) ?? '';
    const result = await searchService.autocomplete(q);
    res.json(result);
  }

  /// GET /search/hints — top trending terms last 24h.
  async hints(_req: Request, res: Response): Promise<void> {
    const data = await searchService.listHints();
    res.json({ data });
  }
}

export const searchController = new SearchController();
