import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { reviewsController } from './reviews.controller.js';

/// Public listing — mounted under /products/:id/reviews without auth.
/// Anyone can read reviews on marketplace products.
export const reviewsPublicRouter = Router({ mergeParams: true });
reviewsPublicRouter.get('/', asyncHandler(reviewsController.list.bind(reviewsController)));

/// Authenticated write surface — mounted under the same path with
/// requireAuth in front. Writes are gated by the per-product purchase
/// check inside the service (see canReview), so any logged-in user
/// can hit the endpoint but only buyers' calls succeed.
export const reviewsAuthRouter = Router({ mergeParams: true });
reviewsAuthRouter.use(requireAuth);
reviewsAuthRouter.post('/', asyncHandler(reviewsController.upsert.bind(reviewsController)));
reviewsAuthRouter.delete('/mine', asyncHandler(reviewsController.deleteOwn.bind(reviewsController)));
