import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./EasyShareSheet.vue', import.meta.url),
  'utf8',
)

describe('EasyShareSheet Sky UI contract', () => {
  it('uses the first-party bottom sheet without Konsta markup', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).not.toMatch(/<\/?k-[a-z]/)
    expect(source).toContain('<SkySheet')
    expect(source).toContain('<SkyList')
    expect(source).toContain('<SkyGlass')
    expect(source).toContain('.easyshare-host :deep(.sky-sheet__panel)')
    expect(source).toMatch(/--easyshare-solid-surface:\s*#1c1c1d/)
    expect(source).toMatch(
      /background:\s*var\(--easyshare-solid-surface\)\s*!important/,
    )
    expect(source).toMatch(/--easyshare-list-surface:\s*#2c2c2e/)
    expect(source).toMatch(
      /\.easyshare-history\s*\{[^}]*overflow:\s*hidden[^}]*background:\s*var\(--easyshare-list-surface\)/s,
    )
  })

  it('only exposes and opens installed share destinations', () => {
    expect(source).toContain("if (appStore.isInstalled('flare'))")
    expect(source).toContain("if (appStore.isInstalled('darkchat'))")
    expect(source).toContain('.filter((id) => appStore.isInstalled(id))')
    expect(source).toContain('if (!appStore.isInstalled(kind)) return')
    expect(source).toContain('if (!appStore.isInstalled(appId)) return')
    expect(source).not.toContain('appStore.homeLayout.hidden.includes')
  })
})
