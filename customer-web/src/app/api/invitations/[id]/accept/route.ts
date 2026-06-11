import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** POST /invitations/:id/accept — accept an invitation. Auth required. */
export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed(
    `/invitations/${encodeURIComponent(id)}/accept`,
    { method: "POST" },
    "Could not accept invitation.",
  );
}
