import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { bannersController } from './banners.controller.js';

/// Public read — mounted before requireAuth in app.ts. Anyone can fetch
/// active banners for a placement (the customer app calls this from the
/// home feed before login is required).
export const bannersPublicRouter = Router();
bannersPublicRouter.get(
  '/',
  asyncHandler(bannersController.listPublic.bind(bannersController)),
);
// Public slide-detail — banner + curated product list with computed
// sale prices. Used by the customer carousel tap target.
bannersPublicRouter.get(
  '/:id/slide',
  asyncHandler(bannersController.getPublicSlide.bind(bannersController)),
);

/// Admin CRUD — mounted under /admin/banners with requirePlatformAdmin
/// guard. List/get exposes full schedule + active state; create/update
/// validate CTA target + colors via zod schemas in the controller.
export const bannersAdminRouter = Router();
bannersAdminRouter.get(
  '/',
  asyncHandler(bannersController.listAdmin.bind(bannersController)),
);
bannersAdminRouter.get(
  '/:id',
  asyncHandler(bannersController.getOne.bind(bannersController)),
);
bannersAdminRouter.post(
  '/',
  asyncHandler(bannersController.create.bind(bannersController)),
);
bannersAdminRouter.patch(
  '/:id',
  asyncHandler(bannersController.update.bind(bannersController)),
);
bannersAdminRouter.delete(
  '/:id',
  asyncHandler(bannersController.delete.bind(bannersController)),
);

/// Merchant CRUD — mounted under /me/banners with requireAuth +
/// requireRole(OWNER) + resolveShop. Phase 7: writes are deprecated;
/// new merchant flows use /me/carousels/:cid/slides which validates
/// carousel ownership before any DB mutation. The GET endpoints stay
/// as a read-only shim so older client builds keep listing the
/// merchant's slides (sorted oldest-first across all their carousels)
/// without breaking on missing endpoints. Writes return 410 GONE with
/// a Location header pointing at the new surface.
export const bannersMerchantRouter = Router();
bannersMerchantRouter.get(
  '/',
  asyncHandler(bannersController.listForShop.bind(bannersController)),
);
bannersMerchantRouter.get(
  '/:id',
  asyncHandler(bannersController.getOneForShop.bind(bannersController)),
);

function gone(req: import('express').Request, res: import('express').Response) {
  res
    .status(410)
    .set('Location', '/me/carousels')
    .json({
      error:
        'POST/PATCH/DELETE on /me/banners is deprecated. Use ' +
        '/me/carousels/:carouselId/slides instead.',
    });
}

bannersMerchantRouter.post('/', gone);
bannersMerchantRouter.patch('/:id', gone);
bannersMerchantRouter.delete('/:id', gone);

// Per-slide linked-product CRUD stays on this surface for now — the
// new slide editor doesn't ship its own product picker yet, so the
// legacy /me/banners/:id/products PUT is still the canonical write
// for the BannerProduct join table. Lifting it onto /me/carousels is
// a follow-up; until then keeping these wired here avoids losing the
// feature entirely. Ownership is enforced server-side via shopId.
bannersMerchantRouter.get(
  '/:id/products',
  asyncHandler(
    bannersController.listProductsForShopBanner.bind(bannersController),
  ),
);
bannersMerchantRouter.put(
  '/:id/products',
  asyncHandler(
    bannersController.replaceProductsForShopBanner.bind(bannersController),
  ),
);
