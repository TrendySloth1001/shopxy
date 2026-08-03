import { z } from "zod";

/**
 * The authenticated user shape, mirroring the backend `safeUserSelect`
 * projection returned by `/auth/login`, `/auth/register` and `/auth/me`
 * (see `backend/src/modules/auth/auth.service.ts`). Parsed at the BFF
 * boundary so the rest of the app works with a validated object, never
 * `any` from the wire. (CLAUDE.md §2.)
 */
export const authUserSchema = z.object({
  id: z.coerce.string(),
  email: z.string(),
  name: z.string(),
  role: z.enum(["OWNER", "CUSTOMER"]),
  isPlatformAdmin: z.boolean().default(false),
  emailNotifications: z.boolean().default(true),
  createdAt: z.string(),

  // Team scope — only present on `/auth/me` (not on login/register).
  shopId: z.coerce.string().nullable().optional(),
  shopRole: z.string().nullable().optional(),
  shopRoleName: z.string().nullable().optional(),
  shopPermissions: z.array(z.string()).default([]),

  // Shop / profile fields — all optional; legacy accounts may omit them.
  shopName: z.string().nullable().optional(),
  shopAddress: z.string().nullable().optional(),
  shopCity: z.string().nullable().optional(),
  shopState: z.string().nullable().optional(),
  shopStateCode: z.string().nullable().optional(),
  shopPinCode: z.string().nullable().optional(),
  shopGstin: z.string().nullable().optional(),
  registrationType: z.string().nullable().optional(),
  shopPan: z.string().nullable().optional(),
  upiVpa: z.string().nullable().optional(),
  avatarUrl: z.string().nullable().optional(),
  phoneNumber: z.string().nullable().optional(),
  // Not a secret — Google's stable per-account `sub`, useless without also
  // owning that Google account. Presence means this account has no
  // password (see backend `safeUserSelect` comment) — combined with
  // `recoveryPinSetAt == null` this is how the app knows a recovery PIN
  // is mandatory before continuing, persistently (not just right after
  // the Google button succeeds, which wouldn't survive a page reload
  // between signup and setting the PIN).
  googleId: z.string().nullable().optional(),
  // Timestamp only (never the PIN or its hash) — presence means the
  // Google-sign-in recovery PIN is already set up.
  recoveryPinSetAt: z.string().nullable().optional(),
});

/** True when this account signed up via Google and hasn't set a recovery
 *  PIN yet — the one thing that gates every protected page ahead of the
 *  usual shopId-based onboarding check. */
export function needsRecoveryPinSetup(user: AuthUser): boolean {
  return user.googleId != null && user.recoveryPinSetAt == null;
}

export type AuthUser = z.infer<typeof authUserSchema>;

/** The token pair the backend returns on login / register / refresh. */
export const tokenPairSchema = z.object({
  accessToken: z.string().min(1),
  refreshToken: z.string().min(1),
});

/** Login / register success envelope from the backend. */
export const authResultSchema = tokenPairSchema.extend({
  user: authUserSchema,
});

/** Google sign-in envelope — same as login, plus whether this account
 *  still needs to set up its recovery PIN (new signups always do). */
export const googleAuthResultSchema = authResultSchema.extend({
  needsPinSetup: z.boolean().optional().default(false),
});
