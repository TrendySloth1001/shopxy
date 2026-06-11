import { proxyAuthed } from "@/server/bff";

/** GET /me/linked-shops — shops the caller is linked to as party or vendor. Auth required. */
export async function GET() {
  return proxyAuthed("/me/linked-shops", undefined, "Could not load linked shops.");
}
