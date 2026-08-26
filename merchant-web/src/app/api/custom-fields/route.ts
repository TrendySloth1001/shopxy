import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { proxy } from "@/server/proxy";
import { customFieldDefSchema } from "@/features/products/schema";

export async function GET() {
  const res = await authedFetch("/custom-fields");
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load custom fields.") },
      { status: res.status },
    );
  }
  const raw = await res.json();
  const list = Array.isArray(raw) ? raw : (raw?.data ?? []);
  const parsed = z.array(customFieldDefSchema).safeParse(list);
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected custom-field data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}

export function POST(req: Request) {
  return proxy("/custom-fields", req, { fallback: "Could not create the field." });
}
