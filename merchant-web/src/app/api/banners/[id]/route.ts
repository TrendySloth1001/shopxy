import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PATCH / DELETE /api/banners/:id (→ backend /me/banners/:id)
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/banners/${encodeURIComponent(id)}`, req, { fallback: "Could not load the banner." });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/banners/${encodeURIComponent(id)}`, req, { fallback: "Could not update the banner." });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/banners/${encodeURIComponent(id)}`, req, { fallback: "Could not delete the banner." });
}
