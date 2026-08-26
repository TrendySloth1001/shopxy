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

  avatarUrl: z.string().nullable().optional(),
  phoneNumber: z.string().nullable().optional(),
});

export type AuthUser = z.infer<typeof authUserSchema>;

export const tokenPairSchema = z.object({
  accessToken: z.string().min(1),
  refreshToken: z.string().min(1),
});

export const authResultSchema = tokenPairSchema.extend({
  user: authUserSchema,
});
