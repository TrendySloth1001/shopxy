import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch } from "@/server/auth/session";

/**
 * Best-effort analytics ingest. Forwards a batch of product events to the
 * backend `/v1/events` (impressions, taps). The backend attributes the whole
 * batch to the caller's JWT, so this is a no-op for anonymous visitors — we
 * swallow everything and always answer 204 so a tracking blip never disrupts
 * the page. Validated at the boundary (CLAUDE.md §auth&data).
 */
const eventSchema = z.object({
  clientUuid: z.string().min(8).max(80),
  eventType: z.enum(["IMPRESSION", "TAP", "VIEW", "ADD_TO_CART", "PURCHASE", "WISHLIST_ADD"]),
  productId: z.union([z.string().min(1), z.number().int().positive()]),
  sessionId: z.string().max(80).nullable().optional(),
  source: z.string().max(40).nullable().optional(),
  occurredAt: z.string().datetime(),
});
const batchSchema = z.object({ events: z.array(eventSchema).min(1).max(100) });

export async function POST(req: Request) {
  const parsed = batchSchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return new NextResponse(null, { status: 204 });

  try {
    await authedFetch("/v1/events", {
      method: "POST",
      body: JSON.stringify(parsed.data),
    });
  } catch {
    // analytics is best-effort — never propagate failures
  }
  return new NextResponse(null, { status: 204 });
}
