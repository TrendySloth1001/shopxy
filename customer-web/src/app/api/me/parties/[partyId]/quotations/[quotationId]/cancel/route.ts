import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

export async function POST(_req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}/cancel`,
    { method: "POST" },
    "Could not cancel quotation.",
  );
}
