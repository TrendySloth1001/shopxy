import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/orders/returns/${encodeURIComponent(id)}/approve`, req, {
    fallback: "Could not approve the return.",
  });
}
