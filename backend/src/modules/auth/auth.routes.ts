import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import {
  register,
  verifyEmail,
  resendOtp,
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
  recentLogins,
  listSessions,
  revokeSessionById,
  revokeOtherSessions,
} from './auth.controller.js';

const router = Router();

// Public — no token needed
router.post('/register', asyncHandler(register));
// Email-OTP verification for first-time signup (public — no session yet).
router.post('/verify-email', asyncHandler(verifyEmail));
router.post('/resend-otp', asyncHandler(resendOtp));
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

// Security activity — recent sign-ins (powers new-device awareness in the UI).
router.get('/security/logins', requireAuth, asyncHandler(recentLogins));

// Sessions / devices — see + revoke where the account is signed in.
router.get('/sessions', requireAuth, asyncHandler(listSessions));
router.post('/sessions/revoke-others', requireAuth, asyncHandler(revokeOtherSessions));
router.delete('/sessions/:id', requireAuth, asyncHandler(revokeSessionById));

// DPDP §11/§12 — data portability + erasure.
router.get('/me/export', requireAuth, asyncHandler(exportData));
router.delete('/me', requireAuth, asyncHandler(deleteAccount));

export default router;
