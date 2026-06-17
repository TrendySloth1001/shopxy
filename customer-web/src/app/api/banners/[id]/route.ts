import { NextResponse } from "next/server";
import { backendFetch, extractError } from "@/server/auth/session";

/** Public banner detail — banner + its pinned products. Proxies the
 *  backend `GET /banners/:id`. No auth required. */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const res = await backendFetch(`/banners/${encodeURIComponent(id)}`);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load the banner.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
