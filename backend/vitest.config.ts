import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // The integration tests hit a real Postgres + MinIO via Prisma. They
    // create rows with random-suffixed identifiers and clean up after
    // themselves so they're safe to run against the dev DB. If you wire
    // up a dedicated test DB later, override DATABASE_URL via .env.test.
    include: ['tests/**/*.test.ts'],
    // Signup requires an emailed OTP, and CI has neither Redis nor a mail
    // transport. Tests that exercise registration opt out here; the flag is
    // refused when NODE_ENV=production, so it cannot weaken a real
    // deployment (see `unverifiedSignupAllowed` in auth.service.ts). The
    // suite that covers the gate itself sets its own env per-test.
    env: { ALLOW_UNVERIFIED_SIGNUP: 'true' },
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
