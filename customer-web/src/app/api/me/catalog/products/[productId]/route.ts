import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ productId: string }> };

/** GET /me/catalog/products/:productId — single catalog product detail. Auth required. */
export async function GET(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed(
    `/me/catalog/products/${encodeURIComponent(productId)}`,
    undefined,
    "Could not load product.",
  );
}
