import { NextResponse } from "next/server";
import { resolveBackendBaseUrl } from "@/server/auth/session";

/**
 * Public media proxy. Avatar/image URLs from the backend are stored relative
 * (`/images/<key>`); the browser can't resolve them because the backend base
 * is server-only. This streams them through the same origin so we never ship
 * `API_BASE_URL` to the client. Only the public `/images/` path is proxied.
 *
 * Hardening:
 *  - The path is locked to exactly `images/<filename>` where `<filename>`
 *    matches a strict safe-filename allowlist, so percent-encoded `..` segments
 *    can't normalise their way out of `/images/` to reach other backend GETs.
 *  - The upstream `Content-Type` is pinned to an image allowlist (anything else
 *    is served as a non-renderable `application/octet-stream` attachment), and
 *    `nosniff` / `inline` / same-origin CORP headers are always re-attached so a
 *    smuggled non-image object can't be MIME-sniffed and executed against the
 *    cookie-bearing BFF origin.
 */

// Strict filename allowlist — no slashes, no `..`, no encoded traversal.
const SAFE_FILENAME = /^[A-Za-z0-9._-]+$/;

// Image content-types we are willing to serve as-is. SVG is intentionally
// excluded — it can carry script and would defeat the point of `nosniff`.
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

  // Defence-in-depth: build the upstream URL so the resolved path provably
  // stays under `/images/` even if the filename check is ever loosened.
  // Follows the same environment choice as the rest of the BFF, so images
  // resolve against whichever backend served the record that references them.
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
      // Pin to the allowlisted image type; refuse to echo anything else.
      "Content-Type": isImage ? upstreamType : "application/octet-stream",
      "Content-Disposition": isImage ? "inline" : "attachment",
      "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Resource-Policy": "same-origin",
      "Cache-Control": "private, max-age=300",
    },
  });
}
