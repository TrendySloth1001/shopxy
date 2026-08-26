import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ productId: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  return proxyAuthed(
    `/me/catalog/products/${encodeURIComponent(productId)}`,
    undefined,
    "Could not load product.",
  );
}
