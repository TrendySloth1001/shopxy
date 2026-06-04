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

  // Team scope — only present on `/auth/me` (not on login/register). Customer
  // accounts are not on any team, so these stay null/empty here.
  shopId: z.number().nullable().optional(),
  shopRole: z.string().nullable().optional(),
  shopRoleName: z.string().nullable().optional(),
  shopPermissions: z.array(z.string()).default([]),

  // Profile fields — all optional.
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
