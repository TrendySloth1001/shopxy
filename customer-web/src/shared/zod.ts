import { z } from "zod";

export const zNum = z.preprocess(
  (v) => (typeof v === "string" && v.trim() !== "" ? Number(v) : v),
  z.number(),
);
