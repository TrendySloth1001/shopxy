import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch } from "@/server/auth/session";
import { hsnSuggestionSchema } from "@/features/products/hsn";

export async function GET(req: NextRequest) {
  const name = req.nextUrl.searchParams.get("name") ?? "";
  if (!name.trim()) return NextResponse.json([]);

  const locale = req.headers.get("accept-language");
  const res = await authedFetch(`/hsn/suggest?name=${encodeURIComponent(name)}`, {
    headers: locale ? { "accept-language": locale } : undefined,
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json([]);
  }
  const raw = await res.json();
  const parsed = z.array(hsnSuggestionSchema).safeParse(raw?.suggestions ?? []);
  return NextResponse.json(parsed.success ? parsed.data : []);
}
