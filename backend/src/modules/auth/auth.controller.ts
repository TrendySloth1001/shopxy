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

/** Pull the device context (IP + UA + explicit device name) off the request. */
function deviceFromReq(req: Request): DeviceContext {
  return {
    ip: req.ip,
    userAgent: req.get('user-agent'),
    deviceName: req.get('x-device-name'),
  };
}

/**
 * The one password-strength rule, reused by register + change-password so the
 * policy stays single-sourced. Min 10 + a letter + a number; the breach check
 * (HIBP) runs in the service on top of this.
 */
const passwordSchema = z
  .string()
  .min(10, 'Password must be at least 10 characters')
  .max(128)
  .regex(/[A-Za-z]/, 'Password must contain at least one letter')
  .regex(/[0-9]/, 'Password must contain at least one number');

/** Friendly copy for the service's `password_breached` sentinel — one place. */
const PASSWORD_BREACHED_MSG =
  'This password has appeared in a known data breach. Please choose a different one.';

/** Translate the breach sentinel to a 400; returns true when it handled it. */
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
    // App-origin role. Merchant app sends OWNER (and a shopName);
    // customer app sends CUSTOMER. Defaults to CUSTOMER so any
    // pre-existing client that omits the field stays on the safer side.
    role: z.enum(['OWNER', 'CUSTOMER']).optional().default('CUSTOMER'),
    // Optional. When an OWNER provides it, the Shop is created in the same
    // transaction as the user (legacy one-step signup). When omitted, the
    // OWNER is created shopless and names their shop on the onboarding
    // screen next (POST /me/onboarding/shop). Either flow is supported.
    shopName: z.string().trim().min(2).max(200).optional(),
    // DPDP consent gate. We require both checkboxes to be true at the
    // wire level too, so a malicious client can't bypass the UI ticks.
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
  // Optional second factor: a 6-digit TOTP code or an 8-char recovery code.
  // Absent on the first attempt; supplied on the retry after `2fa_required`.
  totpCode: z.string().trim().min(6).max(16).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: passwordSchema,
});

// `.nullable()` on each shop field so the settings screen can clear a value
// by sending null (e.g. user removes their GSTIN). Format checks run only
// when a non-null string is supplied — null bypasses the regex.
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
  // Avatar comes from the existing upload service — accept any URL
  // shape (http(s) or server-relative). null = clear the photo.
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
  // Phone: E.164 family — '+' optional prefix, then 7–15 digits.
  // Loose enough to accept Indian numbers with or without the +91.
  phoneNumber: z
    .string()
    .trim()
    .regex(/^\+?[0-9\s\-]{7,20}$/, 'invalid phone number')
    .transform((v) => v.replace(/[\s\-]/g, ''))
    .nullable()
    .optional(),
  // Granular notification preferences (Phase 5).
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
  // Drop the consent literals before handing to the service — they
  // exist only to gate the request, they're not persisted as flags.
  const { acceptedTerms: _t, acceptedPrivacy: _p, ...registerData } = parsed.data;
  const result = await authService.register(registerData, deviceFromReq(req));
  if ('error' in result) {
    if (handlePasswordBreached(res, result.error)) return;
    res.status(409).json({ error: result.error });
    return;
  }
  // OTP gate: a verification code was emailed and no account exists yet — the
  // client should collect the code and POST /auth/verify-email.
  if ('pending' in result) {
    res.status(200).json({ pending: true, email: result.email });
    return;
  }
  // Fallback path (OTP infra down): the account was created directly.
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

/// POST /auth/verify-email — confirm the signup OTP → create the account + sign in.
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

/// POST /auth/resend-otp — re-send the signup verification code (rate-limited).
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

/// GET /auth/team-invite/:token — read-only preview for the staff
/// accept screen. Public (the recipient isn't signed in yet).
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
  // Optional — the service defaults it from the email when not given, so
  // an account that isn't set up on either app still has a usable name.
  name: z.string().trim().min(2).max(80).optional(),
  password: passwordSchema,
});

