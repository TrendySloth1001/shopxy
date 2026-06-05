import { spotlightListSchema, spotlightSchema, type Spotlight } from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
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

export type SpotlightSubmit = {
  dealLabel: string;
  subtitle?: string | null;
  heroImageUrl: string;
  bgColor: string;
  accentColor?: string | null;
  ctaTarget?: string | null;
  startAt: string;
  endAt: string;
};

export function listSpotlights(): Promise<Spotlight[]> {
  return fetch("/api/spotlight", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => spotlightListSchema.parse(raw).data, "Could not load spotlight requests."),
  );
}

export function submitSpotlight(input: SpotlightSubmit): Promise<Spotlight> {
  return fetch("/api/spotlight", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => spotlightSchema.parse(raw), "Could not submit the request."));
}

export async function cancelSpotlight(id: number): Promise<void> {
  const res = await fetch(`/api/spotlight/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not cancel the request.");
  }
}
