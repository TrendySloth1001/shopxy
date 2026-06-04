import { NextResponse } from "next/server";
import { env } from "@/shared/config/env";

/**
 * Public media proxy. Avatar/image URLs from the backend are stored relative
 * (`/images/<key>`); the browser can't resolve them because the backend base
 * is server-only. This streams them through the same origin so we never ship
 * `API_BASE_URL` to the client. Only the public `/images/` path is proxied.
 */
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  if (path[0] !== "images" || path.length < 2) {
    return new NextResponse(null, { status: 404 });
  }

  const upstream = await fetch(`${env.API_BASE_URL}/${path.join("/")}`, {
    cache: "no-store",
  });
  if (!upstream.ok || !upstream.body) {
    return new NextResponse(null, { status: upstream.status || 404 });
  }

  return new NextResponse(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": upstream.headers.get("content-type") ?? "image/webp",
      "Cache-Control": "private, max-age=300",
    },
  });
}
