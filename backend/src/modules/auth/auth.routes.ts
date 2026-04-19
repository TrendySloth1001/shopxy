import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import { register, login, refresh, logout, getMe, changePassword } from './auth.controller.js';

const router = Router();

// Public — no token needed
router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.post('/refresh', asyncHandler(refresh));
router.post('/logout', asyncHandler(logout));

// Protected — token required
router.get('/me', requireAuth, asyncHandler(getMe));
router.post('/change-password', requireAuth, asyncHandler(changePassword));

export default router;
