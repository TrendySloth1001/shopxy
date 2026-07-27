import { NextRequest, NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { hsnResolutionSchema } from "@/features/products/hsn";

// GET /api/hsn/resolve?code=6205&price=2400 — the rate lookup behind the
// auto-fill. `price` matters: apparel is 5% up to ₹2,500 a piece and 18% above,
// so the same code answers differently depending on what's being charged.
//
// A 404 here means "no rate on file", which the field surfaces as a warning
// rather than silently leaving the tax at 0 — a silent zero is an
// under-charged invoice.
export async function GET(req: NextRequest) {
  const code = req.nextUrl.searchParams.get("code") ?? "";
  if (!code.trim()) {
    return NextResponse.json({ error: "Missing code." }, { status: 400 });
  }
  const params = new URLSearchParams({ code });
  const price = req.nextUrl.searchParams.get("price");
  if (price) params.set("price", price);

  const locale = req.headers.get("accept-language");
  const res = await authedFetch(`/hsn/resolve?${params.toString()}`, {
    headers: locale ? { "accept-language": locale } : undefined,
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "No GST rate found for this code.") },
      { status: res.status },
    );
  }
  const parsed = hsnResolutionSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected HSN data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
