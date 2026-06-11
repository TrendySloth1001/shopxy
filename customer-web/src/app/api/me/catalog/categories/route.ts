import { proxyAuthed } from "@/server/bff";

/** GET /me/catalog/categories — product categories for the linked shop catalog. Auth required. */
export async function GET() {
  return proxyAuthed("/me/catalog/categories", undefined, "Could not load categories.");
}
