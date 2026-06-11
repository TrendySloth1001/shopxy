import { proxyAuthed } from "@/server/bff";

/** GET /me/links — parties and vendors the caller is linked to. Auth required. */
export async function GET() {
  return proxyAuthed("/me/links", undefined, "Could not load links.");
}
