import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { hsnShortcutSchema } from "@/features/products/hsn";

export async function GET(req: NextRequest) {
  const locale = req.headers.get("accept-language");
  const res = await authedFetch("/hsn/shortcuts", {
    headers: locale ? { "accept-language": locale } : undefined,
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load your saved codes.") },
      { status: res.status },
    );
  }
  const raw = await res.json();
  const parsed = z.array(hsnShortcutSchema).safeParse(raw?.shortcuts ?? []);
  return NextResponse.json(parsed.success ? parsed.data : []);
}

const bodySchema = z.object({
  label: z.string().min(1).max(120),
  code: z.string().min(1).max(20),
});

export async function POST(req: NextRequest) {
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid payload." }, { status: 400 });
  }
  const res = await authedFetch("/hsn/shortcuts", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save that code.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json(), { status: 201 });
}
