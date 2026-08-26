import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireAuth } from '../../shared/http/requireAuth.js';
import {
  register,
  verifyEmail,
  resendOtp,
  forgotPassword,
  resetPassword,
  login,
  googleAuth,
  setRecoveryPin,
  recoveryPinLogin,
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

router.post('/register', asyncHandler(register));
router.post('/verify-email', asyncHandler(verifyEmail));
router.post('/resend-otp', asyncHandler(resendOtp));
router.post('/login', asyncHandler(login));
router.post('/forgot-password', asyncHandler(forgotPassword));
router.post('/reset-password', asyncHandler(resetPassword));
router.post('/google', asyncHandler(googleAuth));
router.post('/recovery-pin/login', asyncHandler(recoveryPinLogin));
router.post('/refresh', asyncHandler(refresh));
router.post('/logout', asyncHandler(logout));
router.post('/remember-login', asyncHandler(rememberLogin));
router.post('/remember/forget', asyncHandler(forgetRemember));
router.get('/team-invite/:token', asyncHandler(previewTeamInvite));
router.post('/accept-invite', asyncHandler(acceptTeamInvite));

router.post('/logout-all', requireAuth, asyncHandler(logoutAll));
router.get('/me', requireAuth, asyncHandler(getMe));
router.patch('/me', requireAuth, asyncHandler(updateProfile));
router.post('/change-password', requireAuth, asyncHandler(changePassword));
router.post('/remember', requireAuth, asyncHandler(issueRemember));
router.post('/recovery-pin', requireAuth, asyncHandler(setRecoveryPin));

router.get('/2fa/status', requireAuth, asyncHandler(twoFactorStatus));
router.post('/2fa/setup', requireAuth, asyncHandler(twoFactorSetup));
router.post('/2fa/enable', requireAuth, asyncHandler(twoFactorEnable));
router.post('/2fa/disable', requireAuth, asyncHandler(twoFactorDisable));

router.get('/security/logins', requireAuth, asyncHandler(recentLogins));

router.get('/sessions', requireAuth, asyncHandler(listSessions));
router.post('/sessions/revoke-others', requireAuth, asyncHandler(revokeOtherSessions));
router.delete('/sessions/:id', requireAuth, asyncHandler(revokeSessionById));

router.get('/me/export', requireAuth, asyncHandler(exportData));
router.delete('/me', requireAuth, asyncHandler(deleteAccount));

export default router;
