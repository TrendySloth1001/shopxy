import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

// GET /api/coupons/:id/redemptions → /me/coupons-admin/:id/redemptions
export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/coupons-admin/${encodeURIComponent(id)}/redemptions`, req, {
    fallback: "Could not load redemptions.",
  });
}
