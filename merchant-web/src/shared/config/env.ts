import "server-only";
import { z } from "zod";

const schema = z.object({
  API_BASE_URL: z
    .string()
    .url()
    .default("https://qjhcp0ph-3003.inc1.devtunnels.ms/"),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  throw new Error(
    `Invalid environment configuration:\n${parsed.error.toString()}`,
  );
}

export const env = {
  ...parsed.data,
  API_BASE_URL: parsed.data.API_BASE_URL.replace(/\/+$/, ""),
  isProd: parsed.data.NODE_ENV === "production",
} as const;
