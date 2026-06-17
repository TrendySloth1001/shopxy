import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { backendFetch, clearSessionCookies } from "@/server/auth/session";

// POST /api/auth/logout — revoke the refresh token on the backend (best effort)
// and clear the session cookies regardless of the backend's response.
export async function POST() {
  const store = await cookies();
  const refreshToken = store.get("sxm_refresh")?.value;
  if (refreshToken) {
    try {
      await backendFetch("/auth/logout", {
        method: "POST",
        body: JSON.stringify({ refreshToken }),
      });
    } catch {
      // Network failure shouldn't block local sign-out.
    }
  }
  await clearSessionCookies();
  return new NextResponse(null, { status: 204 });
}
