import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}`,
    undefined,
    "Could not load quotation.",
  );
}
