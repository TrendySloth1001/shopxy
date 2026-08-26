import { proxyAuthedPassthrough } from "@/server/bff";

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthedPassthrough("/me/coupons/validate", {
    method: "POST",
    body: JSON.stringify(body),
  });
}
