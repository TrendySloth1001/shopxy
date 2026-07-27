import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch } from "@/server/auth/session";
import { hsnSuggestionSchema } from "@/features/products/hsn";

// GET /api/hsn/suggest?name=cotton+formal+shirt — classification from the
// product name, so the merchant confirms a code instead of hunting for one.
export async function GET(req: NextRequest) {
  const name = req.nextUrl.searchParams.get("name") ?? "";
  if (!name.trim()) return NextResponse.json([]);

  const locale = req.headers.get("accept-language");
  const res = await authedFetch(`/hsn/suggest?name=${encodeURIComponent(name)}`, {
    headers: locale ? { "accept-language": locale } : undefined,
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    // A suggester that fails hard is worse than one that's quiet — the merchant
    // can still search or type a code, so degrade to no suggestions.
    return NextResponse.json([]);
  }
  const raw = await res.json();
  const parsed = z.array(hsnSuggestionSchema).safeParse(raw?.suggestions ?? []);
  return NextResponse.json(parsed.success ? parsed.data : []);
}
