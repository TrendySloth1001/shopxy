import { z } from "zod";

export const hsnNodeSchema = z.object({
  code: z.string(),
  name: z.string(),
});
export type HsnNode = z.infer<typeof hsnNodeSchema>;

export const hsnRuleSchema = z.object({
  threshold: z.coerce.number(),
  atOrBelow: z.coerce.number(),
  above: z.coerce.number(),
  per: z.enum(["PIECE", "PAIR", "UNIT_PER_DAY"]),
});
export type HsnRule = z.infer<typeof hsnRuleSchema>;

export const hsnMatchSchema = z.object({
  code: z.string(),
  kind: z.enum(["GOODS", "SERVICES"]),
  name: z.string(),
  definition: z.string().nullish(),
  gstRate: z.coerce.number(),
  cessRate: z.coerce.number().default(0),
  rateNote: z.string().nullish(),
  rule: hsnRuleSchema.nullish(),
  breadcrumb: z.array(hsnNodeSchema).default([]),
  notHere: z.array(hsnNodeSchema).default([]),
  fromShortcut: z.boolean().default(false),
});
export type HsnMatch = z.infer<typeof hsnMatchSchema>;

export const hsnResolutionSchema = z.object({
  requestedCode: z.string(),
  code: z.string(),
  exact: z.boolean(),
  gstRate: z.coerce.number(),
  cessRate: z.coerce.number().default(0),
  source: z.enum(["HSN", "HSN_RULE", "OVERRIDE"]),
  revision: z.string(),
  rateNote: z.string().nullish(),
  rule: hsnRuleSchema.extend({ testedPrice: z.coerce.number().nullable() }).nullish(),
  breadcrumb: z.array(hsnNodeSchema).default([]),
});
export type HsnResolution = z.infer<typeof hsnResolutionSchema>;

export const hsnSuggestionSchema = hsnMatchSchema.extend({
  via: z
    .enum(["SHORTCUT", "ALIAS", "TEXT", "SEMANTIC"])
    .catch("TEXT"),
});
export type HsnSuggestion = z.infer<typeof hsnSuggestionSchema>;

export const hsnShortcutSchema = z.object({
  id: z.coerce.string(),
  label: z.string(),
  code: z.string(),
  name: z.string().nullish(),
  gstRate: z.coerce.number().nullish(),
  useCount: z.coerce.number().default(0),
  needsAttention: z.boolean().default(false),
});
export type HsnShortcut = z.infer<typeof hsnShortcutSchema>;

export const hsnOverrideSchema = z.object({
  id: z.coerce.string(),
  code: z.string(),
  gstRate: z.coerce.number(),
  cessRate: z.coerce.number().default(0),
  reason: z.string(),
  effectiveFrom: z.string(),
  effectiveTo: z.string().nullish(),
});
export type HsnOverride = z.infer<typeof hsnOverrideSchema>;

async function getJson<S extends z.ZodTypeAny>(
  url: string,
  schema: S,
): Promise<z.output<S> | null> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) return null;
  const parsed = schema.safeParse(await res.json());
  return parsed.success ? parsed.data : null;
}

export async function searchHsn(query: string): Promise<HsnMatch[]> {
  return (
    (await getJson(
      `/api/hsn?q=${encodeURIComponent(query)}`,
      z.array(hsnMatchSchema),
    )) ?? []
  );
}

export async function suggestHsn(name: string): Promise<HsnSuggestion[]> {
  if (!name.trim()) return [];
  return (
    (await getJson(
      `/api/hsn/suggest?name=${encodeURIComponent(name)}`,
      z.array(hsnSuggestionSchema),
    )) ?? []
  );
}

export async function resolveHsn(
  code: string,
  price?: number,
): Promise<HsnResolution | null> {
  const params = new URLSearchParams({ code });
  if (price !== undefined && Number.isFinite(price)) params.set("price", String(price));
  return getJson(`/api/hsn/resolve?${params.toString()}`, hsnResolutionSchema);
}

export async function listShortcuts(): Promise<HsnShortcut[]> {
  return (
    (await getJson("/api/hsn/shortcuts", z.array(hsnShortcutSchema))) ?? []
  );
}

export async function saveShortcut(label: string, code: string): Promise<boolean> {
  const res = await fetch("/api/hsn/shortcuts", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ label, code }),
  });
  return res.ok;
}

async function mutate(url: string, init: RequestInit, fallback: string): Promise<Response> {
  const res = await fetch(url, init);
  if (res.ok) return res;
  let message = fallback;
  try {
    const body = (await res.json()) as { error?: string };
    if (body?.error) message = body.error;
  } catch {
  }
  throw new Error(message);
}

const jsonPost = (body: unknown): RequestInit => ({
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

export async function saveShortcutOrThrow(label: string, code: string): Promise<void> {
  await mutate("/api/hsn/shortcuts", jsonPost({ label, code }), "Could not save that code.");
}

export async function deleteShortcut(id: string): Promise<void> {
  await mutate(
    `/api/hsn/shortcuts/${encodeURIComponent(id)}`,
    { method: "DELETE" },
    "Could not remove that saved code.",
  );
}

export async function listOverrides(): Promise<HsnOverride[]> {
  return (await getJson("/api/hsn/overrides", z.array(hsnOverrideSchema))) ?? [];
}

export async function createOverride(input: {
  code: string;
  gstRate: number;
  cessRate?: number;
  reason: string;
}): Promise<void> {
  await mutate("/api/hsn/overrides", jsonPost(input), "Could not save that rate override.");
}

export async function deleteOverride(id: string): Promise<void> {
  await mutate(
    `/api/hsn/overrides/${encodeURIComponent(id)}`,
    { method: "DELETE" },
    "Could not remove that rate override.",
  );
}

export function normalizeCode(s: string): string {
  return s.replace(/\D/g, "");
}
