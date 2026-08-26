import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { orderListSchema } from "@/features/orders/schema";

export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await authedFetch(`/orders${qs ? `?${qs}` : ""}`);
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load orders.") },
      { status: res.status },
    );
  }
  const parsed = orderListSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected orders data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
