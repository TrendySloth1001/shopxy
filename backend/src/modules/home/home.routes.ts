import { Router } from 'express';
import { homeController } from './home.controller.js';
import asyncHandler from '../../shared/http/asyncHandler.js';

/// Public home-feed routes — no auth required. Mounted before the
/// global requireAuth gate so the customer app can prime the page
/// even before a user logs in.
export const homePublicRouter = Router();

homePublicRouter.get('/feed', asyncHandler(homeController.feed.bind(homeController)));
homePublicRouter.get(
  '/category-rail',
  asyncHandler(homeController.categoryRail.bind(homeController)),
);

/// Auth-only — returns the caller's recently-viewed list and their
/// for-you recommendations. Mounted after the requireAuth middleware.
export const homePersonalRouter = Router();

homePersonalRouter.get(
  '/personalized',
  asyncHandler(homeController.personalized.bind(homeController)),
);
