import { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { authService } from './auth.service.js';
import { totpService } from './totp.service.js';
import { loginAlertsService } from './loginAlerts.service.js';
import { sessionsService } from './sessions.service.js';
import type { DeviceContext } from './deviceContext.js';
import {
  GSTIN_REGEX,
  PAN_REGEX,
  PINCODE_REGEX,
  UPI_VPA_REGEX,
} from '../../shared/validation/indian.js';

function deviceFromReq(req: Request): DeviceContext {
  return {
    ip: req.ip,
    userAgent: req.get('user-agent'),
    deviceName: req.get('x-device-name'),
  };
}

const passwordSchema = z
  .string()
  .min(10, 'Password must be at least 10 characters')
  .max(128)
  .regex(/[A-Za-z]/, 'Password must contain at least one letter')
  .regex(/[0-9]/, 'Password must contain at least one number');

const PASSWORD_BREACHED_MSG =
  'This password has appeared in a known data breach. Please choose a different one.';

function handlePasswordBreached(res: Response, error: string | undefined): boolean {
  if (error !== 'password_breached') return false;
  res.status(400).json({ error: PASSWORD_BREACHED_MSG });
  return true;
}

const registerSchema = z
  .object({
    name: z.string().trim().min(2).max(80),
    email: z.string().trim().email(),
    password: passwordSchema,
    role: z.enum(['OWNER', 'CUSTOMER']).optional().default('CUSTOMER'),
    shopName: z.string().trim().min(2).max(200).optional(),
    acceptedTerms: z.literal(true, {
      errorMap: () => ({ message: 'You must accept the terms of service' }),
    }),
    acceptedPrivacy: z.literal(true, {
      errorMap: () => ({ message: 'You must accept the privacy policy' }),
    }),
  });

const deleteAccountSchema = z.object({
  currentPassword: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(1),
  totpCode: z.string().trim().min(6).max(16).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: passwordSchema,
});

const nullableShopString = (max: number) => z.string().trim().max(max).nullable().optional();

const updateProfileSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  emailNotifications: z.boolean().optional(),
  shopName: nullableShopString(200),
  shopAddress: nullableShopString(500),
  shopCity: nullableShopString(120),
  shopState: nullableShopString(120),
  shopStateCode: z
    .string()
    .regex(/^\d{2}$/, 'must be 2-digit GST state code')
    .nullable()
    .optional(),
  shopPinCode: z
    .string()
    .regex(PINCODE_REGEX, 'invalid Indian PIN code')
    .nullable()
    .optional(),
  shopGstin: z
    .string()
    .regex(GSTIN_REGEX, 'invalid GSTIN')
    .nullable()
    .optional(),
  gstEffectiveFrom: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'must be YYYY-MM-DD')
    .nullable()
    .optional(),
  registrationType: z.enum(['REGULAR', 'COMPOSITION', 'UNREGISTERED']).optional(),
  shopPan: z
    .string()
    .regex(PAN_REGEX, 'invalid PAN')
    .nullable()
    .optional(),
  upiVpa: z
    .string()
    .regex(UPI_VPA_REGEX, 'invalid UPI VPA')
    .nullable()
    .optional(),
  avatarUrl: z
    .string()
    .trim()
    .max(2048)
    .refine(
      (v) => /^https?:\/\//i.test(v) || v.startsWith('/'),
      'must be an http(s) URL or server-relative path',
    )
    .nullable()
    .optional(),
  phoneNumber: z
    .string()
    .trim()
    .regex(/^\+?[0-9\s\-]{7,20}$/, 'invalid phone number')
    .transform((v) => v.replace(/[\s\-]/g, ''))
    .nullable()
    .optional(),
  notifyOrders: z.boolean().optional(),
  notifyDeals: z.boolean().optional(),
  notifyAccount: z.boolean().optional(),
  notifyMessages: z.boolean().optional(),
  pushEnabled: z.boolean().optional(),
  smsEnabled: z.boolean().optional(),
});

