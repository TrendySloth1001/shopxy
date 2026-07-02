import { proxy } from "@/server/proxy";

export function GET(req: Request) {
  return proxy("/dashboard/receivables", req, {
    fallback: "Could not load receivables.",
  });
}
