import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { searchController } from './search.controller.js';

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
