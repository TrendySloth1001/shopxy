import { Request, Response } from 'express';
import { z } from 'zod';
import { reviewsService } from './reviews.service.js';

const upsertReviewSchema = z.object({
  rating: z.number().int().min(1).max(5),
  title: z.string().max(120).optional(),
  body: z.string().max(2000).optional(),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class ReviewsController {
  /// POST /products/:id/reviews — auth required (customer).
  async upsert(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.id);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const payload = upsertReviewSchema.parse(req.body);
    const result = await reviewsService.upsertReview({
      userId: req.user!.sub,
      productId,
      rating: payload.rating,
      title: payload.title,
      body: payload.body,
    });
    if ('error' in result) {
      if (result.error === 'not_purchased') {
        res.status(403).json({
          error: 'Only buyers who purchased this product can leave a review',
        });
        return;
      }
      res.status(400).json({ error: 'Rating must be between 1 and 5' });
      return;
    }
    res.status(200).json(result.review);
  }

  /// DELETE /products/:id/reviews/mine — caller removes their own review.
  async deleteOwn(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.id);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const result = await reviewsService.deleteOwnReview(req.user!.sub, productId);
    if (!result) {
      res.status(404).json({ error: 'No review to delete' });
      return;
    }
    res.status(204).send();
  }

  /// GET /products/:id/reviews — public.
  async list(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.id);
    if (!productId) {
      res.status(400).json({ error: 'Invalid product id' });
      return;
    }
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const result = await reviewsService.listForProduct(productId, {
      cursor: Number.isInteger(cursor) ? cursor : undefined,
      limit,
    });
    res.json(result);
  }
}

export const reviewsController = new ReviewsController();
