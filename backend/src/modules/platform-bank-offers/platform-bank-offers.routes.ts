import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { platformBankOffersController } from './platform-bank-offers.controller.js';

/// Admin CRUD — mounted under `/admin/platform-bank-offers` with
/// `requirePlatformAdmin` upstream. Bank offers are platform-scope by
/// definition (Amazon-style central tie-ups), so there's no merchant
/// router. PDP read goes through the existing marketplace detail DTO
/// which calls `platformBankOffersService.listEligibleForProduct()`
/// directly — no dedicated public route needed.
export const platformBankOffersAdminRouter = Router();

platformBankOffersAdminRouter.get(
  '/',
  asyncHandler(
    platformBankOffersController.listAdmin.bind(
      platformBankOffersController,
    ),
  ),
);
platformBankOffersAdminRouter.get(
  '/:id',
  asyncHandler(
    platformBankOffersController.getOne.bind(platformBankOffersController),
  ),
);
platformBankOffersAdminRouter.post(
  '/',
  asyncHandler(
    platformBankOffersController.create.bind(platformBankOffersController),
  ),
);
platformBankOffersAdminRouter.patch(
  '/:id',
  asyncHandler(
    platformBankOffersController.update.bind(platformBankOffersController),
  ),
);
platformBankOffersAdminRouter.delete(
  '/:id',
  asyncHandler(
    platformBankOffersController.deactivate.bind(
      platformBankOffersController,
    ),
  ),
);
