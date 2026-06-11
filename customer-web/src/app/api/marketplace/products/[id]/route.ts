import { proxyPublic } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** GET /marketplace/products/:id — product detail page (auth optional). */
export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyPublic(
    `/marketplace/products/${encodeURIComponent(id)}`,
    undefined,
    "Could not load product.",
  );
}
