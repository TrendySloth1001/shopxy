import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { hsnMatchSchema } from "@/features/products/hsn";

export async function GET(req: NextRequest) {
  const params = new URLSearchParams({ q: req.nextUrl.searchParams.get("q") ?? "" });
  const kind = req.nextUrl.searchParams.get("kind");
  if (kind) params.set("kind", kind);
  const locale = req.headers.get("accept-language");

  const res = await authedFetch(`/hsn?${params.toString()}`, {
    headers: locale ? { "accept-language": locale } : undefined,
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not search HSN codes.") },
      { status: res.status },
    );
  }
  const raw = await res.json();
  const parsed = z.array(hsnMatchSchema).safeParse(raw?.results ?? []);
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected HSN data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
