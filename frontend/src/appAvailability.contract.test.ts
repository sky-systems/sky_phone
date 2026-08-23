import { readFileSync } from 'node:fs'
import { join } from 'node:path'

import { describe, expect, it } from 'vitest'

import {
  PHONE_APPS,
  isExternalPhoneApp,
  isLaunchablePhoneApp,
} from '@/config/apps'

const repositoryRoot = join(import.meta.dirname, '../..')
const source = (path: string) =>
  readFileSync(join(repositoryRoot, path), 'utf8')

const app = source('frontend/src/App.vue')
const appStore = source('frontend/src/stores/app-store.ts')
const appStoreView = source('frontend/src/views/apps/AppStoreApp.vue')
const appWindow = source('frontend/src/views/PhoneAppWindow.vue')
const client = source('sky_phone/source/client/main.lua')
const config = source('sky_phone/config/config.lua')
const configDefault = source('sky_phone/source/shared/config_default.lua')
const crypto = source('sky_phone/source/server/crypto.lua')
const phone = source('sky_phone/source/server/phone.lua')
const router = source('frontend/src/router/index.ts')

describe('configured app availability contract', () => {
  it('keeps every built-in app in the file and runtime defaults', () => {
    const builtInAppIds = PHONE_APPS.filter(
      (app) =>
        isLaunchablePhoneApp(app) && !app.adminOnly && !isExternalPhoneApp(app),
    ).map((app) => app.id)

    for (const appId of builtInAppIds) {
      const entry = appId.includes('-')
        ? `["${appId}"] = true`
        : `${appId} = true`
      expect(config).toContain(entry)
      expect(configDefault).toContain(entry)
    }
  })

  it('sends disabled apps and reapplies them to an open phone after live saves', () => {
    expect(phone).toContain('disabledApps = SkyPhone.GetDisabledApps()')
    expect(phone).toMatch(
      /function SkyPhone\.GetDisabledApps\(\)[\s\S]*?enabled == false/,
    )
    expect(client).toMatch(
      /configurator:updated[\s\S]*?apply_disabled_apps\(device_payload\)[\s\S]*?device:updated/,
    )
    expect(app).toContain(
      'appStore.hydrate(payload.device?.data.apps?.payload, payload.disabledApps)',
    )
  })

  it('removes disabled apps from every launch path without changing device installs', () => {
    expect(appStore).toContain('disabledApps: [] as LaunchablePhoneAppId[]')
    expect(appStore).toContain('if (!this.isAvailable(appId)) return false')
    expect(appStoreView).toContain('appStore.isAvailable(app.id)')
    expect(router).toContain('useAppStoreStore().isInstalled(to.params.appId)')
    expect(appWindow).toContain('appStore.isInstalled(app.id)')
    expect(app).toMatch(
      /isPhoneAppId\(currentAppId\)[\s\S]*?!appStore\.isInstalled\(currentAppId\)[\s\S]*?router\.push\('\/'\)/,
    )
  })

  it('rejects crypto operations after the app is disabled at runtime', () => {
    expect(crypto).toMatch(
      /local function require_phone\(source\)[\s\S]*?not Config\.Crypto\.Enabled or not SkyPhone\.IsAppEnabled\("crypto"\)/,
    )
    expect(crypto).toMatch(
      /local function refresh_crypto_runtime\(\)[\s\S]*?not Config\.Crypto\.Enabled or not SkyPhone\.IsAppEnabled\("crypto"\)[\s\S]*?sessions = \{\}/,
    )
  })
})
