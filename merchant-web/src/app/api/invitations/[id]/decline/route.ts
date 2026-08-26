import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invitations/${encodeURIComponent(id)}/decline`, req, {
    fallback: "Could not decline the invitation.",
  });
}
