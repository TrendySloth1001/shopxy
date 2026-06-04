import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";

const putSchema = z.object({
  values: z.array(
    z.object({ definitionId: z.number().int(), value: z.string().max(4000) }),
  ),
});

// GET /api/products/:id/custom-fields — values for one product.
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await authedFetch(
    `/products/${encodeURIComponent(id)}/custom-fields`,
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load custom fields.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json());
}

// PUT /api/products/:id/custom-fields — bulk set values.
export async function PUT(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const parsed = putSchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch(
    `/products/${encodeURIComponent(id)}/custom-fields`,
    { method: "PUT", body: JSON.stringify(parsed.data) },
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save custom fields.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => ({ ok: true })));
}
