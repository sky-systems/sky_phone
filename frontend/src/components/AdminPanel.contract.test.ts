import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./AdminPanel.vue', import.meta.url),
  'utf8',
)
const agentInstructions = readFileSync(
  new URL('../../../AGENTS.md', import.meta.url),
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
const persistenceServer = readFileSync(
  new URL(
    '../../../sky_phone/source/server/phone_persistence.lua',
    import.meta.url,
  ),
  'utf8',
)
const simServer = readFileSync(
  new URL('../../../sky_phone/source/server/sim.lua', import.meta.url),
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
const mediaConfig = readFileSync(
  new URL('../../../sky_phone/config/media.lua', import.meta.url),
  'utf8',
)
const schema = readFileSync(
  new URL('../../../sky_phone/sql/install.sql', import.meta.url),
  'utf8',
)
const manifest = readFileSync(
  new URL('../../../sky_phone/fxmanifest.lua', import.meta.url),
  'utf8',
)
const configuratorServer = readFileSync(
  new URL(
    '../../../sky_phone/source/server/phone_configurator.lua',
    import.meta.url,
  ),
  'utf8',
)
const configDefault = readFileSync(
  new URL(
    '../../../sky_phone/source/shared/config_default.lua',
    import.meta.url,
  ),
  'utf8',
)
const frontendBuild = readFileSync(
  new URL('../../build.cjs', import.meta.url),
  'utf8',
)
const configuratorClient = readFileSync(
  new URL(
    '../../../sky_phone/source/client/phone_configurator.lua',
    import.meta.url,
  ),
  'utf8',
)
const mediaImportServer = readFileSync(
  new URL('../../../sky_phone/source/server/media_import.lua', import.meta.url),
  'utf8',
)
const configuratorValueEditor = readFileSync(
  new URL('./AdminConfigValueEditor.vue', import.meta.url),
  'utf8',
)
const configInputWidth = readFileSync(
  new URL('../directives/configInputWidth.ts', import.meta.url),
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

  it('uses a compact transparent shell with dedicated admin workspaces', () => {
    expect(source).toContain('background: transparent')
    expect(source).toContain('width: min(76vw, 1220px)')
    expect(source).toContain('height: min(74vh, 700px)')
    expect(source).toContain('--admin-row-hover: linear-gradient')
    expect(source).toContain('--admin-row-active: linear-gradient')
    expect(source).toContain('background: var(--admin-nav-active)')
    expect(source).not.toContain('admin-panel-brand__mark')
    expect(source).not.toContain('admin-panel-profile-heading__status')
    expect(source).not.toContain('backdrop-filter: blur(2px)')
    expect(source).not.toContain("t('overview.recent')")

    for (const tab of [
      'overview',
      'players',
      'devices',
      'apps',
      'accounts',
      'messages',
      'calls',
      'moderation',
      'audit',
      'configurator',
    ]) {
      expect(source).toContain(`selectTab('${tab}')`)
      expect(source).toContain(`t('tabs.${tab}')`)
    }
  })

  it('removes manual reload and applies a persistent global accent choice', () => {
    expect(source).not.toContain('<RefreshCw')
    expect(source).not.toContain("kind: 'refresh'")
    expect(source).toContain("'sky-phone-admin-accent'")
    expect(source).toContain("'sky-phone-admin-font-family'")
    expect(source).toContain("'sky-phone-admin-font-size'")
    expect(source).toContain("'--admin-accent': accentColor")
    expect(source).toContain("'--admin-font-family': activeAdminFontFamily")
    expect(source).toContain(
      "'--admin-font-scale': String(adminFontSize / 100)",
    )
    expect(source).toContain('class="admin-panel-color-value"')
    expect(source).toContain('class="admin-panel-rgb-fields"')
    expect(source).toContain('class="admin-panel-rgb-range"')
    expect(source).toContain('class="admin-panel-font-select"')
    expect(source).toContain('class="admin-panel-font-select__menu"')
    expect(source).toContain('class="admin-panel-font-size-control"')
    expect(source).not.toContain('type="color"')
    expect(source).toContain('color-mix(in srgb, var(--admin-green)')
    expect(source).toContain('--admin-toggle-on: #63d471')
    expect(source).toContain('background: var(--admin-toggle-on)')
    expect(configuratorValueEditor).toContain(
      'background: var(--admin-toggle-on)',
    )
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
    expect(bridge).toContain('admin = [[')
    for (const endpoint of [
      'admin:bootstrap',
      'admin:player',
      'admin:save-apps',
      'admin:reveal-password',
      'admin:activity',
      'admin:reset-passcode',
      'admin:change-number',
      'admin:factory-reset',
      'admin:configurator',
      'admin:save-configurator',
    ]) {
      expect(store).toContain(endpoint)
    }
  })

  it('protects activity views and device moderation with ownership and audit checks', () => {
    for (const endpoint of [
      'activity',
      'reset-passcode',
      'change-number',
      'factory-reset',
    ]) {
      expect(server).toContain(
        `Bridge.Callbacks.Register("sky_phone:admin:${endpoint}"`,
      )
    }
    expect(server).toContain('data.kind ~= "messages"')
    expect(server).toContain('data.kind ~= "calls"')
    expect(server).toContain('"view_messages"')
    expect(server).toContain('"view_calls"')
    expect(server).toContain('"reset_passcode"')
    expect(server).toContain('"change_number"')
    expect(server).toContain('"factory_reset"')
    expect(simServer).toContain('function SkyPhoneSim.ChangeNumber(')
    expect(simServer).toContain('UPDATE IGNORE `sky_phone_sims`')
    expect(persistenceServer).toContain(
      'function SkyPhonePersistence.FactoryReset(imei)',
    )
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
    expect(config).toContain('Command = "phonepanel"')
    expect(server).toContain('local command_name = Config.AdminPanel.Command')
    expect(server).toContain(
      'RegisterCommand(command_name, function(command_source)',
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

  it('loads the SQL phone configurator before framework-owned configuration is read', () => {
    expect(agentInstructions).toContain('Phone Configurator parity (mandatory)')
    expect(agentInstructions).toContain(
      'changes without matching Configurator support are incomplete',
    )
    expect(config).toMatch(
      /Config\.PhoneConfigurator\s*=\s*\{[\s\S]*?Enabled\s*=\s*true[\s\S]*?Config\.Bridge\s*=/,
    )
    expect(schema).toContain(
      'CREATE TABLE IF NOT EXISTS `sky_phone_configurator`',
    )
    expect(
      manifest.indexOf("'source/shared/config_default.lua'"),
    ).toBeGreaterThan(manifest.indexOf("'config/media.lua'"))
    expect(
      manifest.indexOf("'source/shared/config_default.lua'"),
    ).toBeLessThan(manifest.indexOf("'source/server/phone_configurator.lua'"))
    expect(
      manifest.indexOf("'source/server/phone_configurator.lua'"),
    ).toBeLessThan(manifest.indexOf("'source/bridge/server/framework.lua'"))
    expect(
      manifest.indexOf("'source/client/phone_configurator.lua'"),
    ).toBeLessThan(manifest.indexOf("'source/bridge/client/framework.lua'"))
    expect(configuratorServer).toContain('AND `revision` = ?')
    expect(configuratorServer).toContain('configurator_enabled')
    expect(configuratorServer).toMatch(
      /for key, value in pairs\(ConfigDefaults\)[\s\S]*?key ~= "Media"[\s\S]*?key ~= "PhoneConfigurator"/,
    )
    expect(configuratorServer).toContain(
      'default_media = serialize_value(ConfigDefaults.Media)',
    )
    expect(configDefault).toContain(
      'GENERATED by frontend/build.cjs from config/config.lua and config/media.lua',
    )
    expect(configDefault).toContain('local realConfig = Config')
    expect(configDefault).toContain('ConfigDefaults = Config')
    expect(configDefault.replace(/\r\n?/g, '\n').trimEnd()).toBe(
      [
        '-- GENERATED by frontend/build.cjs from config/config.lua and config/media.lua - do not edit.',
        '-- Escrowed snapshot of the shipped defaults used by the Phone Configurator.',
        'local realConfig = Config',
        'Config = {}',
        '',
        config.replace(/\r\n?/g, '\n').trimEnd(),
        '',
        mediaConfig.replace(/\r\n?/g, '\n').trimEnd(),
        '',
        'ConfigDefaults = Config',
        'Config = realConfig',
      ].join('\n'),
    )
    expect(frontendBuild).toContain("readLuaSource('config', 'config.lua')")
    expect(frontendBuild).toContain("readLuaSource('config', 'media.lua')")
    expect(frontendBuild).toContain("'config_default.lua'")
    expect(configuratorServer).toContain(
      'build_sections("config", stored_config',
    )
    expect(configuratorServer).toContain('build_sections("media", stored_media')
    expect(configuratorServer).toContain('sensitive_path')
    expect(configuratorServer).toContain('restore_redacted_values')
    expect(configuratorServer).toContain(
      '{ __skyType = "map", entries = entries }',
    )
    expect(configuratorServer).toContain('validate_structured_value')
    expect(configuratorServer).toContain('validate_locked_structure')
    expect(configuratorServer).toContain('build_structure(default_value')
    expect(configuratorServer).toContain('path == "Companies.Definitions"')
    expect(configuratorServer).toContain('flatten_company_fields')
    expect(configuratorServer).toContain('structure.mutableKeys')
    expect(configuratorServer).toContain('local function empty_structure(')
    expect(configuratorServer).toContain('template = items[1]')
    expect(configuratorServer).toContain('structure.template')
    expect(configuratorServer).toContain('if not structure.fields[key] then')
    expect(configuratorServer).toContain('field.type == "stringOrFalse"')
    expect(configuratorServer).not.toContain('Config.Media = client_payload')
    expect(configuratorServer).toContain(
      'apply_runtime_table(Config[key], value)',
    )
    expect(configuratorServer).toContain(
      'apply_runtime_table(Config.Media, runtime_media)',
    )
    expect(configuratorServer).toContain('local function read_stored_row()')
    expect(configuratorServer).toContain('local function apply_stored_row(row)')
    expect(configuratorServer).toContain(
      'persisted_row.media_payload ~= media_encoded',
    )
    expect(configuratorServer).toContain(
      'Phone configurator SQL verification failed',
    )
    expect(server).not.toContain('ExecuteCommand(("restart %s")')
    expect(configuratorServer).not.toContain('clear_runtime_table')
    expect(configuratorServer).toContain(
      'TriggerEvent("sky_phone:configurator:serverUpdated", revision)',
    )
    expect(configuratorServer).toContain(
      'function SkyPhoneConfigurator.Broadcast(target)',
    )
    expect(configuratorServer).toContain('SkyPhoneConfigurator.Broadcast(-1)')
    expect(configuratorServer).toContain('through the internal runtime refresh')
    expect(configuratorClient).toContain(
      'Bridge.Callbacks.Trigger("sky_phone:configurator:runtime"',
    )
    expect(configuratorClient).toContain(
      'apply_runtime_table(Config[key], value)',
    )
    expect(configuratorClient).not.toContain('clear_runtime_table')
    expect(configuratorClient).toContain(
      'TriggerEvent("sky_phone:configurator:updated"',
    )
    expect(phoneClient).toMatch(
      /AddEventHandler\("sky_phone:configurator:updated"[\s\S]*?SkyPhoneLocales\.Resolve\(Config\.Bridge\.Locale\)[\s\S]*?SkyPhoneApps\.SendCatalog\(\)[\s\S]*?type = "device:updated"/,
    )
    expect(server).toContain(
      'AddEventHandler("sky_phone:configurator:serverUpdated"',
    )
    expect(phoneServer).toContain('register_configured_phone_item()')
    expect(phoneServer).toContain(
      'AddEventHandler("sky_phone:configurator:serverUpdated"',
    )
    expect(simServer).toContain('refresh_sim_types()')
    expect(simServer).toContain(
      'AddEventHandler("sky_phone:configurator:serverUpdated"',
    )
    expect(mediaImportServer).toContain('local website = {}')
    expect(mediaImportServer).toContain('website._adapter = adapter')
    expect(mediaImportServer).not.toContain('definition._adapter = adapter')
    expect(mediaImportServer).toMatch(
      /AddEventHandler\("sky_phone:configurator:serverUpdated"[\s\S]*?if initialized then[\s\S]*?build_registry\(\)/,
    )
    expect(source).toContain('class="admin-panel-rail__configurator"')
    expect(source).toContain(
      '.admin-panel-rail .admin-panel-rail__configurator',
    )
    expect(source).toContain('<AdminConfigValueEditor')
    expect(source).toContain('function configuratorFieldRepeatsSection(')
    expect(source).toContain('v-if="!configuratorFieldRepeatsSection(field)"')
    expect(source).toContain('class="admin-panel-config-scopes"')
    expect(source).toContain("selectConfiguratorScope('config')")
    expect(source).toContain("selectConfiguratorScope('media')")
    expect(source).not.toContain('class="admin-panel-config-meta"')
    expect(configuratorValueEditor).toContain('function addListRow()')
    expect(configuratorValueEditor).toContain('function addTableField()')
    expect(configuratorValueEditor).toContain(
      'const canExtendTable = computed(',
    )
    expect(configuratorValueEditor).toContain(
      'tableStructure.value.mutableKeys === true',
    )
    expect(configuratorValueEditor).toContain(
      'const usesFixedTableLayout = computed(',
    )
    expect(configuratorValueEditor).toContain(
      "'is-fixed-table': usesFixedTableLayout",
    )
    expect(configuratorValueEditor).toContain('v-if="!usesFixedTableLayout"')
    expect(configuratorValueEditor).toContain(
      '.config-structured-editor.is-fixed-table',
    )
    expect(configuratorValueEditor).toContain('v-else-if="canExtendTable"')
    expect(configuratorValueEditor).toContain('function removeListRow(')
    expect(configuratorValueEditor).toContain('function removeTableField(')
    expect(configuratorValueEditor).toContain('function addMapEntry()')
    expect(configuratorValueEditor).toContain('function updateMapKey(')
    expect(configuratorValueEditor).toContain('fixedMapEntryStructure(current)')
    expect(configuratorValueEditor).toContain('listStructure?.items[index]')
    expect(configuratorValueEditor).toContain('function listItemStructure(')
    expect(configuratorValueEditor).toContain('const listTemplate = computed(')
    expect(configuratorValueEditor).toContain('function structureTypeLabel(')
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__fixed-type"',
    )
    expect(configuratorValueEditor).toContain(
      'const rootTableTabs = computed<RootTableTab[]>(',
    )
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__tabs"',
    )
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__tab-panel"',
    )
    expect(source).toContain(':tab-label="configuratorSubtabLabel"')
    expect(source).toContain('configurator.table.subtabs.${key}')
    expect(configuratorValueEditor).toContain(
      'props.tabLabel?.(key, tableValue.value[key]) ?? key',
    )
    expect(source).toContain('v-config-input-width')
    expect(configuratorValueEditor).toContain('v-config-input-width')
    expect(configInputWidth).toContain("input.addEventListener('input'")
    expect(configInputWidth).toContain('input.scrollWidth')
    expect(source).toContain('filter: drop-shadow')
    expect(source).toContain("input[type='number']::-webkit-inner-spin-button")
    expect(configuratorValueEditor).toContain(
      "input[type='number']::-webkit-inner-spin-button",
    )
    expect(source).toContain('justify-self: start')
    expect(configuratorValueEditor).toContain('function tableFieldStructure(')
    expect(configuratorValueEditor).toContain('function isFixedTableField(')
    expect(configuratorValueEditor).toContain('function blankCollectionValue(')
    expect(configuratorValueEditor).toContain('function blankFromStructure(')
    expect(source).toContain("'is-structured': field.type === 'json'")
    expect(configuratorValueEditor).toContain('function isStructuredValue(')
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__add-field is-list"',
    )
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__actions"',
    )
    expect(configuratorValueEditor).toContain('function toggleStructuredEntry(')
    expect(configuratorValueEditor).toContain(
      'class="config-structured-editor__section-toggle"',
    )
    expect(configuratorValueEditor).toContain(':aria-expanded=')
    expect(configuratorValueEditor).toContain(
      '@media (prefers-reduced-motion: reduce)',
    )
    expect(configuratorValueEditor).toContain(
      '.config-structured-editor__property.has-structured-value',
    )
    expect(configuratorValueEditor).not.toContain('<textarea')
  })
})
