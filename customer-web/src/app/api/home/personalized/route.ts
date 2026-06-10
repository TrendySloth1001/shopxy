import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";

/**
 * Personalised home data (recently-viewed + for-you). Auth-only on the backend;
 * anonymous callers (or any failure) get empty lists with 200 so the client can
 * layer this on top of the public feed without surfacing an error — mirrors the
 * Flutter data source returning empty on 401.
 */
const EMPTY = { recommended: [], recentlyViewed: [] };

export async function GET() {
  const res = await authedFetch("/me/home/personalized");
  if (!res || !res.ok) return NextResponse.json(EMPTY, { status: 200 });
  return NextResponse.json(await res.json().catch(() => EMPTY), { status: 200 });
}
