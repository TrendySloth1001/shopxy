import { z } from "zod";

/// Client contract for the HSN/SAC rate master.
///
/// The merchant classifies the product; the rate is a consequence. Nothing in
/// this module lets them type a rate — that path exists only as the explicit
/// manual escape hatch in the product form, and it is recorded as such.

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
  /// Price-conditional slab (apparel over ₹2,500). Present means the rate the
  /// merchant sees depends on what they charge.
  rule: hsnRuleSchema.nullish(),
  /// Chapter → heading → sub-heading. Shown so the merchant can see that 62 is
  /// woven and 61 is knitted before committing to a code.
  breadcrumb: z.array(hsnNodeSchema).default([]),
  /// "Not this? try these" cross-references.
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
  /// HSN = the code's flat rate · HSN_RULE = decided by price · OVERRIDE = this
  /// shop's own recorded position.
  source: z.enum(["HSN", "HSN_RULE", "OVERRIDE"]),
  /// Which revision of the master produced this rate. Stored on the product so
  /// a later correction can be scoped exactly.
  revision: z.string(),
  rateNote: z.string().nullish(),
  rule: hsnRuleSchema.extend({ testedPrice: z.coerce.number().nullable() }).nullish(),
  breadcrumb: z.array(hsnNodeSchema).default([]),
});
export type HsnResolution = z.infer<typeof hsnResolutionSchema>;

export const hsnSuggestionSchema = hsnMatchSchema.extend({
  /// SHORTCUT = this shop saved it · ALIAS = matched the shared vocabulary ·
  /// TEXT = ranked against code names and definitions · SEMANTIC = a
  /// meaning-based guess. Worth surfacing: a code the merchant saved themselves
  /// deserves more trust than one we inferred.
  ///
  /// Kept permissive on purpose. A tier added on the server must not make the
  /// whole array fail validation and vanish — which is exactly what happened
  /// when `TEXT` shipped and this was a closed enum.
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
  /// The saved code no longer resolves — retired or split by a tariff
  /// revision. Needs the merchant to pick a successor; we must not guess.
  needsAttention: z.boolean().default(false),
});
export type HsnShortcut = z.infer<typeof hsnShortcutSchema>;

/// A recorded departure from the platform rate for one code.
///
/// Deliberately heavier than a shortcut: a shortcut is a bookmark, this is a
/// tax position. `reason` is mandatory server-side because an override without
/// a stated basis can't be told apart from a typo, and it is the field an
/// auditor asks about first.
export const hsnOverrideSchema = z.object({
  id: z.coerce.string(),
  code: z.string(),
  /// Prisma Decimal serialises as a string — coerced, not `z.number()`.
  gstRate: z.coerce.number(),
  cessRate: z.coerce.number().default(0),
  reason: z.string(),
  effectiveFrom: z.string(),
  effectiveTo: z.string().nullish(),
});
export type HsnOverride = z.infer<typeof hsnOverrideSchema>;

/// Generic over the schema rather than over a result type, so the return is
/// the schema's *output* — the one with defaults applied. Typing it as
/// `z.ZodType<T>` infers the input side instead, which makes every
/// `.default()` field optional at the call site.
async function getJson<S extends z.ZodTypeAny>(
  url: string,
  schema: S,
): Promise<z.output<S> | null> {
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) return null;
  const parsed = schema.safeParse(await res.json());
  return parsed.success ? parsed.data : null;
}

/// Type-ahead over codes, aliases and the merchant's own shortcuts.
export async function searchHsn(query: string): Promise<HsnMatch[]> {
  return (
    (await getJson(
      `/api/hsn?q=${encodeURIComponent(query)}`,
      z.array(hsnMatchSchema),
    )) ?? []
  );
}

/// Classification from a product name — the merchant confirms rather than
/// searches. `price` lets the server decide a threshold slab up front.
export async function suggestHsn(name: string): Promise<HsnSuggestion[]> {
  if (!name.trim()) return [];
  return (
    (await getJson(
      `/api/hsn/suggest?name=${encodeURIComponent(name)}`,
      z.array(hsnSuggestionSchema),
    )) ?? []
  );
}

/// The rate lookup. Null means the master carries no rate for this code —
/// callers must say so rather than defaulting to 0%, which is an
/// under-charged invoice.
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

/// Save "when I say X, I mean this code". Stores no rate by design — the rate
/// is always read live, so a saved shortcut can never go stale against a
/// Council revision.
///
/// Returns a boolean rather than throwing: this one is called from the inline
/// save button in the product form, where a failure must not interrupt the
/// merchant mid-edit. The management screen uses the throwing variants below,
/// because there a silent failure looks like the delete worked.
export async function saveShortcut(label: string, code: string): Promise<boolean> {
  const res = await fetch("/api/hsn/shortcuts", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ label, code }),
  });
  return res.ok;
}

/// Surface the backend's `{ error }` so the screen can say what went wrong.
/// A 403 here is meaningful — overrides need `shop:manage`, which a Cashier or
/// Stockist doesn't hold — and "nothing happened" would be a bad way to learn
/// that.
async function mutate(url: string, init: RequestInit, fallback: string): Promise<Response> {
  const res = await fetch(url, init);
  if (res.ok) return res;
  let message = fallback;
  try {
    const body = (await res.json()) as { error?: string };
    if (body?.error) message = body.error;
  } catch {
    /* keep fallback */
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

/// Soft-delete: an override that was in force when documents were raised stays
/// on the record, it just stops applying to new ones.
export async function deleteOverride(id: string): Promise<void> {
  await mutate(
    `/api/hsn/overrides/${encodeURIComponent(id)}`,
    { method: "DELETE" },
    "Could not remove that rate override.",
  );
}

/// HSN/SAC codes are digits only; merchants paste them with spaces and dots.
/// Mirrors `normalizeHsn` on the backend so both ends agree what "the same
/// code" means.
export function normalizeCode(s: string): string {
  return s.replace(/\D/g, "");
}
