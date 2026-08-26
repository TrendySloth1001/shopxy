import { NextResponse } from "next/server";
import { authedFetch } from "@/server/auth/session";

export async function GET() {
  const res = await authedFetch("/auth/me/export");
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: "Could not export your data." },
      { status: 502 },
    );
  }

  const body = await res.text();
  return new NextResponse(body, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition":
        res.headers.get("content-disposition") ??
        'attachment; filename="shopxy-data.json"',
      "Cache-Control": "no-store",
    },
  });
}
