import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const resource = (path: string) =>
  readFileSync(new URL(`../../sky_phone/${path}`, import.meta.url), 'utf8')
const customTonesServer = resource('source/server/custom_tones.lua')
const databaseMigration = resource('source/server/db_migrate.lua')
const clientMain = resource('source/client/main.lua')
const clientTones = resource('source/client/custom_tones.lua')
const manifest = resource('fxmanifest.lua')
const nuiServerBridge = resource('source/client/nui_server_bridge.lua')
const settingsSource = readFileSync(
  new URL('./views/apps/SettingsApp.vue', import.meta.url),
  'utf8',
)
const adminManager = readFileSync(
  new URL('./components/AdminCustomToneManager.vue', import.meta.url),
  'utf8',
)
const adminStore = readFileSync(
  new URL('./stores/admin.ts', import.meta.url),
  'utf8',
)
const adminPanel = readFileSync(
  new URL('./components/AdminPanel.vue', import.meta.url),
  'utf8',
)
const config = resource('config/config.lua')
const configurator = resource('source/server/phone_configurator.lua')

describe('custom phone tone contract', () => {
  it('stores bounded audio payloads in a phone-owned table', () => {
    expect(databaseMigration).toContain('name = "sky_phone_custom_tones"')
    expect(databaseMigration).toContain(
      '{ name = "audio_payload", type = "MEDIUMTEXT NOT NULL"',
    )
    expect(customTonesServer).toContain('local MAX_TONES_PER_TYPE = 32')
    expect(customTonesServer).toContain('local MAX_AUDIO_BYTES = 2000000')
    expect(customTonesServer).toContain('local MAX_TRANSFER_CHUNK_CHARS = 8000')
    expect(customTonesServer).toContain('local MAX_TRANSFER_CHUNKS = 334')
    expect(customTonesServer).toContain('local MAX_DURATION_MS = 30000')
    expect(customTonesServer).toContain('decoded_base64_size')
    expect(customTonesServer).toContain('valid_audio_signature')
  })

  it('keeps creation and deletion behind server-side admin authorization', () => {
    const adminServer = resource('source/server/admin.lua')
    expect(adminServer).toMatch(
      /^Bridge\.Database\.AfterMigration\("sky_phone", function\(\)/,
    )
    expect(adminServer.trimEnd()).toMatch(/end\)\r?\nend\)$/)
    expect(adminServer).toContain('"sky_phone:admin:tone-upload-start"')
    expect(adminServer).toContain('"sky_phone:admin:tone-upload-chunk"')
    expect(adminServer).toContain(
      'math.max(400, tonumber(Config.AdminPanel.ActionRequestsPerMinute) or 0)',
    )
    expect(adminServer).toContain('"sky_phone:admin:tone-upload-finish"')
    expect(adminServer).toContain('"sky_phone:admin:delete-tone"')
    expect(adminServer).toContain('require_admin(')
    expect(adminServer).toContain('"create_custom_tone"')
    expect(adminServer).toContain('"delete_custom_tone"')
  })

  it('loads metadata on readiness and audio only when it is played', () => {
    expect(clientMain).toContain(
      'Bridge.Callbacks.Trigger("sky_phone:tones:list"',
    )
    expect(clientMain).toContain('type = "phone:tones"')
    expect(customTonesServer).toContain('TriggerLatentClientEvent(')
    expect(customTonesServer).toContain('"sky_phone:tones:audio-request"')
    expect(customTonesServer).toContain('AUDIO_TRANSFER_BYTES_PER_SECOND')
    expect(clientTones).toContain('RegisterNUICallback("tones:audio"')
    expect(clientTones).toContain('"sky_phone:tones:audio-response"')
    expect(clientTones).toContain('AUDIO_TRANSFER_TIMEOUT_MS')
    expect(manifest).toContain("'source/client/custom_tones.lua'")
    expect(nuiServerBridge).not.toContain('audio-start')
    expect(nuiServerBridge).not.toContain('audio-chunk')
    expect(customTonesServer).toContain(
      'SELECT `id`, `mime_type`, `audio_payload`',
    )
  })

  it('offers direct local-file management without a URL field', () => {
    expect(adminManager).toContain('type="file"')
    expect(adminManager).toContain('readAsDataURL(file)')
    expect(adminManager).not.toContain('type="url"')
    expect(adminManager).not.toContain('https://')
    expect(adminManager).not.toContain('fileInput.value?.click()')
    expect(adminManager).toContain(':key="fileInputResetKey"')
    expect(adminManager).toContain('AUDIO_METADATA_TIMEOUT_MS')
    expect(adminManager).toContain('onStarted: () =>')
    expect(adminManager).toContain("t('errors.playback')")
    expect(adminStore).toContain('finally {')
    expect(adminStore).toContain("this.actionKey = ''")
    expect(adminStore).toContain('cacheCustomPhoneTonePayload(')
    expect(adminPanel).toContain("| 'tones'")
    expect(adminPanel).toContain("selectTab('tones')")
  })

  it('supports URL-free file configuration outside the phone panel', () => {
    expect(config).toContain('Config.CustomTones = {')
    expect(config).toContain('config/custom_tones/')
    expect(customTonesServer).toContain('LoadResourceFile(')
    expect(configurator).toContain('CustomTones = true')
    expect(configurator).toContain('and key ~= "CustomTones"')
  })

  it('shows built-in and custom choices in both sound categories', () => {
    expect(settingsSource).toContain('phone.customTones.ringtones.map')
    expect(settingsSource).toContain('phone.customTones.notificationSounds.map')
    expect(settingsSource).toContain('v-for="ringtone in ringtoneChoices"')
    expect(settingsSource).toContain(
      'v-for="sound in notificationSoundChoices"',
    )
  })
})
