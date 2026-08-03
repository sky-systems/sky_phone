import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    assetsDir: 'assets',
    emptyOutDir: true,
    outDir: 'dist',
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
})

