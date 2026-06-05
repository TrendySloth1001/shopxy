import { streamPdf } from "@/server/pdf";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  return streamPdf(`/quotations/${encodeURIComponent(id)}/pdf`, `quotation-${id}.pdf`);
}
