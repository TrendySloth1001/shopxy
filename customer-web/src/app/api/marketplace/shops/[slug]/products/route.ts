import { backendFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ slug: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { slug } = await params;
  const qs = new URL(req.url).searchParams.toString();
  const path = `/marketplace/shops/${encodeURIComponent(slug)}/products${qs ? `?${qs}` : ""}`;
  const res = await backendFetch(path);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load shop products.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
