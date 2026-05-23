import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import {
  register,
  login,
  refresh,
  logout,
  getMe,
  updateProfile,
  changePassword,
  exportData,
  deleteAccount,
} from './auth.controller.js';

const router = Router();

// Public — no token needed
router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.post('/refresh', asyncHandler(refresh));
router.post('/logout', asyncHandler(logout));

// Protected — token required
router.get('/me', requireAuth, asyncHandler(getMe));
router.patch('/me', requireAuth, asyncHandler(updateProfile));
router.post('/change-password', requireAuth, asyncHandler(changePassword));

// DPDP §11/§12 — data portability + erasure.
router.get('/me/export', requireAuth, asyncHandler(exportData));
router.delete('/me', requireAuth, asyncHandler(deleteAccount));

export default router;
