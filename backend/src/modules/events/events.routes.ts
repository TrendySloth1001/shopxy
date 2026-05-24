import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { eventsController } from './events.controller.js';

/// Customer-side event ingest. Mounted under /v1/events behind
/// requireAuth (we need a user id to attribute activity — anonymous
/// pre-login events aren't accepted yet; sessionId-only ingestion
/// lands in a future phase).
export const eventsIngestRouter = Router();
eventsIngestRouter.post(
  '/',
  asyncHandler(eventsController.ingest.bind(eventsController)),
);

/// Per-user "recently viewed" list — mounted at /me/recently-viewed
/// behind requireAuth. Both OWNER and CUSTOMER can read their own.
export const recentlyViewedRouter = Router();
recentlyViewedRouter.get(
  '/',
  asyncHandler(eventsController.listRecentlyViewed.bind(eventsController)),
);
