import { z } from "zod";

// ── UserAddress ───────────────────────────────────────────────────────────────

export const userAddressSchema = z.object({
  id: z.coerce.string(),
  label: z.string().nullable().optional(),
  fullName: z.string(),
  phone: z.string(),
  line1: z.string(),
  line2: z.string().nullable().optional(),
  city: z.string(),
  state: z.string(),
  pincode: z.string(),
  landmark: z.string().nullable().optional(),
  isDefault: z.boolean(),
});

export type UserAddress = z.infer<typeof userAddressSchema>;

export const addressListSchema = z.object({
  data: z.array(userAddressSchema),
});

// ── Address form ──────────────────────────────────────────────────────────────

export interface AddressFormValues {
  label: string;
  fullName: string;
  phone: string;
  line1: string;
  line2: string;
  city: string;
  state: string;
  pincode: string;
  landmark: string;
  isDefault: boolean;
}

/** One-line summary as shown in the checkout picker row. */
export function addressOneLine(a: UserAddress): string {
  const parts: string[] = [a.line1];
  if (a.line2) parts.push(a.line2);
  parts.push(a.city, a.state, a.pincode);
  return parts.join(", ");
}
