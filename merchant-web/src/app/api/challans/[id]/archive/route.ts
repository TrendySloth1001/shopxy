import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  const restore = new URL(req.url).searchParams.get("restore") === "1";
  const path = restore ? "unarchive" : "archive";
  return proxy(`/challans/${encodeURIComponent(id)}/${path}`, req, {
    fallback: restore
      ? "Could not restore the challan."
      : "Could not archive the challan.",
  });
}
