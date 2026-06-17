import { NextResponse, type NextRequest } from "next/server";

/**
 * Route guard based on session-cookie presence. This is a fast, coarse gate:
 * it keeps guests out of protected pages and signed-in users off the auth
 * screens without a backend round-trip. Real token validity is enforced by
 * `/api/auth/me` (and ultimately the backend's requireAuth) once the page
 * loads — see RequireAuth.
 */
const PROTECTED = ["/dashboard", "/account"];
const AUTH_PAGES = ["/login", "/register"];

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const hasSession =
    req.cookies.has("sxm_refresh") || req.cookies.has("sxm_access");

  if (AUTH_PAGES.includes(pathname) && hasSession) {
    return NextResponse.redirect(new URL("/dashboard", req.url));
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
  matcher: ["/dashboard/:path*", "/account/:path*", "/login", "/register"],
};
