import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

// Pure-function unit tests (node env). The `@/` alias mirrors tsconfig paths.
export default defineConfig({
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
