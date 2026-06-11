import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string }> };

/** GET /me/parties/:partyId/quotations — list quotations for a party. Auth required. */
export async function GET(req: Request, { params }: Ctx) {
  const { partyId } = await params;
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load quotations.",
  );
}

/** POST /me/parties/:partyId/quotations — create a quotation request. Auth required. */
export async function POST(req: Request, { params }: Ctx) {
  const { partyId } = await params;
  const body = await req.text().catch(() => null);
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/quotations`,
    { method: "POST", body: body ?? undefined },
    "Could not submit quotation request.",
  );
}
