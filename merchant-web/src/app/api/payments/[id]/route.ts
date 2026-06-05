import { proxy, withQuery } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(withQuery(`/payments/${encodeURIComponent(id)}`, req), req, {
    fallback: "Could not void the payment.",
  });
}
