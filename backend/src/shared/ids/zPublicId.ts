import { z } from 'zod';
import { decodeId } from './publicId.js';

/**
 * Zod schema for an id arriving in a **request body** — the INPUT-side companion
 * to {@link encodeIdsDeep}. Accepts either an opaque public token or a legacy
 * numeric id (string or number) and transforms it to the internal integer, so
 * the service layer always receives a plain `number`.
 *
 * Dual-mode by construction (it delegates to {@link decodeId}), so a
 * not-yet-migrated client sending `categoryId: 5` and a migrated client sending
 * `categoryId: "UkLWZg9D"` both validate. Invalid/forged ids fail validation
 * with a 400 (bodies are the client's own data — unlike a URL param probing the
 * id space, a bad body id is a genuine client error, not a lookup miss).
 *
 * Usage: replace `z.number().int().positive()` on any FK body field, e.g.
 *   `categoryId: zPublicId.nullable().optional()`
 *   `orderedIds: z.array(zPublicId).min(1)`
 */
export const zPublicId = z
  .union([z.string(), z.number()])
  .transform((v, ctx) => {
    const n = decodeId(String(v));
    if (n === null) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'Invalid id' });
      return z.NEVER;
    }
    return n;
  });
