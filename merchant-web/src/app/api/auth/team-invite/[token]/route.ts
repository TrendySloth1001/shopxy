import { NextResponse } from "next/server";
import { backendFetch } from "@/server/auth/session";

// GET /api/auth/team-invite/:token — public, read-only preview of a TEAM invite
// for the accept screen ("<Shop> invited you to join as <role>").
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ token: string }> },
) {
  const { token } = await params;
  const res = await backendFetch(
    `/auth/team-invite/${encodeURIComponent(token)}`,
  );
  const body = await res.json().catch(() => ({}));
  return NextResponse.json(body, { status: res.status });
}