export async function register(req: Request, res: Response) {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const { acceptedTerms: _t, acceptedPrivacy: _p, ...registerData } = parsed.data;
  const result = await authService.register(registerData, deviceFromReq(req));
  if ('error' in result) {
    if (handlePasswordBreached(res, result.error)) return;
    if (result.error === 'verification_unavailable') {
      res.status(503).json({
        error: 'verification_unavailable',
        message:
          "We couldn't send your verification code just now. Please try again in a few minutes.",
      });
      return;
    }
    res.status(409).json({ error: result.error });
    return;
  }
  if ('pending' in result) {
    res.status(200).json({ pending: true, email: result.email });
    return;
  }
  if (result.user?.id) {
    void loginAlertsService.recordLogin({
      userId: result.user.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  }
  res.status(201).json(result);
}

const verifyEmailSchema = z.object({
  email: z.string().trim().email(),
  otp: z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code'),
});

export async function verifyEmail(req: Request, res: Response) {
  const parsed = verifyEmailSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.verifyEmailOtp(
    parsed.data.email,
    parsed.data.otp,
    deviceFromReq(req),
  );
  if ('error' in result) {
    const msg: Record<string, string> = {
      expired: 'This code has expired. Please sign up again.',
      invalid: 'That code is incorrect. Try again.',
      too_many: 'Too many wrong attempts. Please sign up again.',
    };
    const code = result.error === 'invalid' ? 401 : 400;
    res.status(code).json({ error: msg[result.error] ?? result.error });
    return;
  }
  if (result.user?.id) {
    void loginAlertsService.recordLogin({
      userId: result.user.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  }
  res.status(201).json(result);
}

const resendOtpSchema = z.object({ email: z.string().trim().email() });

export async function resendOtp(req: Request, res: Response) {
  const parsed = resendOtpSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.resendEmailOtp(parsed.data.email);
  if ('error' in result) {
    if (result.error === 'cooldown') {
      res.setHeader('Retry-After', String(result.retryAfterS));
      res.status(429).json({ error: `Please wait ${result.retryAfterS}s before requesting a new code.` });
      return;
    }
    if (result.error === 'expired') {
      res.status(400).json({ error: 'Your signup session expired. Please sign up again.' });
      return;
    }
    res.status(400).json({ error: 'Could not send a new code. Try again.' });
    return;
  }
  res.status(204).end();
}

export async function previewTeamInvite(req: Request, res: Response) {
  const result = await authService.previewTeamInvite(req.params.token);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.json(result.invite);
}

const acceptInviteSchema = z.object({
  token: z.string().min(1),
  name: z.string().trim().min(2).max(80).optional(),
  password: passwordSchema,
});

export async function acceptTeamInvite(req: Request, res: Response) {
  const parsed = acceptInviteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.acceptTeamInvite(parsed.data, deviceFromReq(req));
  if ('error' in result) {
    if (handlePasswordBreached(res, result.error)) return;
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(201).json(result);
}

export async function login(req: Request, res: Response) {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.login(
    parsed.data.email,
    parsed.data.password,
    parsed.data.totpCode,
    deviceFromReq(req),
  );
  if ('error' in result) {
    if (result.error === 'locked') {
      const seconds = Math.ceil(result.retryAfterMs / 1000);
      res.setHeader('Retry-After', String(seconds));
      res.status(429).json({
        error: `Too many failed attempts. Try again in ${Math.ceil(seconds / 60)} minute(s).`,
      });
      return;
    }
    if (result.error === '2fa_required') {
      res.status(401).json({ error: '2fa_required', twoFactorRequired: true });
      return;
    }
    if (result.error === '2fa_invalid') {
      res.status(401).json({ error: 'Invalid two-factor code', twoFactorRequired: true });
      return;
    }
    res.status(401).json({ error: result.error });
    return;
  }
  if (result.user?.id) {
    void loginAlertsService.recordLogin({
      userId: result.user.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  }
  res.json(result);
}

const googleAuthSchema = z.object({
  idToken: z.string().min(10),
});

export async function googleAuth(req: Request, res: Response) {
  const parsed = googleAuthSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'idToken required' });
    return;
  }
  const result = await authService.googleAuth(parsed.data.idToken, deviceFromReq(req));
  if ('error' in result) {
    if (result.error === 'account_disabled') {
      res.status(403).json({ error: 'This account has been disabled' });
      return;
    }
    res.status(401).json({ error: 'Google sign-in failed' });
    return;
  }
  if (result.user?.id) {
    void loginAlertsService.recordLogin({
      userId: result.user.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  }
  res.json(result);
}

const pinSchema = z
  .string()
  .regex(/^\d{4,6}$/, 'PIN must be 4-6 digits');

const setRecoveryPinSchema = z.object({ pin: pinSchema });

export async function setRecoveryPin(req: Request, res: Response) {
  const parsed = setRecoveryPinSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.setRecoveryPin(req.user!.sub, parsed.data.pin);
  res.json(result);
}

const recoveryPinLoginSchema = z.object({
  email: z.string().trim().email(),
  pin: pinSchema,
  totpCode: z.string().trim().min(6).max(16).optional(),
});

export async function recoveryPinLogin(req: Request, res: Response) {
  const parsed = recoveryPinLoginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.loginWithRecoveryPin(
    parsed.data.email,
    parsed.data.pin,
    parsed.data.totpCode,
    deviceFromReq(req),
  );
  if ('error' in result) {
    if (result.error === 'locked') {
      const seconds = Math.ceil(result.retryAfterMs / 1000);
      res.setHeader('Retry-After', String(seconds));
      res.status(429).json({
        error: `Too many failed attempts. Try again in ${Math.ceil(seconds / 60)} minute(s).`,
      });
      return;
    }
    if (result.error === '2fa_required') {
      res.status(401).json({ error: '2fa_required', twoFactorRequired: true });
      return;
    }
    if (result.error === '2fa_invalid') {
      res.status(401).json({ error: 'Invalid two-factor code', twoFactorRequired: true });
      return;
    }
    res.status(401).json({ error: result.error });
    return;
  }
  if (result.user?.id) {
    void loginAlertsService.recordLogin({
      userId: result.user.id,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  }
  res.json(result);
}

export async function refresh(req: Request, res: Response) {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'refreshToken required' });
    return;
  }
  const result = await authService.refresh(parsed.data.refreshToken, deviceFromReq(req));
  if ('error' in result) {
    res.status(401).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function logout(req: Request, res: Response) {
  const { refreshToken } = req.body as { refreshToken?: string };
  if (refreshToken) await authService.logout(refreshToken);
  res.status(204).end();
}

export async function logoutAll(req: Request, res: Response) {
  await authService.logoutAll(req.user!.sub);
  res.status(204).end();
}

const rememberSchema = z.object({ label: z.string().trim().max(80).optional() });
const rememberTokenSchema = z.object({ rememberToken: z.string().min(20).max(256) });

export async function issueRemember(req: Request, res: Response) {
  const parsed = rememberSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: 'Invalid input' });
    return;
  }
  const result = await authService.issueRememberToken(req.user!.sub, parsed.data.label ?? null);
  res.status(201).json(result);
}

export async function rememberLogin(req: Request, res: Response) {
  const parsed = rememberTokenSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'rememberToken required' });
    return;
  }
  const result = await authService.rememberLogin(parsed.data.rememberToken, deviceFromReq(req));
  if ('error' in result) {
    res.status(401).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function forgetRemember(req: Request, res: Response) {
  const parsed = rememberTokenSchema.safeParse(req.body);
  if (parsed.success) await authService.forgetRememberToken(parsed.data.rememberToken);
  res.status(204).end();
}

function withShopScope<T extends object>(req: Request, user: T) {
  return {
    ...user,
    shopId: req.user!.shopId ?? null,
    shopRole: req.user!.shopRole ?? null,
    shopRoleName: req.user!.shopRoleName ?? null,
    shopPermissions: req.user!.shopPermissions ?? [],
  };
}

export async function getMe(req: Request, res: Response) {
  const user = await authService.getMe(req.user!.sub);
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  res.json(withShopScope(req, user));
}

export async function updateProfile(req: Request, res: Response) {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.updateProfile(req.user!.sub, parsed.data);
  if (!result) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  if ('error' in result) {
    res.status(422).json({ error: result.error });
    return;
  }
  res.json(withShopScope(req, result));
}

export async function exportData(req: Request, res: Response) {
  const blob = await authService.exportData(req.user!.sub);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="shopxy-data-${req.user!.sub}-${Date.now()}.json"`,
  );
  res.setHeader('Content-Type', 'application/json');
  res.json(blob);
}

export async function deleteAccount(req: Request, res: Response) {
  const parsed = deleteAccountSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.deleteAccount(
    req.user!.sub,
    parsed.data.currentPassword,
  );
  if ('error' in result) {
    if (result.error === 'invalid_password') {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(404).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function changePassword(req: Request, res: Response) {
  const parsed = changePasswordSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.changePassword(
    req.user!.sub,
    parsed.data.currentPassword,
    parsed.data.newPassword,
  );
  if ('error' in result) {
    if (handlePasswordBreached(res, result.error)) return;
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(204).end();
}

const forgotPasswordSchema = z.object({
  email: z.string().trim().email(),
});

export async function forgotPassword(req: Request, res: Response) {
  const parsed = forgotPasswordSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  await authService.requestPasswordReset(parsed.data.email);
  res.status(204).end();
}

const resetPasswordSchema = z.object({
  email: z.string().trim().email(),
  otp: z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code'),
  newPassword: passwordSchema,
});

const RESET_FAILURE_COPY: Record<string, string> = {
  expired: 'That code has expired. Request a new one.',
  invalid: 'That code is incorrect. Try again.',
  too_many: 'Too many incorrect codes. Request a new one.',
};

export async function resetPassword(req: Request, res: Response) {
  const parsed = resetPasswordSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await authService.resetPassword(
    parsed.data.email,
    parsed.data.otp,
    parsed.data.newPassword,
  );
  if ('error' in result) {
    if (handlePasswordBreached(res, result.error)) return;
    const reason = result.error ?? 'invalid';
    res.status(401).json({
      error: reason,
      message: RESET_FAILURE_COPY[reason] ?? 'Could not reset your password.',
    });
    return;
  }
  res.status(204).end();
}

const twoFactorCodeSchema = z.object({
  code: z.string().trim().min(6).max(16),
});

export async function twoFactorStatus(req: Request, res: Response) {
  res.json(await totpService.status(req.user!.sub));
}

export async function twoFactorSetup(req: Request, res: Response) {
  const result = await totpService.beginEnrollment(req.user!.sub);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function twoFactorEnable(req: Request, res: Response) {
  const parsed = twoFactorCodeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await totpService.confirmEnrollment(req.user!.sub, parsed.data.code);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function twoFactorDisable(req: Request, res: Response) {
  const parsed = twoFactorCodeSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await totpService.disable(req.user!.sub, parsed.data.code);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(204).end();
}

export async function recentLogins(req: Request, res: Response) {
  res.json(await loginAlertsService.recentLogins(req.user!.sub));
}

export async function listSessions(req: Request, res: Response) {
  res.json(await sessionsService.list(req.user!.sub, req.user!.sid));
}

export async function revokeSessionById(req: Request, res: Response) {
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'Invalid session id' });
    return;
  }
  const ok = await sessionsService.revoke(req.user!.sub, id);
  if (!ok) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.status(204).end();
}

export async function revokeOtherSessions(req: Request, res: Response) {
  const revoked = await sessionsService.revokeOthers(req.user!.sub, req.user!.sid);
  res.json({ revoked });
}
