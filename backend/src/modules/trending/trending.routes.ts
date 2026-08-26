import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { trendingController } from './trending.controller.js';

export const trendingPublicRouter = Router();
trendingPublicRouter.get(
  '/trending',
  asyncHandler(trendingController.listTrending.bind(trendingController)),
);

export const recommendationsRouter = Router();
recommendationsRouter.get(
  '/recommended',
  asyncHandler(trendingController.listRecommendations.bind(trendingController)),
);
