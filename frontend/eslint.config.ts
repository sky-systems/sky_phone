import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import { globalIgnores } from 'eslint/config'
import pluginVue from 'eslint-plugin-vue'

export default defineConfigWithVueTs(
  { files: ['**/*.{ts,mts,tsx,vue}'], name: 'app/files-to-lint' },
  globalIgnores(['**/dist/**', 'testserver/**', 'build.cjs']),
  pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,
  skipFormatting,
)

