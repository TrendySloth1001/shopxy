import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/scan-console/ticket", req, {
    fallback: "Could not start the scan console.",
  });
}
