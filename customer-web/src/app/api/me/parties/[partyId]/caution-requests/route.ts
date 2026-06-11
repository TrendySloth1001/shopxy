import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ partyId: string }> };

/** GET /me/parties/:partyId/caution-requests — list caution requests. Auth required. */
export async function GET(req: Request, { params }: Ctx) {
  const { partyId } = await params;
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/caution-requests${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load caution requests.",
  );
}

/** POST /me/parties/:partyId/caution-requests — create a caution request. Auth required. */
export async function POST(req: Request, { params }: Ctx) {
  const { partyId } = await params;
  const body = await req.text().catch(() => null);
  return proxyAuthed(
    `/me/parties/${encodeURIComponent(partyId)}/caution-requests`,
    { method: "POST", body: body ?? undefined },
    "Could not submit caution request.",
  );
}
