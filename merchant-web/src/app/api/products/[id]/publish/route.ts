import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { productSchema } from "@/features/products/schema";

const bodySchema = z.object({ isPublished: z.boolean() });

export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch(`/products/${encodeURIComponent(id)}/publish`, {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not update publish state.") },
      { status: res.status },
    );
  }
  const product = productSchema.safeParse(await res.json());
  if (!product.success) {
    return NextResponse.json({ error: "Unexpected product data." }, { status: 502 });
  }
  return NextResponse.json(product.data);
}
