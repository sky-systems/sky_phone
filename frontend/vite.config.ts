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
    fs: {
      allow: [fileURLToPath(new URL('.', import.meta.url))],
      strict: false,
    },
    host: '127.0.0.1',
  },
})

