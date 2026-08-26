import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { homeService } from './home.service.js';

function parseId(raw: string | undefined): number | null {
  return decodeId(raw);
}

export class HomeController {
  async feed(_req: Request, res: Response): Promise<void> {
    const data = await homeService.getFeed();
    res.json(data);
  }

  async categoryRail(req: Request, res: Response): Promise<void> {
    const id = parseId(req.query.categoryId as string | undefined);
    if (!id) {
      res.status(400).json({ error: 'categoryId required' });
      return;
    }
    const takeRaw = req.query.take ? Number(req.query.take) : 10;
    const take = Number.isInteger(takeRaw) ? Math.min(50, Math.max(1, takeRaw)) : 10;
    const data = await homeService.getCategoryRail(id, take);
    res.json({ data });
  }

  async personalized(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const data = await homeService.getPersonalized(userId);
    res.json(data);
  }

  async endlessPage(req: Request, res: Response): Promise<void> {
    const seedRaw = Number(req.query.seed);
    const seed = Number.isFinite(seedRaw) && seedRaw > 0
      ? Math.floor(seedRaw)
      : Math.floor(Math.random() * 2_000_000_000);
    const pageRaw = Number(req.query.page);
    const page = Number.isFinite(pageRaw) && pageRaw >= 0 ? Math.floor(pageRaw) : 0;
    const limitRaw = Number(req.query.limit);
    const limit = Number.isFinite(limitRaw) ? Math.min(40, Math.max(4, Math.floor(limitRaw))) : 16;
    const viewerUserId = req.user?.sub;

    const data = await homeService.getEndlessPage({ seed, page, limit, viewerUserId });

    if (viewerUserId) {
      res.setHeader('Cache-Control', 'private, max-age=30');
    } else {
      res.setHeader(
        'Cache-Control',
        'public, max-age=60, s-maxage=300, stale-while-revalidate=600',
      );
    }
    res.setHeader('Vary', 'Authorization');

    res.json({ ...data, seed });
  }
}

export const homeController = new HomeController();
