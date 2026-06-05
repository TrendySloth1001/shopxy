import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/vendors/:id/overview → /me/vendors/:id/overview
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/vendors/${encodeURIComponent(id)}/overview`, req, {
    fallback: "Could not load the vendor.",
  });
}
