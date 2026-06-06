import { proxy, withQuery } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/vendors/:id/changes → /vendors/:id/changes (field-level audit)
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(withQuery(`/vendors/${encodeURIComponent(id)}/changes`, req), req, {
    fallback: "Could not load history.",
  });
}
