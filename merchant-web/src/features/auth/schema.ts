import { z } from "zod";

/**
 * Client + server input schemas, mirroring the backend zod rules in
 * `auth.controller.ts` so validation can't drift between the form, the BFF
 * route handler, and the backend. Used by the forms (field errors) and by
 * the route handlers (boundary validation — CLAUDE.md §2).
 *
 * Password rule is kept in lockstep with the backend: ≥8 chars, ≥1 letter,
 * ≥1 digit.
 */
export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .max(128, "Password is too long")
  .regex(/[A-Za-z]/, "Password must contain at least one letter")
  .regex(/[0-9]/, "Password must contain at least one number");

export const loginSchema = z.object({
  email: z.string().trim().email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

export type LoginInput = z.infer<typeof loginSchema>;

/**
 * Merchant registration. Every merchant signup creates an OWNER account and
 * its Shop atomically on the backend, so `shopName` is required. Consent to
 * both the terms and privacy policy is required at the wire level (DPDP).
 */
export const registerSchema = z
  .object({
    name: z.string().trim().min(2, "Name must be at least 2 characters").max(80),
    shopName: z
      .string()
      .trim()
      .min(2, "Shop name must be at least 2 characters")
      .max(200),
    email: z.string().trim().email("Enter a valid email address"),
    password: passwordSchema,
    confirmPassword: z.string(),
    acceptedTerms: z.literal(true, {
      errorMap: () => ({ message: "You must accept the Terms of Service" }),
    }),
    acceptedPrivacy: z.literal(true, {
      errorMap: () => ({ message: "You must accept the Privacy Policy" }),
    }),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type RegisterInput = z.infer<typeof registerSchema>;

/**
 * Profile update (merchant). Every field optional — the account form PATCHes
 * only what changed. Shape/length are checked here; strict Indian formats
 * (GSTIN/PAN/PIN/UPI) remain the backend's authority and its field errors are
 * surfaced to the user. Empty strings on clearable shop fields are mapped to
 * `null` by the route handler so a value can be removed.
 */
export const updateProfileSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters").max(80).optional(),
  shopName: z.string().trim().max(200).optional(),
  shopAddress: z.string().trim().max(500).optional(),
  shopCity: z.string().trim().max(120).optional(),
  shopState: z.string().trim().max(120).optional(),
  shopStateCode: z.string().trim().max(2).optional(),
  shopPinCode: z.string().trim().max(6).optional(),
  shopGstin: z.string().trim().max(15).optional(),
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

/**
 * Staff onboarding via a TEAM invite link: a brand-new user sets a password
 * against an invite token and is signed straight in (backend `/accept-invite`).
 */
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
