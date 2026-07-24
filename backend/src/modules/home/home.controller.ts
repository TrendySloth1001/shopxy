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

  /// Endless-scroll product page. Public — anonymous sessions just omit
  /// the `seed` and we mint one. Requires no auth header but honours
  /// the optional `viewerUserId` so a signed-in merchant doesn't see
  /// their own shop's products in their for-you stream.
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

    // Cache headers. Anonymous reads are CDN-friendly — the (seed, page,
    // limit) tuple is in the query string, so an upstream cache keys
    // on the full URL. 60s fresh + 10min stale-while-revalidate means
    // a single origin hit per (seed, page) absorbs an entire CDN region.
    //
    // Authenticated reads (viewer-shop filter applied) stay private
    // and short-lived — never share a cached body between two users.
    if (viewerUserId) {
      res.setHeader('Cache-Control', 'private, max-age=30');
    } else {
      res.setHeader(
        'Cache-Control',
        'public, max-age=60, s-maxage=300, stale-while-revalidate=600',
      );
    }
    // Vary on Authorization so caches don't ever serve a private-tagged
    // body to a different signed-in user that happens to share IP / UA.
    res.setHeader('Vary', 'Authorization');

    res.json({ ...data, seed });
  }
}

export const homeController = new HomeController();
