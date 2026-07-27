import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// DELETE /api/hsn/overrides/:id → /hsn/overrides/:id
//
// Soft on the backend: the override stops applying to new documents but stays
// on the record, because it was the shop's stated position when earlier
// invoices were raised and erasing it would falsify those.
export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/hsn/overrides/${encodeURIComponent(id)}`, req, {
    fallback: "Could not remove that rate override.",
  });
}
