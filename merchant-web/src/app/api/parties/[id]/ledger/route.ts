import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/ledger → /me/parties/:id/ledger
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/parties/${encodeURIComponent(id)}/ledger`, req, {
    fallback: "Could not load the ledger.",
  });
}
