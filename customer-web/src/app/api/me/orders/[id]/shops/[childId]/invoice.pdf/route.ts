import { proxyBinaryAuthed } from "@/server/bff";

type Ctx = { params: Promise<{ id: string; childId: string }> };

/** GET /me/orders/:parentId/shops/:childId/invoice.pdf — download invoice PDF. Auth required. */
export async function GET(_req: Request, { params }: Ctx) {
  const { id, childId } = await params;
  return proxyBinaryAuthed(
    `/me/orders/${encodeURIComponent(id)}/shops/${encodeURIComponent(childId)}/invoice.pdf`,
    "Could not retrieve invoice.",
  );
}
