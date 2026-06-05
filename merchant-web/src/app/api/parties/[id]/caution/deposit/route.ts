import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST /api/parties/:id/caution/deposit → /parties/:id/caution/deposit
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}/caution/deposit`, req, {
    fallback: "Could not record the deposit.",
  });
}
