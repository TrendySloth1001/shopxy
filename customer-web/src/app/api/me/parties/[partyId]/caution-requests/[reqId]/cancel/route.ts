import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; reqId: string }> };

/** POST /me/parties/:partyId/caution-requests/:reqId/cancel — cancel a pending caution request. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { partyId, reqId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/caution-requests/${encodeURIComponent(reqId)}/cancel`,
    { method: "POST" },
    "Could not cancel caution request.",
  );
}
