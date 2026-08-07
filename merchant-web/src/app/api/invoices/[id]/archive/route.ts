import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

/**
 * Archive a DRAFT or CANCELLED invoice — file it out of the working list.
 *
 * Replaces the old DELETE, which the backend could never honour: a draft
 * already owns its legal serial and Rule 46(b) needs the run consecutive, so
 * the row can't go away. `?restore=1` brings it back.
 */
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  const restore = new URL(req.url).searchParams.get("restore") === "1";
  const path = restore ? "unarchive" : "archive";
  return proxy(`/invoices/${encodeURIComponent(id)}/${path}`, req, {
    fallback: restore
      ? "Could not restore the invoice."
      : "Could not archive the invoice.",
  });
}
