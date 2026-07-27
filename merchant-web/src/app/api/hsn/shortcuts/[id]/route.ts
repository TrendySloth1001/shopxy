import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// DELETE /api/hsn/shortcuts/:id → /hsn/shortcuts/:id
//
// Removing a shortcut only forgets a bookmark: nothing already priced changes,
// because a shortcut never carried a rate in the first place.
export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/hsn/shortcuts/${encodeURIComponent(id)}`, req, {
    fallback: "Could not remove that saved code.",
  });
}
