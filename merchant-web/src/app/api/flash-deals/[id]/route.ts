import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PATCH / DELETE /api/flash-deals/:id
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/flash-deals/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the flash deal.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/flash-deals/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the flash deal.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/flash-deals/${encodeURIComponent(id)}`, req, {
    fallback: "Could not cancel the flash deal.",
  });
}
