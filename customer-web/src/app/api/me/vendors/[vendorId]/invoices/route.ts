import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ vendorId: string }> };

/** GET /me/vendors/:vendorId/invoices — invoice list for a linked vendor. Auth required. */
export async function GET(req: Request, { params }: Ctx) {
  const { vendorId } = await params;
  const qs = new URL(req.url).searchParams.toString();
  return proxyAuthed(
    `/me/vendors/${encodeURIComponent(vendorId)}/invoices${qs ? `?${qs}` : ""}`,
    undefined,
    "Could not load invoices.",
  );
}
