import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import {
  register,
  login,
  refresh,
  logout,
  logoutAll,
  getMe,
  updateProfile,
  changePassword,
  exportData,
  deleteAccount,
  previewTeamInvite,
  acceptTeamInvite,
  issueRemember,
  rememberLogin,
  forgetRemember,
  twoFactorStatus,
  twoFactorSetup,
  twoFactorEnable,
  twoFactorDisable,
} from './auth.controller.js';

const router = Router();

// Public — no token needed
router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.post('/refresh', asyncHandler(refresh));
router.post('/logout', asyncHandler(logout));
// Device-remember: one-tap return sign-in for native apps (desktop/Flutter).
// remember-login + forget are public (the device credential IS the auth);
// issuing one requires an active session.
router.post('/remember-login', asyncHandler(rememberLogin));
router.post('/remember/forget', asyncHandler(forgetRemember));
// Staff onboarding via a TEAM invite token — preview + accept-with-signup.
router.get('/team-invite/:token', asyncHandler(previewTeamInvite));
router.post('/accept-invite', asyncHandler(acceptTeamInvite));

// Protected — token required
router.post('/logout-all', requireAuth, asyncHandler(logoutAll));
router.get('/me', requireAuth, asyncHandler(getMe));
router.patch('/me', requireAuth, asyncHandler(updateProfile));
router.post('/change-password', requireAuth, asyncHandler(changePassword));
router.post('/remember', requireAuth, asyncHandler(issueRemember));

// Two-factor auth (TOTP) — all require an active session.
router.get('/2fa/status', requireAuth, asyncHandler(twoFactorStatus));
router.post('/2fa/setup', requireAuth, asyncHandler(twoFactorSetup));
router.post('/2fa/enable', requireAuth, asyncHandler(twoFactorEnable));
router.post('/2fa/disable', requireAuth, asyncHandler(twoFactorDisable));

// DPDP §11/§12 — data portability + erasure.
router.get('/me/export', requireAuth, asyncHandler(exportData));
router.delete('/me', requireAuth, asyncHandler(deleteAccount));

export default router;
