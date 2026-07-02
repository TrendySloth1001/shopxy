import { proxy } from "@/server/proxy";

export function GET(req: Request) {
  return proxy("/dashboard/payables", req, {
    fallback: "Could not load payables.",
  });
}
