import { proxyAuthed204 } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed204(
    `/me/returns/${encodeURIComponent(id)}/cancel`,
    { method: "POST", body: JSON.stringify({}) },
    "Could not cancel return.",
  );
}
