import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/quotations/${encodeURIComponent(id)}/decline-request`, req, {
    fallback: "Could not decline the request.",
  });
}
