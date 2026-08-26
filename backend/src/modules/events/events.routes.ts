import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { eventsController } from './events.controller.js';

export const eventsIngestRouter = Router();
eventsIngestRouter.post(
  '/',
  asyncHandler(eventsController.ingest.bind(eventsController)),
);

export const recentlyViewedRouter = Router();
recentlyViewedRouter.get(
  '/',
  asyncHandler(eventsController.listRecentlyViewed.bind(eventsController)),
);
