import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** POST /invitations/:id/decline — decline an invitation. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed(
    `/invitations/${encodeURIComponent(id)}/decline`,
    { method: "POST" },
    "Could not decline invitation.",
  );
}
