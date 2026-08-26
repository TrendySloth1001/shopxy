import { pdfTemplateListSchema, type PdfTemplate } from "./schema";

async function okJson<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export function listPdfTemplates(): Promise<PdfTemplate[]> {
  return fetch("/api/pdf-templates", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => pdfTemplateListSchema.parse(raw), "Could not load templates."),
  );
}
