import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/stock-adjustments/${encodeURIComponent(id)}/reverse`, req, {
    fallback: "Could not reverse the adjustment.",
  });
}
