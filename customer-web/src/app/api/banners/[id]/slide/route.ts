import { proxyPublic } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** GET /banners/:id/slide — banner detail with products. Public. */
export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyPublic(
    `/banners/${encodeURIComponent(id)}/slide`,
    undefined,
    "Could not load banner.",
  );
}
