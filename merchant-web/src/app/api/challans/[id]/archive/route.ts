import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

/**
 * Archive a settled challan — file it out of the working list.
 *
 * There is no DELETE and can't be: the challan number is a per-shop serial
 * allocated at create time and Rule 55 wants the run serially numbered, so
 * the row can't go away. The backend refuses a PENDING challan (goods are
 * still out against it). `?restore=1` brings it back.
 */
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
