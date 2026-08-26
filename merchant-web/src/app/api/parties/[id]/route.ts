import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the customer.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the customer.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/parties/${encodeURIComponent(id)}`, req, {
    fallback: "Could not delete the customer.",
  });
}
