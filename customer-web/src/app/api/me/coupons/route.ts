import { proxyAuthed } from "@/server/bff";

export async function GET() {
  return proxyAuthed("/me/coupons", undefined, "Could not load coupons.");
}
