import { z } from "zod";

export const connectDetailsSchema = z.object({
  accountId: z.string(),
  kycStatus: z.string(),
  payoutsEnabled: z.boolean(),
  email: z.string().nullable(),
  legalBusinessName: z.string().nullable(),
  contactName: z.string().nullable(),
  businessType: z.string().nullable(),
});
export type ConnectDetails = z.infer<typeof connectDetailsSchema>;

async function post(path: string, accountId: string): Promise<unknown> {
  const res = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ accountId }),
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) throw new Error((body as { error?: string } | null)?.error ?? "Request failed.");
  return body;
}

export function verifyConnect(accountId: string): Promise<ConnectDetails> {
  return post("/api/linked-account/connect", accountId).then((b) => connectDetailsSchema.parse(b));
}

export function confirmConnect(accountId: string): Promise<void> {
  return post("/api/linked-account/connect/confirm", accountId).then(() => undefined);
}

export const onboardingSchema = z.object({
  legalBusinessName: z.string().trim().min(1, "Required").max(200),
  customerFacingBusinessName: z.string().trim().max(255).optional(),
  contactName: z.string().trim().min(1, "Required").max(120),
  email: z.string().trim().email("Enter a valid email"),
  phone: z.string().trim().regex(/^\d{8,15}$/, "8–15 digits"),
  businessType: z.string().min(1),
  category: z.string().min(1),
  pan: z.string().trim().toUpperCase().regex(/^[A-Z]{5}[0-9]{4}[A-Z]$/, "Invalid PAN"),
  gst: z
    .string()
    .trim()
    .toUpperCase()
    .regex(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z][Z][0-9A-Z]$/, "Invalid GSTIN")
    .optional()
    .or(z.literal("")),
  registeredAddress: z.object({
    street1: z.string().trim().min(1, "Required").max(255),
    street2: z.string().trim().max(255).optional(),
    city: z.string().trim().min(1, "Required").max(120),
    state: z.string().trim().min(1, "Required").max(120),
    postalCode: z.string().trim().regex(/^\d{6}$/, "6-digit PIN"),
    country: z.string().default("IN"),
  }),
  beneficiaryName: z.string().trim().min(1, "Required").max(120),
  bankAccountNumber: z.string().trim().regex(/^\d{6,20}$/, "6–20 digits"),
  bankIfsc: z.string().trim().toUpperCase().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, "Invalid IFSC"),
});
export type OnboardingInput = z.infer<typeof onboardingSchema>;

export async function startOnboarding(input: OnboardingInput): Promise<void> {
  const res = await fetch("/api/linked-account", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  const body = (await res.json().catch(() => null)) as { error?: string } | null;
  if (!res.ok) throw new Error(body?.error ?? "Could not start onboarding.");
}
