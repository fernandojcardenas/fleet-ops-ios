import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.mjs'],
    // All suites share one emulator; run files one at a time.
    fileParallelism: false,
    testTimeout: 20000,
    hookTimeout: 30000,
  },
});
