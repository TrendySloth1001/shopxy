import { NextResponse, type NextRequest } from "next/server";

const PROTECTED = ["/notifications", "/account", "/orders", "/returns"];
const AUTH_PAGES = ["/login", "/register"];

const MUTATING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

function isCrossOriginMutation(req: NextRequest): boolean {
  if (!MUTATING_METHODS.has(req.method)) return false;

  const site = req.headers.get("sec-fetch-site");
  if (site) return site !== "same-origin" && site !== "none";

  const origin = req.headers.get("origin");
  if (!origin) return false;
  try {
    return new URL(origin).host !== req.nextUrl.host;
  } catch {
    return true;
  }
}

export function middleware(req: NextRequest) {
  if (req.nextUrl.pathname.startsWith("/api/") && isCrossOriginMutation(req)) {
    return NextResponse.json({ error: "Forbidden." }, { status: 403 });
  }

  const { pathname } = req.nextUrl;
  const hasSession =
    req.cookies.has("sxc_refresh") || req.cookies.has("sxc_access");

  if (AUTH_PAGES.includes(pathname) && hasSession) {
    return NextResponse.redirect(new URL("/", req.url));
  }

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
