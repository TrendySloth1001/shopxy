import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST /api/parties/:id/caution/forfeit → /parties/:id/caution/forfeit
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}/caution/forfeit`, req, {
    fallback: "Could not forfeit the deposit.",
  });
}
