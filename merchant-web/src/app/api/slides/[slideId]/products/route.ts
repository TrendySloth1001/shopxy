import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ slideId: string }> };

// GET / PUT /api/slides/:slideId/products
// A slide is a Banner row; pinned products live on /me/banners/:id/products,
// where the backend enforces ownership via the slide's sponsorShopId.
export async function GET(req: Request, { params }: Ctx) {
  const { slideId } = await params;
  return proxy(`/me/banners/${encodeURIComponent(slideId)}/products`, req, {
    fallback: "Could not load slide products.",
  });
}

export async function PUT(req: Request, { params }: Ctx) {
  const { slideId } = await params;
  return proxy(`/me/banners/${encodeURIComponent(slideId)}/products`, req, {
    fallback: "Could not save slide products.",
  });
}
