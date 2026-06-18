import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/void`, req, { fallback: "Could not void the sale." });
}
