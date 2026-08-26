import { z } from "zod";

export const passwordSchema = z
  .string()
  .min(10, "Password must be at least 10 characters")
  .max(128, "Password is too long")
  .regex(/[A-Za-z]/, "Password must contain at least one letter")
  .regex(/[0-9]/, "Password must contain at least one number");

export const loginSchema = z.object({
  email: z.string().trim().email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const recoveryPinSchema = z
  .string()
  .regex(/^\d{4,6}$/, "PIN must be 4-6 digits");

export const recoveryPinLoginSchema = z.object({
  email: z.string().trim().email("Enter a valid email address"),
  pin: recoveryPinSchema,
});

const registerFields = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters").max(80),
  email: z.string().trim().email("Enter a valid email address"),
  password: passwordSchema,
  confirmPassword: z.string(),
  acceptedTerms: z.literal(true, {
    errorMap: () => ({ message: "You must accept the Terms of Service" }),
  }),
  acceptedPrivacy: z.literal(true, {
    errorMap: () => ({ message: "You must accept the Privacy Policy" }),
  }),
});

export const registerSchema = registerFields.refine(
  (d) => d.password === d.confirmPassword,
  { message: "Passwords do not match", path: ["confirmPassword"] },
);

export const registerWireSchema = registerFields.omit({ confirmPassword: true });

export type RegisterInput = z.infer<typeof registerSchema>;

export const updateProfileSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters").max(80).optional(),
  shopName: z.string().trim().max(200).optional(),
  shopAddress: z.string().trim().max(500).optional(),
  shopCity: z.string().trim().max(120).optional(),
  shopState: z.string().trim().max(120).optional(),
  shopStateCode: z.string().trim().max(2).optional(),
  shopPinCode: z.string().trim().max(6).optional(),
  shopGstin: z.string().trim().max(15).optional(),
  gstEffectiveFrom: z
    .string()
    .trim()
    .regex(/^(\d{4}-\d{2}-\d{2})?$/, "must be YYYY-MM-DD")
    .optional(),
  registrationType: z.enum(["REGULAR", "COMPOSITION", "UNREGISTERED"]).optional(),
  shopPan: z.string().trim().max(10).optional(),
  upiVpa: z.string().trim().max(120).optional(),
  phoneNumber: z.string().trim().max(20).optional(),
  emailNotifications: z.boolean().optional(),
});

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;

export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, "Enter your current password"),
    newPassword: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((d) => d.newPassword === d.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;

export const deleteAccountSchema = z.object({
  currentPassword: z.string().min(1, "Enter your password to confirm"),
});

export const acceptInviteSchema = z
  .object({
    token: z.string().min(1),
    name: z.string().trim().min(2, "Name must be at least 2 characters").max(80).optional(),
    password: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type AcceptInviteInput = z.infer<typeof acceptInviteSchema>;
