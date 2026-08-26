import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string; invoiceId: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { partyId, invoiceId } = await params;
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/invoices/${encodeURIComponent(invoiceId)}`,
    undefined,
    "Could not load invoice.",
  );
}
