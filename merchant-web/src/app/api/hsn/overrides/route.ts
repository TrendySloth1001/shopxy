import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { hsnOverrideSchema } from "@/features/products/hsn";

// This shop's recorded departures from the platform GST rate.
//
// Separate from shortcuts on purpose: a shortcut is classification (a bookmark
// with no rate), this restates the tax position on a code for the whole
// catalogue. The backend gates it on `shop:manage` and demands a reason.

export async function GET() {
  const res = await authedFetch("/hsn/overrides");
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load your rate overrides.") },
      { status: res.status },
    );
  }
  const raw = await res.json();
  const parsed = z.array(hsnOverrideSchema).safeParse(raw?.overrides ?? []);
  return NextResponse.json(parsed.success ? parsed.data : []);
}

// Mirrors the backend's own zod rules, so an invalid payload is refused at the
// edge rather than making a round trip.
const bodySchema = z.object({
  code: z.string().min(1).max(20),
  gstRate: z.number().min(0).max(100),
  cessRate: z.number().min(0).max(500).optional(),
  reason: z.string().min(3).max(500),
});

export async function POST(req: NextRequest) {
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Enter a code, a rate, and a reason of at least 3 characters." },
      { status: 400 },
    );
  }
  const res = await authedFetch("/hsn/overrides", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save that rate override.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json(), { status: 201 });
}
