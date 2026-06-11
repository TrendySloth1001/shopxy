import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** POST /me/orders/:id/pay — create / reuse a Razorpay payment intent. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed(
    `/me/orders/${encodeURIComponent(id)}/pay`,
    { method: "POST", body: JSON.stringify({}) },
    "Could not initiate payment.",
  );
}
