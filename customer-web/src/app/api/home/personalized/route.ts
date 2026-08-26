import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";

const EMPTY = { recommended: [], recentlyViewed: [] };

export async function GET() {
  const res = await authedFetch("/me/home/personalized");
  if (!res || !res.ok) return NextResponse.json(EMPTY, { status: 200 });
  return NextResponse.json(await res.json().catch(() => EMPTY), { status: 200 });
}
