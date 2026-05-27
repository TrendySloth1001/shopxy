import { Request, Response } from 'express';
import { marketplaceService } from './marketplace.service.js';

/// Returns the parsed number, undefined when the value is absent, or
/// null when the value is present but malformed. The three-state
/// return keeps the controller's "invalid filter" check terse — null
/// short-circuits to a 400 while undefined drops through as "not set".
function parseOptionalNumber(raw: unknown): number | undefined | null {
  if (raw === undefined || raw === '') return undefined;
  const n = Number(raw);
  if (!Number.isFinite(n)) return null;
  return n;
}

/// Accepts `?shopIds=1,2,3` (CSV string) or `?shopIds=1&shopIds=2`
/// (express array). Empty list = undefined (no filter); any non-int
/// entry returns null so the controller can 400.
function parseShopIds(raw: unknown): number[] | undefined | null {
  if (raw === undefined || raw === '') return undefined;
  const tokens = Array.isArray(raw)
    ? raw.flatMap((v) => String(v).split(','))
    : String(raw).split(',');
  const ids: number[] = [];
  for (const t of tokens) {
    const trimmed = t.trim();
    if (!trimmed) continue;
    const n = Number(trimmed);
    if (!Number.isInteger(n) || n <= 0) return null;
    ids.push(n);
  }
  return ids.length > 0 ? ids : undefined;
}

export class MarketplaceController {
  async getProduct(req: Request, res: Response): Promise<void> {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const product = await marketplaceService.getPublicProduct(id, req.user?.sub);
    if (!product) {
      res.status(404).json({ error: 'Product not found' });
      return;
    }
    res.json(product);
  }

  /// GET /marketplace/products/:id/frequently-bought-together
  /// Returns up to 5 slim product cards. Empty array (not 404) when no
  /// cohort exists — the rail's empty state just renders nothing.
  async getFbt(req: Request, res: Response): Promise<void> {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const data = await marketplaceService.getFrequentlyBoughtTogether(
      id,
      req.user?.sub,
    );
    res.json({ data });
  }

  async listShopProducts(req: Request, res: Response): Promise<void> {
    const slug = String(req.params.slug || '').toLowerCase();
    if (!/^[a-z0-9-]{1,80}$/.test(slug)) {
      res.status(400).json({ error: 'Invalid slug' });
      return;
    }
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(60, Math.max(1, Number(req.query.limit) || 24));
    const sort = String(req.query.sort || '') as
      | 'popular' | 'newest' | 'price_asc' | 'price_desc' | '';
    const result = await marketplaceService.listShopProducts({
      slug,
      skip: (page - 1) * limit,
      limit,
      sort: sort || 'popular',
      viewerUserId: req.user?.sub,
    });
    if (!result) {
      res.status(404).json({ error: 'Shop not found' });
      return;
    }
    res.json({
      shop: result.shop,
      data: result.data,
      pagination: {
        page, limit, total: result.total,
        pages: Math.max(1, Math.ceil(result.total / limit)),
      },
    });
  }

  async listCategoryProducts(req: Request, res: Response): Promise<void> {
    const slug = String(req.params.slug || '').toLowerCase();
    if (!/^[a-z0-9-]{1,80}$/.test(slug)) {
      res.status(400).json({ error: 'Invalid slug' });
      return;
    }
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(60, Math.max(1, Number(req.query.limit) || 24));
    const sort = String(req.query.sort || '') as
      | 'popular' | 'newest' | 'price_asc' | 'price_desc' | '';

    // Filter axes — every numeric input is bounded server-side, and a
    // single bad value returns 400 instead of silently widening the
    // result set (which would be a security/UX surprise).
    const priceMin = parseOptionalNumber(req.query.priceMin);
    const priceMax = parseOptionalNumber(req.query.priceMax);
    const ratingMin = parseOptionalNumber(req.query.ratingMin);
    if (
      (priceMin === null) ||
      (priceMax === null) ||
      (ratingMin === null) ||
      (priceMin !== undefined && priceMin < 0) ||
      (priceMax !== undefined && priceMax < 0) ||
      (ratingMin !== undefined && (ratingMin < 0 || ratingMin > 5))
    ) {
      res.status(400).json({ error: 'Invalid filter value' });
      return;
    }
    const inStock = req.query.inStock === 'true' || req.query.inStock === '1';
    const shopIds = parseShopIds(req.query.shopIds);
    if (shopIds === null) {
      res.status(400).json({ error: 'Invalid shopIds' });
      return;
    }
    const includeFacets =
      req.query.includeFacets === 'true' || req.query.includeFacets === '1';

    const result = await marketplaceService.listCategoryProducts({
      slug,
      skip: (page - 1) * limit,
      limit,
      sort: sort || 'popular',
      viewerUserId: req.user?.sub,
      priceMin,
      priceMax,
      ratingMin,
      inStock,
      shopIds,
      includeFacets,
    });
    if (!result) {
      res.status(404).json({ error: 'Category not found' });
      return;
    }
    res.json({
      category: result.category,
      data: result.data,
      pagination: {
        page, limit, total: result.total,
        pages: Math.max(1, Math.ceil(result.total / limit)),
      },
      ...(result.facets ? { facets: result.facets } : {}),
    });
  }
}

export const marketplaceController = new MarketplaceController();
