import { NextResponse, type NextRequest } from "next/server";
import { authedFetch } from "@/server/auth/session";
import { dashboardStatsSchema, PERIODS, type DashboardPeriod } from "@/features/dashboard/stats";

export async function GET(req: NextRequest) {
  const raw = req.nextUrl.searchParams.get("period");
  const period: DashboardPeriod = (PERIODS as readonly string[]).includes(raw ?? "")
    ? (raw as DashboardPeriod)
    : "today";

  const res = await authedFetch(`/dashboard/stats?period=${period}`);
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
    return NextResponse.json({ error: "Could not load the dashboard." }, { status: 502 });
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
