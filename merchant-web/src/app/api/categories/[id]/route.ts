import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/categories/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the category.",
  });
}
