import { proxyAuthed } from "@/server/bff";

/** GET /invitations/incoming — list incoming invitations. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/invitations/incoming${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load invitations.",
  );
}
