import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { trendingController } from './trending.controller.js';

/// Public trending — mounted before requireAuth so the home feed
/// works for both logged-in and not-yet-logged-in surfaces.
export const trendingPublicRouter = Router();
trendingPublicRouter.get(
  '/trending',
  asyncHandler(trendingController.listTrending.bind(trendingController)),
);

/// Per-user recommendations — auth-required. Cache → trending fallback
/// for cold-start users handled inside the service.
export const recommendationsRouter = Router();
recommendationsRouter.get(
  '/recommended',
  asyncHandler(trendingController.listRecommendations.bind(trendingController)),
);
