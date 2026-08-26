import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";

export async function POST() {
  const res = await authedFetch("/notifications/read-all", { method: "POST" });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok && res.status !== 204) {
    return NextResponse.json(
      { error: await extractError(res, "Could not mark all read.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => ({ updated: 0 })), { status: 200 });
}
