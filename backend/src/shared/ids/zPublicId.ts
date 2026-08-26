import { z } from 'zod';
import { decodeId } from './publicId.js';

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
