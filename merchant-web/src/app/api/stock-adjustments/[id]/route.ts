import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/stock-adjustments/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the adjustment.",
  });
}
