import { proxy, withQuery } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/caution → /parties/:id/caution (history + balance)
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(withQuery(`/parties/${encodeURIComponent(id)}/caution`, req), req, {
    fallback: "Could not load caution history.",
  });
}
