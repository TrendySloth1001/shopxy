import { proxy } from "@/server/proxy";

type Ctx = { params: Promise<{ id: string }> };

/**
 * Archive a settled quotation — file it out of the merchant's working list.
 *
 * There is no DELETE: the quotation number is a per-shop serial allocated at
 * create time. The backend refuses one the customer can still act on
 * (REQUESTED / PENDING). Merchant-side only — the customer keeps seeing the
 * quote in their own list. `?restore=1` brings it back.
 */
export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  const restore = new URL(req.url).searchParams.get("restore") === "1";
  const path = restore ? "unarchive" : "archive";
  return proxy(`/quotations/${encodeURIComponent(id)}/${path}`, req, {
    fallback: restore
      ? "Could not restore the quotation."
      : "Could not archive the quotation.",
  });
}
