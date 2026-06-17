import { proxy } from "@/server/proxy";

// POST /api/scan-console/ticket → backend /me/scan-console/ticket.
// Mints a single-use, short-lived ticket the browser uses to open the
// scan-console WebSocket. Cookie-authed via the BFF; the JWT never reaches
// the client (only the ephemeral ticket does).
export function POST(req: Request) {
  return proxy("/me/scan-console/ticket", req, {
    fallback: "Could not start the scan console.",
  });
}
