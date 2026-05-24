import { Request, Response } from 'express';
import { marketplaceService } from './marketplace.service.js';

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
    const result = await marketplaceService.listCategoryProducts({
      slug,
      skip: (page - 1) * limit,
      limit,
      sort: sort || 'popular',
      viewerUserId: req.user?.sub,
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
    });
  }
}

export const marketplaceController = new MarketplaceController();
