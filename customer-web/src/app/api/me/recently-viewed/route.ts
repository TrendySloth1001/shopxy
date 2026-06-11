import { proxyAuthed } from "@/server/bff";

/** GET /me/recently-viewed — products recently viewed by the caller. Auth required. */
export async function GET() {
  return proxyAuthed("/me/recently-viewed", undefined, "Could not load recently viewed.");
}
