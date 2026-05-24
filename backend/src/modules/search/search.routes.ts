import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { searchController } from './search.controller.js';

/// Public search surfaces. Mounted before requireAuth so the customer
/// shell works pre-login. The service still attributes searches to a
/// userId when the JWT is present (req.user populated by an earlier
/// optional-auth pass would be nice here, but for now we simply read
/// req.user if it happens to be set — see search.service `actor`).
const router = Router();
router.post('/', asyncHandler(searchController.search.bind(searchController)));
router.get(
  '/autocomplete',
  asyncHandler(searchController.autocomplete.bind(searchController)),
);
router.get(
  '/hints',
  asyncHandler(searchController.hints.bind(searchController)),
);

export default router;
