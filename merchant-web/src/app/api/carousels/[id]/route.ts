import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / PATCH / DELETE /api/carousels/:id
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/carousels/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the carousel.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/carousels/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the carousel.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/carousels/${encodeURIComponent(id)}`, req, {
    fallback: "Could not delete the carousel.",
  });
}
