import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";

export async function DELETE(
  _req: Request,
  { params }: { params: Promise<{ id: string; imageId: string }> },
) {
  const { id, imageId } = await params;
  const res = await authedFetch(
    `/products/${encodeURIComponent(id)}/images/${encodeURIComponent(imageId)}`,
    { method: "DELETE" },
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not remove the image.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
