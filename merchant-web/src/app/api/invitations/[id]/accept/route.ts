import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// POST /api/invitations/:id/accept → /invitations/:id/accept
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/invitations/${encodeURIComponent(id)}/accept`, req, {
    fallback: "Could not accept the invitation.",
  });
}
