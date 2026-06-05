import { proxy, withQuery } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/caution-requests → /parties/:id/caution-requests
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(withQuery(`/parties/${encodeURIComponent(id)}/caution-requests`, req), req, {
    fallback: "Could not load caution requests.",
  });
}
