import { proxyAuthed } from "@/server/bff";

/** GET /me/coupons — list applicable coupons. Auth required. */
export async function GET() {
  return proxyAuthed("/me/coupons", undefined, "Could not load coupons.");
}
