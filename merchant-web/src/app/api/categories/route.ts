import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { categorySchema } from "@/features/products/schema";

export async function GET() {
  const res = await authedFetch("/categories");
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load categories.") },
      { status: res.status },
    );
  }
  const raw = await res.json();
  const list = Array.isArray(raw) ? raw : (raw?.data ?? []);
  const parsed = z.array(categorySchema).safeParse(list);
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected categories data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
