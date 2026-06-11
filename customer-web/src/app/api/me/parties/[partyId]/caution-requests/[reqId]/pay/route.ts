import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; reqId: string }> };

/** POST /me/parties/:partyId/caution-requests/:reqId/pay — initiate gateway payment for caution request. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { partyId, reqId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/caution-requests/${encodeURIComponent(reqId)}/pay`,
    { method: "POST" },
    "Could not initiate payment.",
  );
}
