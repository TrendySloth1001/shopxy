import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/recently-viewed", undefined, "Could not load recently viewed.");
}
