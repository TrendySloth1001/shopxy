import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST /api/parties/:id/caution/refund → /parties/:id/caution/refund
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}/caution/refund`, req, {
    fallback: "Could not record the refund.",
  });
}
