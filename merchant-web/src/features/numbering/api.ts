import {
  numberingSchemeListSchema,
  numberingSchemeSchema,
  type NumberingScheme,
  type Series,
  type UpdateSchemeInput,
} from "./schema";

async function okJson<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export function listNumberingSchemes(): Promise<NumberingScheme[]> {
  return fetch("/api/numbering", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => numberingSchemeListSchema.parse(raw), "Could not load numbering settings."),
  );
}

export function updateNumberingScheme(
  series: Series,
  input: UpdateSchemeInput,
): Promise<NumberingScheme> {
  return fetch(`/api/numbering/${series}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okJson(r, (raw) => numberingSchemeSchema.parse(raw), "Could not save numbering settings."));
}

export function setNumberingNextNumber(series: Series, startAt: number): Promise<NumberingScheme> {
  return fetch(`/api/numbering/${series}/next-number`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ startAt }),
  }).then((r) =>
    okJson(r, (raw) => numberingSchemeSchema.parse(raw), "Could not set the starting number."),
  );
}
