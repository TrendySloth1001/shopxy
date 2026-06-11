import { proxyAuthed204 } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** DELETE /products/:id/reviews/mine — remove the caller's own review. Auth required. */
export async function DELETE(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed204(
    `/products/${encodeURIComponent(id)}/reviews/mine`,
    { method: "DELETE" },
    "Could not delete review.",
  );
}
