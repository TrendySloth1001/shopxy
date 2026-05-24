import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { collectionsController } from './collections.controller.js';

/// Public read — mounted before requireAuth at /collections.
export const collectionsPublicRouter = Router();
collectionsPublicRouter.get(
  '/',
  asyncHandler(collectionsController.listPublic.bind(collectionsController)),
);
collectionsPublicRouter.get(
  '/:slug',
  asyncHandler(collectionsController.getPublic.bind(collectionsController)),
);

/// Admin CRUD — mounted under /admin/collections with requirePlatformAdmin.
export const collectionsAdminRouter = Router();
collectionsAdminRouter.get(
  '/_search/products',
  asyncHandler(collectionsController.searchProducts.bind(collectionsController)),
);
collectionsAdminRouter.get(
  '/',
  asyncHandler(collectionsController.listAdmin.bind(collectionsController)),
);
collectionsAdminRouter.get(
  '/:id',
  asyncHandler(collectionsController.getAdmin.bind(collectionsController)),
);
collectionsAdminRouter.post(
  '/',
  asyncHandler(collectionsController.create.bind(collectionsController)),
);
collectionsAdminRouter.patch(
  '/:id',
  asyncHandler(collectionsController.update.bind(collectionsController)),
);
collectionsAdminRouter.delete(
  '/:id',
  asyncHandler(collectionsController.delete.bind(collectionsController)),
);
collectionsAdminRouter.put(
  '/:id/items',
  asyncHandler(collectionsController.replaceItems.bind(collectionsController)),
);
