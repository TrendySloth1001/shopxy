import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/orders/returns/${encodeURIComponent(id)}/refund`, req, {
    fallback: "Could not refund the return.",
  });
}
