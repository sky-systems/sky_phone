import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./AdminApp.vue', import.meta.url), 'utf8')
const store = readFileSync(
  new URL('../../stores/admin.ts', import.meta.url),
  'utf8',
)
const server = readFileSync(
  new URL('../../../../sky_phone/source/server/admin.lua', import.meta.url),
  'utf8',
)
const bridge = readFileSync(
  new URL(
    '../../../../sky_phone/source/client/nui_server_bridge.lua',
    import.meta.url,
  ),
  'utf8',
)
const config = readFileSync(
  new URL('../../../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
)
const schema = readFileSync(
  new URL('../../../../sky_phone/sql/install.sql', import.meta.url),
  'utf8',
)

describe('admin command center contracts', () => {
  it('uses the shared Sky UI with one scroll owner and no Konsta imports', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    for (const component of [
      'SkyAppPage',
      'SkyNavbar',
      'SkyScrollArea',
      'SkySearchbar',
      'SkyDialog',
      'SkyCard',
    ]) {
      expect(source).toContain(`<${component}`)
    }
    expect(source.match(/<SkyScrollArea/g)).toHaveLength(2)
    expect(source).toContain('<template v-if="admin.selectedPlayer">')
    expect(source).toContain('<template v-else>')
    expect(source).toContain('@media (prefers-reduced-motion: reduce)')
  })

  it('connects each admin operation through the standard NUI callback bridge', () => {
    expect(bridge).toContain(
      'admin = [[bootstrap player set-app reveal-password]]',
    )
    for (const endpoint of [
      'admin:bootstrap',
      'admin:player',
      'admin:set-app',
      'admin:reveal-password',
    ]) {
      expect(store).toContain(endpoint)
    }
  })

  it('authorizes every server request and applies separate rate limits', () => {
    expect(server).toContain('SkyPhone.RequireSession(source)')
    expect(server).toContain(
      'Bridge.Framework.HasAdminGroup(source, Config.AdminPanel.AdminGroups)',
    )
    expect(server).toContain('Config.AdminPanel.ReadRequestsPerMinute')
    expect(server).toContain('Config.AdminPanel.ActionRequestsPerMinute')
    expect(server).toContain('Config.AdminPanel.CredentialRevealsPerMinute')
    expect(config).toContain('Config.AdminPanel = {')
  })

  it('validates ownership and app policy before remote device mutation', () => {
    expect(server).toContain('find_owned_device(target_source, data.imei)')
    expect(server).toContain('app_metadata(data.appId)')
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
    expect(schema).toContain('CREATE TABLE IF NOT EXISTS `sky_phone_admin_audit`')
  })
})
