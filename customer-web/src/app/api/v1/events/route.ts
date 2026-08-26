import { proxyAuthed } from "@/server/bff";

export async function POST(req: Request) {
  const body = await req.text().catch(() => null);
  return proxyAuthed(
    "/v1/events",
    { method: "POST", body: body ?? undefined },
    "Could not record events.",
  );
}
