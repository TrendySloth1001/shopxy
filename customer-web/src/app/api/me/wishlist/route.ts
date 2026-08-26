import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/wishlist", undefined, "Could not load wishlist.");
}
