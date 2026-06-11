import { proxyAuthed, proxyAuthed204 } from "@/server/bff";

type Ctx = { params: Promise<{ productId: string }> };

/** POST /me/wishlist/:productId — add a product to the wishlist. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed(
    `/me/wishlist/${encodeURIComponent(productId)}`,
    { method: "POST" },
    "Could not add to wishlist.",
  );
}

/** DELETE /me/wishlist/:productId — remove a product from the wishlist. Auth required. */
export async function DELETE(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed204(
    `/me/wishlist/${encodeURIComponent(productId)}`,
    { method: "DELETE" },
    "Could not remove from wishlist.",
  );
}