/// POST /auth/accept-invite — brand-new staffer sets up their account
/// against a TEAM invite token and is logged straight in.
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
    // Password was right but the account has 2FA on — tell the client to
    // collect a code and retry with `totpCode`. A flag (not just the string)
    // so clients branch on a stable field.
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
  // Record the sign-in + alert on a new device. Best-effort, fire-and-forget:
  // it must never add latency to (or fail) the login response.
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

// ── Device-remember (one-tap return sign-in for native apps) ──────────

const rememberSchema = z.object({ label: z.string().trim().max(80).optional() });
const rememberTokenSchema = z.object({ rememberToken: z.string().min(20).max(256) });

/// POST /auth/remember — authenticated. Mint a device-remember credential
/// for the signed-in user (called by desktop/Flutter right after login).
export async function issueRemember(req: Request, res: Response) {
  const parsed = rememberSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: 'Invalid input' });
    return;
  }
  const result = await authService.issueRememberToken(req.user!.sub, parsed.data.label ?? null);
  res.status(201).json(result);
}

/// POST /auth/remember-login — public. Exchange a stored device-remember
/// credential for a fresh session (no password). Rotates the credential.
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

/// POST /auth/remember/forget — public. Revoke a single remembered device
/// ("Remove this account"). Always 204 (idempotent; reveals nothing).
export async function forgetRemember(req: Request, res: Response) {
  const parsed = rememberTokenSchema.safeParse(req.body);
  if (parsed.success) await authService.forgetRememberToken(parsed.data.rememberToken);
  res.status(204).end();
}

export async function getMe(req: Request, res: Response) {
  const user = await authService.getMe(req.user!.sub);
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  // Surface the caller's team scope alongside the profile so the
  // merchant app can gate role-sensitive UI (Team & roles actions,
  // hiding write affordances staff can't use). Both are hydrated onto
  // req.user by requireAuth from the ShopMember row; null for accounts
  // not on any team.
  res.json({
    ...user,
    shopId: req.user!.shopId ?? null,
    shopRole: req.user!.shopRole ?? null,
    shopRoleName: req.user!.shopRoleName ?? null,
    shopPermissions: req.user!.shopPermissions ?? [],
  });
}

export async function updateProfile(req: Request, res: Response) {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const user = await authService.updateProfile(req.user!.sub, parsed.data);
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  res.json(user);
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
  // result.mode is 'deleted' (account row removed) or 'pseudonymised'
  // (PII-4 controlled wipe — identity tombstoned, statutory invoices
  // retained). The client surfaces a different confirmation per mode.
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

// ── Two-factor auth (TOTP) ────────────────────────────────────────────

const twoFactorCodeSchema = z.object({
  // 6-digit TOTP code or an 8-char recovery code.
  code: z.string().trim().min(6).max(16),
});

/// GET /auth/2fa/status — is 2FA enabled (or mid-enrollment) for the caller.
export async function twoFactorStatus(req: Request, res: Response) {
  res.json(await totpService.status(req.user!.sub));
}

/// POST /auth/2fa/setup — mint a pending secret; returns the QR + otpauth URL.
export async function twoFactorSetup(req: Request, res: Response) {
  const result = await totpService.beginEnrollment(req.user!.sub);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.json(result);
}

/// POST /auth/2fa/enable — confirm a code, turn 2FA on, return recovery codes.
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

/// POST /auth/2fa/disable — turn 2FA off after re-verifying a current code.
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

/// GET /auth/security/logins — the caller's recent sign-ins for a "where
/// you're signed in" / security-activity screen.
export async function recentLogins(req: Request, res: Response) {
  res.json(await loginAlertsService.recentLogins(req.user!.sub));
}

// ── Sessions / devices ────────────────────────────────────────────────

/// GET /auth/sessions — active sessions (device, where, when), current flagged.
export async function listSessions(req: Request, res: Response) {
  res.json(await sessionsService.list(req.user!.sub, req.user!.sid));
}

/// DELETE /auth/sessions/:id — revoke one session (signs that device out now).
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

/// POST /auth/sessions/revoke-others — sign out every device except this one.
export async function revokeOtherSessions(req: Request, res: Response) {
  const revoked = await sessionsService.revokeOthers(req.user!.sub, req.user!.sid);
  res.json({ revoked });
}
