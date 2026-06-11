import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** POST /me/orders/:id/payment/sync — sync payment status after Razorpay sheet. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed(
    `/me/orders/${encodeURIComponent(id)}/payment/sync`,
    { method: "POST", body: JSON.stringify({}) },
    "Could not sync payment status.",
  );
}
