import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/hsn/overrides/${encodeURIComponent(id)}`, req, {
    fallback: "Could not remove that rate override.",
  });
}
