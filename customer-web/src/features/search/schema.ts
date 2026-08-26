import { z } from "zod";

const asNumber = z.union([z.number(), z.string().transform((s) => parseFloat(s))]).nullable().optional();

export const searchHitSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  sku: z.string().default(""),
  sellingPrice: z.preprocess((v) => {
    if (typeof v === "string") return parseFloat(v);
    return v;
  }, z.number().default(0)),
  ratingAvg: asNumber.transform((v) => (v == null ? null : v)),
  ratingCount: z.number().default(0),
  imageUrl: z.string().nullable().optional().transform((v) => v ?? null),
  shop: z
    .object({
      id: z.coerce.string().default("0"),
      name: z.string().default(""),
      slug: z.string().default(""),
    })
    .optional()
    .default({ id: "0", name: "", slug: "" }),
  rank: z.preprocess((v) => {
    if (typeof v === "string") return parseFloat(v);
    return v;
  }, z.number().default(0)),
  semanticScore: z.number().nullable().optional(),
  ftsScore: z.number().nullable().optional(),
});

export type RawSearchHit = z.infer<typeof searchHitSchema>;

export const searchFacetsSchema = z.object({
  priceMin: z.number().default(0),
  priceMax: z.number().default(0),
  inStockCount: z.number().default(0),
  ratingBuckets: z
    .object({
      ge1: z.number().default(0),
      ge2: z.number().default(0),
      ge3: z.number().default(0),
      ge4: z.number().default(0),
      ge5: z.number().default(0),
    })
    .default({ ge1: 0, ge2: 0, ge3: 0, ge4: 0, ge5: 0 }),
  brands: z
    .array(z.object({ brand: z.string(), count: z.number() }))
    .default([]),
});

export const searchResultSchema = z.object({
  query: z.string().default(""),
  semantic: z.boolean().default(false),
  results: z.array(searchHitSchema).default([]),
  facets: searchFacetsSchema.nullable().optional(),
});

export const autocompleteSchema = z.object({
  products: z
    .array(z.object({ id: z.coerce.string(), name: z.string() }))
    .default([]),
  terms: z
    .array(
      z.union([
        z.string(),
        z.object({ term: z.string() }).transform((o) => o.term),
      ]),
    )
    .default([]),
});

export const hintsSchema = z.object({
  data: z
    .array(
      z.union([
        z.string(),
        z.object({ term: z.string() }).transform((o) => o.term),
      ]),
    )
    .default([]),
});
