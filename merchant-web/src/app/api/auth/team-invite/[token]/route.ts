import { NextResponse } from "next/server";
import { backendFetch } from "@/server/auth/session";

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
