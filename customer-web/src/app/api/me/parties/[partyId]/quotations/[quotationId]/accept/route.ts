import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

/** POST /me/parties/:partyId/quotations/:quotationId/accept — accept a quotation. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}/accept`,
    { method: "POST" },
    "Could not accept quotation.",
  );
}
