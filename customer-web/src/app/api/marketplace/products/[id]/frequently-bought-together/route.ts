import { proxyPublic } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyPublic(
    `/marketplace/products/${encodeURIComponent(id)}/frequently-bought-together`,
    undefined,
    "Could not load related products.",
  );
}
