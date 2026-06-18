import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST checkout → backend confirms invoice + records tender (single transaction).
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/pos/sales/${encodeURIComponent(id)}/checkout`, req, { fallback: "Checkout failed." });
}
