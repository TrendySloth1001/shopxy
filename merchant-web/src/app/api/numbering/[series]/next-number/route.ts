import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ series: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { series } = await params;
  return proxy(`/numbering/${encodeURIComponent(series)}/next-number`, req, {
    method: "POST",
    fallback: "Could not set the starting number.",
  });
}
