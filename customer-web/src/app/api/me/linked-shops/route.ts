import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/linked-shops", undefined, "Could not load linked shops.");
}
