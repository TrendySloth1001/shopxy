import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";
import { unreadCountSchema } from "@/features/notifications/schema";

export async function GET() {
  const res = await authedFetch("/notifications/unread-count");
  if (!res || !res.ok) return NextResponse.json({ unread: 0 });
  const parsed = unreadCountSchema.safeParse(await res.json().catch(() => null));
  return NextResponse.json({ unread: parsed.success ? parsed.data.unread : 0 });
}
