import { proxy } from "@/server/proxy";

// POST /api/scan-console/clear → backend /me/scan-console/clear.
// Tells every live console for this shop to reset its list.
export function POST(req: Request) {
  return proxy("/me/scan-console/clear", req, {
    fallback: "Could not clear the console.",
  });
}
