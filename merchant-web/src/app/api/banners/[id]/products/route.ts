import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PUT /api/banners/:id/products (→ backend /me/banners/:id/products)
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/banners/${encodeURIComponent(id)}/products`, req, {
    fallback: "Could not load banner products.",
  });
}

export async function PUT(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/banners/${encodeURIComponent(id)}/products`, req, {
    fallback: "Could not save banner products.",
  });
}
