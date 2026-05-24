import { Request, Response } from 'express';
import { homeService } from './home.service.js';

function parseId(raw: string | undefined): number | null {
  if (!raw) return null;
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
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
}

export const homeController = new HomeController();
