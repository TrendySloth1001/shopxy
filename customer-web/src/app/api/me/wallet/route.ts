import { proxyAuthed } from "@/server/bff";

/** GET /me/wallet — wallet balance and recent ledger entries. Auth required. */
export async function GET() {
  return proxyAuthed("/me/wallet", undefined, "Could not load wallet.");
}
