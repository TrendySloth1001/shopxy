import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string; reqId: string }> };

// POST /api/parties/:id/caution-requests/:reqId/reject
export async function POST(req: Request, { params }: Ctx) {
  const { id, reqId } = await params;
  return proxy(
    `/parties/${encodeURIComponent(id)}/caution-requests/${encodeURIComponent(reqId)}/reject`,
    req,
    { fallback: "Could not decline the request." },
  );
}
