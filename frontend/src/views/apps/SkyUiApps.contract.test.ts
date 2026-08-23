import { readdirSync, readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const appDirectory = new URL('.', import.meta.url)
const appSources = readdirSync(appDirectory)
  .filter((file) => file.endsWith('.vue'))
  .map((file) => ({
    file,
    source: readFileSync(new URL(file, appDirectory), 'utf8'),
  }))

const appSupportSources = [
  '../../components/account/AccountLogoutDialog.vue',
  '../../components/account/AppProfileAuth.vue',
  '../../components/account/IfruitAppAuth.vue',
  '../../components/AlarmEditor.vue',
  '../../components/AlarmSoundMenu.vue',
  '../../components/AppIcon.vue',
  '../../components/citymarkt/CityMarktSelect.vue',
  '../../components/CustomAppFrame.vue',
  '../../components/feather/FeatherPostCard.vue',
].map((file) => ({
  file,
  source: readFileSync(new URL(file, import.meta.url), 'utf8'),
}))

const skyUiIndexSources = [
  '../../ui/index.ts',
  '../../ui/controls/index.ts',
  '../../ui/overlays/index.ts',
  '../../ui/settings/index.ts',
].map((file) => readFileSync(new URL(file, import.meta.url), 'utf8'))

const exportedSkyTags = new Set(
  skyUiIndexSources
    .flatMap((source) =>
      [...source.matchAll(/default as (Sky[A-Za-z0-9]+)/g)].map(
        ([, name]) => name,
      ),
    )
    .map((name) => name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase()),
)

describe('phone apps use Sky UI', () => {
  it('keeps every app free of direct Konsta UI imports', () => {
    expect(appSources.length).toBeGreaterThan(0)

    for (const { file, source } of appSources) {
      expect(source, file).not.toContain("from 'konsta/vue'")
    }
  })

  it('keeps app-specific support components on Sky UI', () => {
    for (const { file, source } of appSupportSources) {
      expect(source, file).not.toContain("from 'konsta/vue'")
      expect(source, file).toContain("from '@/ui'")
    }
  })

  it('only renders Sky UI tags that are exported by the shared library', () => {
    for (const { file, source } of appSources) {
      const tags = [...source.matchAll(/<\/?(sky-[a-z0-9-]+)/g)].map(
        ([, tag]) => tag,
      )

      for (const tag of tags)
        expect(exportedSkyTags, `${file}: ${tag}`).toContain(tag)
    }
  })

  it('does not contain identifiers damaged by the Konsta prefix migration', () => {
    const damagedIdentifier =
      /(?:clocsky|crewlinsky|darsky|locsky|networsky|tracsky)/

    for (const { file, source } of [...appSources, ...appSupportSources]) {
      expect(source, file).not.toMatch(damagedIdentifier)
    }
  })

  it('does not pass obsolete Konsta color maps into Sky components', () => {
    for (const { file, source } of [...appSources, ...appSupportSources]) {
      expect(source, file).not.toMatch(/\b:colors=/)
    }
  })

  it('uses top notifications instead of app-level toasts', () => {
    for (const { file, source } of appSources) {
      expect(source, file).not.toMatch(/\bSkyToast\b|<sky-toast|<k-toast/)
      expect(source, file).not.toMatch(/(?:citymarkt|pages)__toast/)
    }
  })

  it('uses shared liquid glass for remaining compact interaction controls', () => {
    const minimumGlassButtons: Record<string, number> = {
      'CameraApp.vue': 1,
      'FeatherApp.vue': 2,
      'FlareApp.vue': 1,
      'FlipTokApp.vue': 2,
      'MemoryApp.vue': 2,
      'MinesweeperApp.vue': 3,
      'NeonDropApp.vue': 3,
      'NumberMergeApp.vue': 3,
      'PicstagramApp.vue': 6,
      'SkyFlappyApp.vue': 3,
      'SnakeApp.vue': 2,
      'TowerStackApp.vue': 3,
      'WeazelNewsApp.vue': 2,
    }

    for (const [file, minimum] of Object.entries(minimumGlassButtons)) {
      const source = appSources.find((app) => app.file === file)?.source ?? ''
      const glassButtons = source.match(
        /<(?:SkyButton|sky-button)(?=[^>]*\bglass\b)[^>]*>/g,
      )

      expect(glassButtons?.length ?? 0, file).toBeGreaterThanOrEqual(minimum)
    }
  })
})
