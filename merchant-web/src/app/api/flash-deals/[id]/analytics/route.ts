import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/flash-deals/:id/analytics → backend /me/analytics/flash-deals/:id
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/analytics/flash-deals/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load analytics.",
  });
}
