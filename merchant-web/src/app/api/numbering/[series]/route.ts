import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ series: string }> };

export async function PATCH(req: Request, { params }: Ctx) {
  const { series } = await params;
  return proxy(`/numbering/${encodeURIComponent(series)}`, req, {
    method: "PATCH",
    fallback: "Could not save numbering settings.",
  });
}
