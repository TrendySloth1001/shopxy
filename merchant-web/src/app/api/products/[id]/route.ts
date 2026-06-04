import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { productSchema } from "@/features/products/schema";

// GET /api/products/:id
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await authedFetch(`/products/${encodeURIComponent(id)}`);
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load the product.") },
      { status: res.status },
    );
  }
  const parsed = productSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected product data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}

// PATCH /api/products/:id — update.
export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch(`/products/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save the product.") },
      { status: res.status },
    );
  }
  const parsed = productSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected product data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}

// DELETE /api/products/:id
export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await authedFetch(`/products/${encodeURIComponent(id)}`, {
    method: "DELETE",
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not delete the product.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
