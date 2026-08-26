import { NextResponse } from "next/server";
import { z } from "zod";
import { authedFetch, extractError } from "@/server/auth/session";

const bodySchema = z.object({ orderedIds: z.array(z.number().int()).min(1) });

export async function PATCH(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body." }, { status: 400 });
  }
  const res = await authedFetch(
    `/products/${encodeURIComponent(id)}/images/reorder`,
    { method: "PATCH", body: JSON.stringify(parsed.data) },
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not reorder images.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json());
}
