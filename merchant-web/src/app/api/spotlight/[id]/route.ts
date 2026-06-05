import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// DELETE /api/spotlight/:id — cancel a still-PENDING request.
export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/brand-spotlight/${encodeURIComponent(id)}`, req, {
    fallback: "Could not cancel the request.",
  });
}
