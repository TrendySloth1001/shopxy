import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PATCH / DELETE /api/promotions/:id
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/promotions/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the promotion.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/promotions/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the promotion.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/promotions/${encodeURIComponent(id)}`, req, {
    fallback: "Could not cancel the promotion.",
  });
}
