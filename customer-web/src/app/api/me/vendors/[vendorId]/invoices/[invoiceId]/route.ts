import { proxyAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ vendorId: string; invoiceId: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { vendorId, invoiceId } = await params;
  return proxyAuthed(
    `/me/vendors/${encodeURIComponent(vendorId)}/invoices/${encodeURIComponent(invoiceId)}`,
    undefined,
    "Could not load invoice.",
  );
}
