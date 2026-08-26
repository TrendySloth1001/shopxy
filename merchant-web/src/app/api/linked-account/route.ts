import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/linked-account", req, { fallback: "Could not start onboarding." });
}
