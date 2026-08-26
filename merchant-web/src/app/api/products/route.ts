import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { productListSchema, productSchema } from "@/features/products/schema";

export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await authedFetch(`/products${qs ? `?${qs}` : ""}`);
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load products.") },
      { status: res.status },
    );
  }
  const parsed = productListSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected products data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch("/products", {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not create the product.") },
      { status: res.status },
    );
  }
  const parsed = productSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected product data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data, { status: 201 });
}
