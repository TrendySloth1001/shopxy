import { proxy } from "@/server/proxy";

// POST /api/pos/ticket → backend /me/pos/ticket (POS-area WS ticket, so a
// cashier with invoices perms can open the live cart). See review H3.
export function POST(req: Request) {
  return proxy("/me/pos/ticket", req, { fallback: "Could not start the live cart." });
}
