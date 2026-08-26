import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

export async function GET() {
  const res = await authedFetch("/me/addresses");
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load addresses.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const res = await authedFetch("/me/addresses", {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not add address.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
