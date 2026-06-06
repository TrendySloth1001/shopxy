import { proxy, withQuery } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/changes → /parties/:id/changes (field-level audit)
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(withQuery(`/parties/${encodeURIComponent(id)}/changes`, req), req, {
    fallback: "Could not load history.",
  });
}
