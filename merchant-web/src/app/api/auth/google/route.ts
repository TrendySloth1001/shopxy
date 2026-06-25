import { NextResponse } from "next/server";

/**
 * OAuth start endpoint for "Continue with Google".
 *
 * Google sign-in is not wired up on the backend yet (no OAuth client, callback,
 * or user provisioning). Until that lands, this route redirects back to the
 * sign-in page with a clear notice rather than dead-ending on a 404. When the
 * backend flow exists, replace the redirect below with a 302 to the backend's
 * Google authorisation URL. See PENDING.md.
 */
export function GET(request: Request) {
  const url = new URL("/login", request.url);
  url.searchParams.set("reason", "google-soon");
  return NextResponse.redirect(url);
}
