import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

/** GET /me/parties/:partyId/quotations/:quotationId — quotation detail. Auth required. */
export async function GET(_req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}`,
    undefined,
    "Could not load quotation.",
  );
}
