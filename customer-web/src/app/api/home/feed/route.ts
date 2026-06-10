import { NextResponse } from "next/server";
import { backendFetch, extractError } from "@/server/auth/session";

/**
 * Public home feed. Proxies the backend `/home/feed` aggregator (banners, flash
 * deals, spotlights, trending, …). No auth needed — anonymous visitors get the
 * same cold-start feed the mobile app shows. The client maps the raw payload.
 */
export async function GET() {
  const res = await backendFetch("/home/feed");
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load the home feed.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
