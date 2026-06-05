import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invoices/${encodeURIComponent(id)}/status`, req, {
    fallback: "Could not update the invoice.",
  });
}
