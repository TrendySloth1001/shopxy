import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";
import { dashboardStatsSchema } from "@/features/dashboard/stats";

// GET /api/dashboard/stats — proxy the backend dashboard overview with the
// caller's bearer token. Surfaces the backend's 403 (role lacks dashboard:view)
// so the screen can explain it.
export async function GET() {
  const res = await authedFetch("/dashboard/stats");
  if (!res) {
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  }
  if (res.status === 403) {
    return NextResponse.json(
      { error: "Your role doesn’t include the dashboard overview." },
      { status: 403 },
    );
  }
  if (!res.ok) {
    return NextResponse.json(
      { error: "Could not load the dashboard." },
      { status: 502 },
    );
  }

  const parsed = dashboardStatsSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Unexpected dashboard data from the server." },
      { status: 502 },
    );
  }
  return NextResponse.json(parsed.data);
}
