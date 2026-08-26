import { NextResponse } from "next/server";
import { proxy, withQuery } from "@/server/proxy";

export async function GET(req: Request) {
  const res = await proxy(withQuery("/linked-account", req), undefined, {
    fallback: "Could not load payout status.",
  });
  if (res.status === 404) return NextResponse.json(null, { status: 200 });
  return res;
}
