import { z } from "zod";

/**
 * The authenticated user shape, mirroring the backend `safeUserSelect`
 * projection returned by `/auth/login`, `/auth/register` and `/auth/me`
 * (see `backend/src/modules/auth/auth.service.ts`). Parsed at the BFF
 * boundary so the rest of the app works with a validated object, never
 * `any` from the wire. (CLAUDE.md §2.)
 */
export const authUserSchema = z.object({
  id: z.number(),
  email: z.string(),
  name: z.string(),
  role: z.enum(["OWNER", "CUSTOMER"]),
  isPlatformAdmin: z.boolean().default(false),
  emailNotifications: z.boolean().default(true),
  createdAt: z.string(),

  // Team scope — only present on `/auth/me` (not on login/register).
  shopId: z.number().nullable().optional(),
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
});

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
