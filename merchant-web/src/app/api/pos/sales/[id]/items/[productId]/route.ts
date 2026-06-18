import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string; productId: string }> };

export async function PATCH(req: Request, { params }: Ctx) {
  const { id, productId } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/items/${encodeURIComponent(productId)}`, req, {
    fallback: "Could not update the item.",
  });
}
export async function DELETE(req: Request, { params }: Ctx) {
  const { id, productId } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/items/${encodeURIComponent(productId)}`, req, {
    fallback: "Could not remove the item.",
  });
}
