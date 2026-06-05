import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/overview → /me/parties/:id/overview
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/parties/${encodeURIComponent(id)}/overview`, req, {
    fallback: "Could not load the customer.",
  });
}
