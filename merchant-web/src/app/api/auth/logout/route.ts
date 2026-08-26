import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { backendFetch, clearSessionCookies } from "@/server/auth/session";

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
    }
  }
  await clearSessionCookies();
  return new NextResponse(null, { status: 204 });
}
