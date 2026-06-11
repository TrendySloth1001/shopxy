import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string }> };

/** GET /me/parties/:partyId/invoices — invoice list for a linked party. Auth required. */
export async function GET(req: Request, { params }: Ctx) {
  const { partyId } = await params;
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/invoices${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load invoices.",
  );
}
