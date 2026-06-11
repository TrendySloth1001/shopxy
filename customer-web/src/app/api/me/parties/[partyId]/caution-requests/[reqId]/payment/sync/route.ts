import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; reqId: string }> };

/** POST /me/parties/:partyId/caution-requests/:reqId/payment/sync — confirm gateway settlement. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { partyId, reqId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/caution-requests/${encodeURIComponent(reqId)}/payment/sync`,
    { method: "POST" },
    "Could not sync payment.",
  );
}
