import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    assetsDir: 'assets',
    // Keep the published NUI compatible with the Chromium 103 CEF runtime.
    cssMinify: 'lightningcss',
    cssTarget: 'chrome103',
    emptyOutDir: true,
    outDir: 'dist',
    target: 'chrome103',
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        display: fileURLToPath(new URL('./display.html', import.meta.url)),
      },
      output: {
        assetFileNames: 'assets/sky-[name]-[hash].[ext]',
        chunkFileNames: 'assets/sky-[name]-[hash].js',
        entryFileNames: 'assets/sky-[name]-[hash].js',
      },
    },
  },
  plugins: [tailwindcss(), vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    // Browser traces contain HTML snapshots; do not hot-reload the app when
    // Playwright writes reports or traces during a theme test.
    watch: {
      ignored: ['**/theme-test-results/**', '**/playwright-report/**'],
    },
    fs: {
      allow: [fileURLToPath(new URL('.', import.meta.url))],
      strict: false,
    },
    // Bind one loopback family so strictPort also rejects a second dev server.
    // Open the UI through localhost so embeds still receive that page origin.
    host: '127.0.0.1',
  },
})
