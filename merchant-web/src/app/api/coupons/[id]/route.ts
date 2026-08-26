import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/coupons-admin/${encodeURIComponent(id)}`, req, {
    fallback: "Could not load the coupon.",
  });
}

export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/coupons-admin/${encodeURIComponent(id)}`, req, {
    fallback: "Could not save the coupon.",
  });
}

export async function DELETE(req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxy(`/me/coupons-admin/${encodeURIComponent(id)}`, req, {
    fallback: "Could not deactivate the coupon.",
  });
}
