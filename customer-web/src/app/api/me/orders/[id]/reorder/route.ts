import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return proxyAuthed(
    `/me/orders/${encodeURIComponent(id)}/reorder`,
    { method: "POST", body: JSON.stringify({}) },
    "Could not reorder.",
  );
}
