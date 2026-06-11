import { proxyAuthed } from "@/server/bff";

/** GET /me/wishlist — the caller's wishlist. Auth required. */
export async function GET() {
  return proxyAuthed("/me/wishlist", undefined, "Could not load wishlist.");
}
