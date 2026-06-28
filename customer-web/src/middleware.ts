import { NextResponse, type NextRequest } from "next/server";

/**
 * Route guard based on session-cookie presence. This is a fast, coarse gate:
 * it keeps guests out of protected pages and signed-in users off the auth
 * screens without a backend round-trip. Real token validity is enforced by
 * `/api/auth/me` (and ultimately the backend's requireAuth) once the page
 * loads — see RequireAuth.
 */
const PROTECTED = ["/notifications", "/account", "/orders", "/returns"];
const AUTH_PAGES = ["/login", "/register"];

const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/**
 * CSRF backstop for the cookie-authed BFF. SameSite=Lax already blocks most
 * cross-site cookie POSTs, but a state-changing request whose `Origin` is a
 * foreign site (or which the browser flags as cross-site via `Sec-Fetch-Site`)
 * is rejected outright. Same-origin and direct/navigational requests pass.
 */
function isCrossOriginMutation(req: NextRequest): boolean {
  if (!MUTATING_METHODS.has(req.method)) return false;

  const site = req.headers.get("sec-fetch-site");
  if (site) return site !== "same-origin" && site !== "none";

  // Fallback for browsers that don't send Sec-Fetch-Site: compare Origin host
  // against the host the request was actually sent to.
  const origin = req.headers.get("origin");
  if (!origin) return false; // non-browser / same-origin server call
  try {
    return new URL(origin).host !== req.nextUrl.host;
  } catch {
    return true;
  }
}

export function middleware(req: NextRequest) {
  // BFF route handlers carry the httpOnly session cookies; reject cross-origin
  // mutations before they reach any handler.
  if (req.nextUrl.pathname.startsWith("/api/") && isCrossOriginMutation(req)) {
    return NextResponse.json({ error: "Forbidden." }, { status: 403 });
  }

  const { pathname } = req.nextUrl;
  const hasSession =
    req.cookies.has("sxc_refresh") || req.cookies.has("sxc_access");

  if (AUTH_PAGES.includes(pathname) && hasSession) {
    return NextResponse.redirect(new URL("/", req.url));
  }

  // The old merchant-style dashboard is gone — the storefront home is "/".
  if (pathname === "/dashboard" || pathname.startsWith("/dashboard/")) {
    const dest = pathname.startsWith("/dashboard/notifications")
      ? "/notifications"
      : "/";
    return NextResponse.redirect(new URL(dest, req.url));
  }

  const isProtected = PROTECTED.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
  if (isProtected && !hasSession) {
    const url = new URL("/login", req.url);
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/api/:path*", "/dashboard/:path*", "/notifications/:path*", "/account/:path*", "/orders/:path*", "/returns/:path*", "/login", "/register"],
};
