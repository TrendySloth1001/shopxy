import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";
import { pendingCountSchema } from "@/features/orders/schema";

export async function GET() {
  const res = await authedFetch("/orders/pending-count");
  if (!res || !res.ok) return NextResponse.json({ count: 0 });
  const parsed = pendingCountSchema.safeParse(await res.json());
  return NextResponse.json({ count: parsed.success ? parsed.data.count : 0 });
}
