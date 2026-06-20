import { proxy } from "@/server/proxy";

// POST /api/cashier/authorize → manager authorises a privileged till action.
export function POST(req: Request) {
  return proxy("/me/cashier/authorize", req, { fallback: "Could not authorise." });
}
