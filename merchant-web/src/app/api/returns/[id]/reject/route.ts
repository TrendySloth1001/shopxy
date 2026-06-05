import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/orders/returns/${encodeURIComponent(id)}/reject`, req, {
    fallback: "Could not reject the return.",
  });
}
