import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invoices/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the invoice.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invoices/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the invoice.",
  });
}
