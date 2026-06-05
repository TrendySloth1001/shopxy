import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// DELETE /api/invitations/:id → /invitations/:id (cancel a pending invite)
export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invitations/${encodeURIComponent(id)}`, req, {
    fallback: "Could not cancel the invitation.",
  });
}
