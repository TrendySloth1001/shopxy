import { proxyPublic } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** GET /products/:id/reviews/summary — rating histogram + 3 recent reviews. Public. */
export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyPublic(
    `/products/${encodeURIComponent(id)}/reviews/summary`,
    undefined,
    "Could not load review summary.",
  );
}
