import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PATCH / DELETE /api/vendors/:id → /me/vendors/:id
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/vendors/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the vendor.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/vendors/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the vendor.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/vendors/${encodeURIComponent(id)}`, req, {
    fallback: "Could not delete the vendor.",
  });
}
