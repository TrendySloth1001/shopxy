import { Request, Response } from 'express';
import { z } from 'zod';
import { authService } from './auth.service.js';
import {
  GSTIN_REGEX,
  PAN_REGEX,
  PINCODE_REGEX,
  UPI_VPA_REGEX,
} from '../../shared/validation/indian.js';

const registerSchema = z
  .object({
    name: z.string().trim().min(2).max(80),
    email: z.string().trim().email(),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .max(128)
      .regex(/[A-Za-z]/, 'Password must contain at least one letter')
      .regex(/[0-9]/, 'Password must contain at least one number'),
    // App-origin role. Merchant app sends OWNER (and a shopName);
    // customer app sends CUSTOMER. Defaults to CUSTOMER so any
    // pre-existing client that omits the field stays on the safer side.
    role: z.enum(['OWNER', 'CUSTOMER']).optional().default('CUSTOMER'),
    // Required when role is OWNER. The Shop row is created in the same
    // transaction as the user and a unique slug is generated from this.
    shopName: z.string().trim().min(2).max(200).optional(),
    // DPDP consent gate. We require both checkboxes to be true at the
    // wire level too, so a malicious client can't bypass the UI ticks.
    acceptedTerms: z.literal(true, {
      errorMap: () => ({ message: 'You must accept the terms of service' }),
    }),
    acceptedPrivacy: z.literal(true, {
      errorMap: () => ({ message: 'You must accept the privacy policy' }),
    }),
  })
  .refine((d) => d.role !== 'OWNER' || (d.shopName && d.shopName.length >= 2), {
    message: 'shopName is required when registering as a merchant',
    path: ['shopName'],
  });

const deleteAccountSchema = z.object({
  currentPassword: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z
    .string()
    .min(8)
    .max(128)
    .regex(/[A-Za-z]/)
    .regex(/[0-9]/),
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
  const result = await authService.register(registerData);
  if ('error' in result) {
    res.status(409).json({ error: result.error });
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
  const result = await authService.login(parsed.data.email, parsed.data.password);
  if ('error' in result) {
    res.status(401).json({ error: result.error });
    return;
  }
  res.json(result);
}

export async function refresh(req: Request, res: Response) {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'refreshToken required' });
    return;
  }
  const result = await authService.refresh(parsed.data.refreshToken);
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

export async function getMe(req: Request, res: Response) {
  const user = await authService.getMe(req.user!.sub);
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  res.json(user);
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
    if (result.error === 'cannot_delete_with_active_records') {
      res.status(409).json({ error: result.error });
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
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(204).end();
}
