import { z } from "zod";

export const authUserSchema = z.object({
  id: z.coerce.string(),
  email: z.string(),
  name: z.string(),
  role: z.enum(["OWNER", "CUSTOMER"]),
  isPlatformAdmin: z.boolean().default(false),
  emailNotifications: z.boolean().default(true),
  createdAt: z.string(),

  shopId: z.coerce.string().nullable().optional(),
  shopRole: z.string().nullable().optional(),
  shopRoleName: z.string().nullable().optional(),
  shopPermissions: z.array(z.string()).default([]),

  shopName: z.string().nullable().optional(),
  shopAddress: z.string().nullable().optional(),
  shopCity: z.string().nullable().optional(),
  shopState: z.string().nullable().optional(),
  shopStateCode: z.string().nullable().optional(),
  shopPinCode: z.string().nullable().optional(),
  shopGstin: z.string().nullable().optional(),
  gstEffectiveFrom: z.string().nullable().optional(),
  registrationType: z.string().nullable().optional(),
  shopPan: z.string().nullable().optional(),
  upiVpa: z.string().nullable().optional(),
  avatarUrl: z.string().nullable().optional(),
  phoneNumber: z.string().nullable().optional(),
  googleId: z.string().nullable().optional(),
  recoveryPinSetAt: z.string().nullable().optional(),
});

export function needsRecoveryPinSetup(user: AuthUser): boolean {
  return user.googleId != null && user.recoveryPinSetAt == null;
}

export type AuthUser = z.infer<typeof authUserSchema>;

export const tokenPairSchema = z.object({
  accessToken: z.string().min(1),
  refreshToken: z.string().min(1),
});

export const authResultSchema = tokenPairSchema.extend({
  user: authUserSchema,
});

export const googleAuthResultSchema = authResultSchema.extend({
  needsPinSetup: z.boolean().optional().default(false),
});
