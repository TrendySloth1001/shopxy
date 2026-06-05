import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/challans/${encodeURIComponent(id)}/convert`, req, {
    fallback: "Could not convert the challan.",
  });
}
