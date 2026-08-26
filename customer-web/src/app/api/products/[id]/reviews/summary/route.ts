import { proxyPublic } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyPublic(
    `/products/${encodeURIComponent(id)}/reviews/summary`,
    undefined,
    "Could not load review summary.",
  );
}
