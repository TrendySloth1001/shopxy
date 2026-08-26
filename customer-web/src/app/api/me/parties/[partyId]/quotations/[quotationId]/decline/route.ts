import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  const body = await req.text().catch(() => null);
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}/decline`,
    { method: "POST", body: body ?? undefined },
    "Could not decline quotation.",
  );
}
