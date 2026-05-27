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
    // singleFork keeps everything in one worker but vitest still runs
    // test FILES concurrently inside that worker by default. Disable
    // file parallelism so suites that do global `deleteMany` cleanups
    // (banners, carousels) don't nuke each other's in-flight fixtures.
    fileParallelism: false,
    hookTimeout: 30_000,
    testTimeout: 30_000,
  },
});
