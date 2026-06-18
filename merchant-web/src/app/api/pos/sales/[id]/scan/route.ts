import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST a scanned code → backend resolves + adds to the shared cart.
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/scan`, req, { fallback: "Could not add the scan." });
}
