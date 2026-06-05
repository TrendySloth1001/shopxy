import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET / POST /api/carousels/:id/slides
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/carousels/${encodeURIComponent(id)}/slides`, req, {
    fallback: "Could not load slides.",
  });
}

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/carousels/${encodeURIComponent(id)}/slides`, req, {
    fallback: "Could not create the slide.",
  });
}
