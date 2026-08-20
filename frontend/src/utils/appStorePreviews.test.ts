import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

import { PHONE_APPS } from '@/config/apps'
import { APP_STORE_PREVIEW_IMAGE_IDS } from '@/utils/appStorePreviewImages'
import {
  getAppStorePreviewVisual,
  PREVIEWABLE_BUILTIN_APP_IDS,
} from '@/utils/appStorePreviews'

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

describe('App Store preview catalog', () => {
  it('contains a real captured screenshot for every built-in store app', () => {
    const storeAppIds = PHONE_APPS.filter(
      (app) =>
        app.kind !== 'external' && app.id !== 'app-store' && !app.adminOnly,
    ).map((app) => app.id)

    expect([...APP_STORE_PREVIEW_IMAGE_IDS].sort()).toEqual(storeAppIds.sort())
  })

  it('provides specialized preview data for every built-in store app', () => {
    const storeAppIds = PHONE_APPS.filter(
      (app) =>
        app.kind !== 'external' && app.id !== 'app-store' && !app.adminOnly,
    ).map((app) => app.id)

    expect([...PREVIEWABLE_BUILTIN_APP_IDS].sort()).toEqual(
      storeAppIds.sort(),
    )
    const visualSignatures = new Set<string>()
    for (const appId of storeAppIds) {
      const preview = getAppStorePreviewVisual(appId)
      visualSignatures.add(`${preview.accent}:${preview.surface}`)
    }
    expect(visualSignatures.size).toBe(storeAppIds.length)
  })

  it('localizes every specialized preview in the fallback, English and German locales', () => {
    const localeSources = [
      readFileSync(
        fileURLToPath(new URL('../stores/phone.ts', import.meta.url)),
        'utf8',
      ),
      readFileSync(
        fileURLToPath(
          new URL('../../../sky_phone/config/locales/en.lua', import.meta.url),
        ),
        'utf8',
      ),
      readFileSync(
        fileURLToPath(
          new URL('../../../sky_phone/config/locales/de.lua', import.meta.url),
        ),
        'utf8',
      ),
    ]

    for (const appId of PREVIEWABLE_BUILTIN_APP_IDS) {
      const escapedAppId = escapeRegExp(appId)
      for (const source of localeSources) {
        expect(source).toMatch(
          new RegExp(
            `(?:["']${escapedAppId}["']\\]?|${escapedAppId})\\s*[:=]\\s*\\{\\s*first\\s*[:=]`,
          ),
        )
      }
    }
  })
})
