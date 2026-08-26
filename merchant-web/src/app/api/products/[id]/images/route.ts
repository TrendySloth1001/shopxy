import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";
import { productImageSchema } from "@/features/products/schema";

const bodySchema = z.object({ url: z.string().min(1) });

export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch(`/products/${encodeURIComponent(id)}/images`, {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not add the image.") },
      { status: res.status },
    );
  }
  const image = productImageSchema.safeParse(await res.json());
  if (!image.success) {
    return NextResponse.json({ error: "Unexpected image data." }, { status: 502 });
  }
  return NextResponse.json(image.data, { status: 201 });
}
