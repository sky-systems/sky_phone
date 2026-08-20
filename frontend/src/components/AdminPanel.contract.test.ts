import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./AdminPanel.vue', import.meta.url),
  'utf8',
)
const app = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')
const apps = readFileSync(new URL('../config/apps.ts', import.meta.url), 'utf8')
const store = readFileSync(
  new URL('../stores/admin.ts', import.meta.url),
  'utf8',
)
const server = readFileSync(
  new URL('../../../sky_phone/source/server/admin.lua', import.meta.url),
  'utf8',
)
const phoneServer = readFileSync(
  new URL('../../../sky_phone/source/server/phone.lua', import.meta.url),
  'utf8',
)
const phoneClient = readFileSync(
  new URL('../../../sky_phone/source/client/main.lua', import.meta.url),
  'utf8',
)
const focusClient = readFileSync(
  new URL('../../../sky_phone/source/client/focus.lua', import.meta.url),
  'utf8',
)
const bridge = readFileSync(
  new URL(
    '../../../sky_phone/source/client/nui_server_bridge.lua',
    import.meta.url,
  ),
  'utf8',
)
const config = readFileSync(
  new URL('../../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
)
const schema = readFileSync(
  new URL('../../../sky_phone/sql/install.sql', import.meta.url),
  'utf8',
)

describe('standalone admin panel contracts', () => {
  it('renders as a dedicated full-screen editor outside the phone shell', () => {
    expect(apps).not.toContain("id: 'admin'")
    expect(app).toContain("event.data?.type === 'admin:open'")
    expect(app).toContain('v-if="adminPanelOpen"')
    expect(app).toContain('<AdminPanel')
    expect(source).toContain("import { SkyButton } from '@/ui'")
    expect(source).toContain('class="admin-panel-overlay"')
    expect(source).toContain('class="admin-panel-rail"')
    expect(source).toContain('class="admin-panel-directory"')
    expect(source).toContain('class="admin-panel-editor"')
    expect(source).toContain('pointer-events: auto')
    expect(source).toContain('@media (prefers-reduced-motion: reduce)')
  })

  it('stages app changes locally and saves them only from the toolbar action', () => {
    expect(source).toContain('const drafts = ref<')
    expect(source).toContain('@click="saveChanges"')
    expect(source).toContain("t('editor.noAutoSave')")
    expect(store).toContain("'admin:save-apps'")
    expect(store).not.toContain("'admin:set-app'")
    expect(server).toContain(
      'Bridge.Callbacks.Register("sky_phone:admin:save-apps"',
    )
  })

  it('connects every operation through the standard NUI callback bridge', () => {
    expect(bridge).toContain(
      'admin = [[bootstrap player save-apps reveal-password]]',
    )
    for (const endpoint of [
      'admin:bootstrap',
      'admin:player',
      'admin:save-apps',
      'admin:reveal-password',
    ]) {
      expect(store).toContain(endpoint)
    }
  })

  it('authorizes every server request without requiring a phone session', () => {
    expect(server).not.toContain('SkyPhone.RequireSession(source)')
    expect(server).toContain(
      'Bridge.Framework.HasAdminGroup(source, Config.AdminPanel.AdminGroups)',
    )
    expect(server).toContain('Config.AdminPanel.ReadRequestsPerMinute')
    expect(server).toContain('Config.AdminPanel.ActionRequestsPerMinute')
    expect(server).toContain('Config.AdminPanel.CredentialRevealsPerMinute')
    expect(config).toContain('Config.AdminPanel = {')
  })

  it('opens directly from the configurable command with dedicated focus', () => {
    expect(config).toContain('Command = "phoneadmin"')
    expect(server).toContain(
      'RegisterCommand(Config.AdminPanel.Command, function(command_source)',
    )
    expect(server).toContain(
      'TriggerClientEvent("sky_phone:admin:launch", player_source)',
    )
    expect(phoneServer).not.toContain(
      'RegisterCommand(Config.AdminPanel.Command',
    )
    expect(phoneClient).toContain('RegisterNetEvent("sky_phone:admin:launch"')
    expect(phoneClient).toContain('SkyPhoneFocus.SetAdminPanel(true)')
    expect(focusClient).toContain('function SkyPhoneFocus.SetAdminPanel(open)')
  })

  it('validates ownership, app policy, and revision before a batch mutation', () => {
    expect(server).toContain('find_owned_device(target_source, data.imei)')
    expect(server).toContain('app_metadata(change.appId)')
    expect(server).toContain('error = "device_not_owned"')
    expect(server).toContain('error = "app_protected"')
    expect(server).toContain('AND `revision` = ?')
    expect(server).toContain('SkyPhone.RefreshDevice(data.imei)')
  })

  it('gates plaintext account reveals behind confirmation and audit logging', () => {
    expect(source).toContain('revealDialogImei')
    expect(source).toContain("t('credentials.revealTitle')")
    expect(server).toContain('"reveal_account_password"')
    expect(server).toContain('write_audit(')
    expect(server).not.toContain('passcode_hash` AS')
    expect(schema).toContain(
      'CREATE TABLE IF NOT EXISTS `sky_phone_admin_audit`',
    )
  })
})
