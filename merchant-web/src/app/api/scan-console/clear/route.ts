import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/scan-console/clear", req, {
    fallback: "Could not clear the console.",
  });
}
