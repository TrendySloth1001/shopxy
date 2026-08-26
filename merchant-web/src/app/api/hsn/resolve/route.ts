import { NextRequest, NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { hsnResolutionSchema } from "@/features/products/hsn";

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
