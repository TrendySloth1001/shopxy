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

/** Verify an existing Razorpay linked account id — returns details to confirm. */
export function verifyConnect(accountId: string): Promise<ConnectDetails> {
  return post("/api/linked-account/connect", accountId).then((b) => connectDetailsSchema.parse(b));
}

/** Confirm + store the account as this shop's payout destination. */
export function confirmConnect(accountId: string): Promise<void> {
  return post("/api/linked-account/connect/confirm", accountId).then(() => undefined);
}
