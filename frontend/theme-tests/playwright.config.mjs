import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: '*.pw.mjs',
  timeout: 240_000,
  expect: { timeout: 10_000 },
  workers: 2,
  fullyParallel: true,
  retries: 0,
  outputDir: '../theme-test-results',
  reporter: [
    ['list'],
    [
      'html',
      {
        open: 'never',
        outputFolder: fileURLToPath(
          new URL('../playwright-report', import.meta.url),
        ),
      },
    ],
  ],
  use: {
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    baseURL: 'http://127.0.0.1:5198',
    viewport: { width: 1280, height: 1000 },
    colorScheme: 'light',
    channel: process.env.PLAYWRIGHT_CHANNEL || undefined,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: [
    {
      command:
        'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5198 --strictPort',
      url: 'http://127.0.0.1:5198',
      cwd: '..',
      reuseExistingServer: !process.env.CI,
    },
    {
      command: 'node testserver/index.cjs 3098',
      url: 'http://127.0.0.1:3098/health',
      cwd: '..',
      reuseExistingServer: !process.env.CI,
    },
  ],
})
