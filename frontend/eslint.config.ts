import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'
import {
  defineConfigWithVueTs,
  vueTsConfigs,
} from '@vue/eslint-config-typescript'
import { globalIgnores } from 'eslint/config'
import pluginVue from 'eslint-plugin-vue'

export default defineConfigWithVueTs(
  { files: ['**/*.{ts,mts,tsx,vue}'], name: 'app/files-to-lint' },
  globalIgnores(['**/.vite/**', '**/dist/**', 'testserver/**', 'build.cjs']),
  pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,
  {
    files: ['scripts/**/*.cjs'],
    // These Node utilities are also loaded by the CommonJS publishing script.
    rules: { '@typescript-eslint/no-require-imports': 'off' },
  },
  skipFormatting,
)
