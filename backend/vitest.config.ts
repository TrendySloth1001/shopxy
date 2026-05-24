import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // The integration tests hit a real Postgres + MinIO via Prisma. They
    // create rows with random-suffixed identifiers and clean up after
    // themselves so they're safe to run against the dev DB. If you wire
    // up a dedicated test DB later, override DATABASE_URL via .env.test.
    include: ['tests/**/*.test.ts'],
    globals: false,
    pool: 'forks',
    poolOptions: {
      forks: {
        // Sequential: shared DB → no parallel writes step on each other.
        // Once we move to a per-test transaction / per-suite database,
        // bump this back to default.
        singleFork: true,
      },
    },
    hookTimeout: 30_000,
    testTimeout: 30_000,
  },
});
