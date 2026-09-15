import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./PhoneAppWindow.vue', import.meta.url),
  'utf8',
)

describe('PhoneAppWindow bundle contract', () => {
  it('loads the App Store from the phone shell instead of a delayed chunk', () => {
    expect(source).toContain(
      "import AppStoreApp from '@/views/apps/AppStoreApp.vue'",
    )
    expect(source).toContain("app.value?.id === 'app-store'")
    expect(source).toContain('? AppStoreApp : app.value?.component')
    expect(source).toContain(
      '<component :is="builtinAppComponent" :key="shareLaunch" />',
    )
    expect(source).toContain("'app-window--citywarn': app.id === 'citywarn'")
  })
})
