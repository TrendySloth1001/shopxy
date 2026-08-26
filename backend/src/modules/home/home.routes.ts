import { Router } from 'express';
import { homeController } from './home.controller.js';
import asyncHandler from '../../shared/http/asyncHandler.js';

export const homePublicRouter = Router();

homePublicRouter.get('/feed', asyncHandler(homeController.feed.bind(homeController)));
homePublicRouter.get(
  '/feed/page',
  asyncHandler(homeController.endlessPage.bind(homeController)),
);
homePublicRouter.get(
  '/category-rail',
  asyncHandler(homeController.categoryRail.bind(homeController)),
);

export const homePersonalRouter = Router();

homePersonalRouter.get(
  '/personalized',
  asyncHandler(homeController.personalized.bind(homeController)),
);
