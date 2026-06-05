import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string; slideId: string }> };

// GET / PATCH / DELETE /api/carousels/:id/slides/:slideId
export async function GET(req: Request, { params }: Ctx) {
  const { id, slideId } = await params;
  return proxy(
    `/me/carousels/${encodeURIComponent(id)}/slides/${encodeURIComponent(slideId)}`,
    req,
    { fallback: "Could not load the slide." },
  );
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id, slideId } = await params;
  return proxy(
    `/me/carousels/${encodeURIComponent(id)}/slides/${encodeURIComponent(slideId)}`,
    req,
    { fallback: "Could not save the slide." },
  );
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id, slideId } = await params;
  return proxy(
    `/me/carousels/${encodeURIComponent(id)}/slides/${encodeURIComponent(slideId)}`,
    req,
    { fallback: "Could not delete the slide." },
  );
}
