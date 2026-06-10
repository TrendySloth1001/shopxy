import { NextResponse } from "next/server";
import { authedFetch, backendFetch, extractError } from "@/server/auth/session";

/**
 * Endless-scroll product page. Public, but if the caller has a session we send
 * it through `authedFetch` so the backend can apply its viewer filter (a
 * merchant never sees their own shop's products in their stream). Anonymous
 * callers fall back to the plain public fetch.
 *
 * Query: `page` (>=0), `limit` (4..40), optional `seed` (reuse across pages).
 */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const qp = new URLSearchParams();
  const page = url.searchParams.get("page");
  const limit = url.searchParams.get("limit");
  const seed = url.searchParams.get("seed");
  qp.set("page", page && /^\d+$/.test(page) ? page : "0");
  qp.set("limit", limit && /^\d+$/.test(limit) ? limit : "16");
  if (seed && /^\d+$/.test(seed)) qp.set("seed", seed);

  const path = `/home/feed/page?${qp.toString()}`;
  const res = (await authedFetch(path)) ?? (await backendFetch(path));
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load more products.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
