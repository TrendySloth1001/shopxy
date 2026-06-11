import { proxyBinaryAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; quotationId: string }> };

/** GET /me/parties/:partyId/quotations/:quotationId/pdf — download quotation PDF. Auth required. */
export async function GET(_req: Request, { params }: Ctx) {
  const { partyId, quotationId } = await params;
  return proxyBinaryAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations/${encodeURIComponent(quotationId)}/pdf`,
    "Could not retrieve quotation PDF.",
  );
}
