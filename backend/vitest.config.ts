import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    env: { ALLOW_UNVERIFIED_SIGNUP: 'true' },
    globals: false,
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true,
      },
    },
    fileParallelism: false,
    hookTimeout: 30_000,
    testTimeout: 30_000,
  },
});
