import { proxyAuthed204 } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

/** DELETE /invitations/:id — cancel an outgoing invitation (sender only). Auth required. */
export async function DELETE(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed204(
    `/invitations/${encodeURIComponent(id)}`,
    { method: "DELETE" },
    "Could not cancel invitation.",
  );
}
