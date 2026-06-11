import { proxyAuthed } from "@/server/bff";

/** POST /v1/events — ingest analytics events. Auth required. */
export async function POST(req: Request) {
  const body = await req.text().catch(() => null);
  return proxyAuthed(
    "/v1/events",
    { method: "POST", body: body ?? undefined },
    "Could not record events.",
  );
}
