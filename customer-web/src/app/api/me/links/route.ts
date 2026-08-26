import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/links", undefined, "Could not load links.");
}
