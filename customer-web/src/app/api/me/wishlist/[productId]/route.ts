import { proxyAuthed, proxyAuthed204 } from "@/server/bff";

type Ctx = { params: Promise<{ productId: string }> };

export async function POST(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed(
    `/me/wishlist/${encodeURIComponent(productId)}`,
    { method: "POST" },
    "Could not add to wishlist.",
  );
}

export async function DELETE(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed204(
    `/me/wishlist/${encodeURIComponent(productId)}`,
    { method: "DELETE" },
    "Could not remove from wishlist.",
  );
}
