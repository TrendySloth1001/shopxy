import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST quick-add → backend creates a minimal product (products:manage) + adds it.
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/quick-add`, req, {
    fallback: "Could not add the product.",
  });
}
