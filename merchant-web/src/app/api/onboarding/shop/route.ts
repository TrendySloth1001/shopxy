import { proxy } from "@/server/proxy";

// POST /api/onboarding/shop — create the signed-in merchant's first shop
// (name + a few details). Proxies to the backend's ownerOnly onboarding
// route, which seeds the owner membership + starter roles.
export function POST(req: Request) {
  return proxy("/me/onboarding/shop", req, {
    fallback: "Could not create your shop.",
  });
}
