import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/parties/:id/ledger → /parties/:id/ledger
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}/ledger`, req, {
    fallback: "Could not load the ledger.",
  });
}
