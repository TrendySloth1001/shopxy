import { streamPdf } from "@/server/pdf";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  const kind = new URL(req.url).searchParams.get("kind") ?? "invoice";
  return streamPdf(
    `/pdf-templates/${encodeURIComponent(id)}/sample?kind=${encodeURIComponent(kind)}`,
    `${id}-sample.pdf`,
  );
}
