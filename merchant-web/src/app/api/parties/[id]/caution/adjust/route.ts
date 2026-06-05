import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST /api/parties/:id/caution/adjust → /parties/:id/caution/adjust (set-off)
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}/caution/adjust`, req, {
    fallback: "Could not set off the deposit.",
  });
}
