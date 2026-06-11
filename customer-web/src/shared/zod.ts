import { z } from "zod";

/**
 * Backend money/quantity fields are Prisma `Decimal`s, which serialize to
 * JSON as STRINGS ("499.00"), while plain Int/Float columns arrive as
 * numbers. `zNum` accepts both and always yields a number, so response
 * schemas don't break depending on the column type behind a field.
 *
 * Null/undefined pass through untouched, so `zNum.nullish()` keeps its
 * meaning (unlike `z.coerce.number()`, which turns null into 0).
 */
export const zNum = z.preprocess(
  (v) => (typeof v === "string" && v.trim() !== "" ? Number(v) : v),
  z.number(),
);
