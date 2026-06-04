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
 * Customer registration. Creates a CUSTOMER account on the backend (no shop).
 * Consent to both the terms and privacy policy is required at the wire level
 * (DPDP), matching the backend schema.
 */
export const registerSchema = z
  .object({
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
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export type RegisterInput = z.infer<typeof registerSchema>;

/**
 * Profile update (customer). Every field optional — the account form PATCHes
 * only what changed. Empty `phoneNumber` is mapped to `null` by the route
 * handler so the value can be cleared.
 */
export const updateProfileSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters").max(80).optional(),
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
