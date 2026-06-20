import { proxy } from "@/server/proxy";

// POST /api/cashier/return → issue a credit note for the selected lines.
export function POST(req: Request) {
  return proxy("/me/cashier/return", req, { fallback: "Could not process the return." });
}
