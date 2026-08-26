import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/onboarding/shop", req, {
    fallback: "Could not create your shop.",
  });
}
