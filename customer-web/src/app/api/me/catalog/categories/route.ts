import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/catalog/categories", undefined, "Could not load categories.");
}
