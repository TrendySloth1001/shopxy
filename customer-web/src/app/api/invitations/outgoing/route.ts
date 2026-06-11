import { proxyAuthed } from "@/server/bff";

/** GET /invitations/outgoing — list outgoing invitations. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/invitations/outgoing${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load invitations.",
  );
}
