import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/challans/${encodeURIComponent(id)}/cancel`, req, {
    fallback: "Could not cancel the challan.",
  });
}
