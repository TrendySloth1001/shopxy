import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { reviewsController } from './reviews.controller.js';

export const reviewsPublicRouter = Router({ mergeParams: true });
reviewsPublicRouter.get('/summary', asyncHandler(reviewsController.summary.bind(reviewsController)));
reviewsPublicRouter.get('/', asyncHandler(reviewsController.list.bind(reviewsController)));

export const reviewsAuthRouter = Router({ mergeParams: true });
reviewsAuthRouter.use(requireAuth);
reviewsAuthRouter.post('/', asyncHandler(reviewsController.upsert.bind(reviewsController)));
reviewsAuthRouter.delete('/mine', asyncHandler(reviewsController.deleteOwn.bind(reviewsController)));

export const myReviewsRouter = Router();
myReviewsRouter.use(requireAuth);
myReviewsRouter.get('/', asyncHandler(reviewsController.listMine.bind(reviewsController)));
