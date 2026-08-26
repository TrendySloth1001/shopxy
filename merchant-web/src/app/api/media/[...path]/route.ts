import { NextResponse } from "next/server";
import { resolveBackendBaseUrl } from "@/server/auth/session";

const SAFE_FILENAME = /^[A-Za-z0-9._-]+$/;

const ALLOWED_IMAGE_TYPES = new Set([
  "image/webp",
  "image/jpeg",
  "image/png",
  "image/gif",
]);

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const filename = path[1];
  if (
    path.length !== 2 ||
    path[0] !== "images" ||
    !filename ||
    filename.includes("..") ||
    !SAFE_FILENAME.test(filename)
  ) {
    return new NextResponse(null, { status: 404 });
  }

  const upstreamUrl = new URL(
    filename,
    `${await resolveBackendBaseUrl()}/images/`,
  );
  if (!upstreamUrl.pathname.startsWith("/images/")) {
    return new NextResponse(null, { status: 404 });
  }

  const upstream = await fetch(upstreamUrl, { cache: "no-store" });
  if (!upstream.ok || !upstream.body) {
    return new NextResponse(null, { status: upstream.status || 404 });
  }

  const upstreamType = upstream.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  const isImage = !!upstreamType && ALLOWED_IMAGE_TYPES.has(upstreamType);

  return new NextResponse(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": isImage ? upstreamType : "application/octet-stream",
      "Content-Disposition": isImage ? "inline" : "attachment",
      "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Resource-Policy": "same-origin",
      "Cache-Control": "private, max-age=300",
    },
  });
}
