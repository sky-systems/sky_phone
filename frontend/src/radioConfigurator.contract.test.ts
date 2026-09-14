import { readdirSync, readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'
import { collectLuaLocaleValues } from './testing/lua-locale'

const resourceSource = (path: string): string =>
  readFileSync(
    new URL(`../../sky_phone/${path}`, import.meta.url),
    'utf8',
  ).replace(/\r\n/g, '\n')

const configSource = resourceSource('config/config.lua')
const configuratorSource = resourceSource(
  'source/server/phone_configurator.lua',
)
const radioSource = resourceSource('source/server/radio.lua')
const editorSource = readFileSync(
  new URL('./components/AdminConfigValueEditor.vue', import.meta.url),
  'utf8',
)

describe('radio configurator access contract', () => {
  it('lets the server allow everyone or enforce configured job grades', () => {
    expect(configSource).toMatch(
      /DisplayName\s*=\s*\{[\s\S]*?AllowEveryone\s*=\s*false,[\s\S]*?AllowedJobs\s*=\s*\{/,
    )

    const start = radioSource.indexOf(
      'local function can_set_display_name(source)',
    )
    const end = radioSource.indexOf(
      '\nlocal function normalize_display_name',
      start,
    )
    const permissionSource = radioSource.slice(start, end)

    expect(permissionSource).toContain('if config.AllowEveryone == true then')
    expect(permissionSource.indexOf('config.AllowEveryone')).toBeLessThan(
      permissionSource.indexOf('Bridge.Framework.GetJob(source)'),
    )
    expect(permissionSource).toContain('config.AllowedJobs[job.name]')
    expect(permissionSource).toContain('(tonumber(job.grade) or 0)')
  })

  it('keeps both radio job tables mutable and validates their value types', () => {
    expect(configuratorSource).toContain(
      'path == "Radio.DisplayName.AllowedJobs"',
    )
    expect(configuratorSource).toContain(
      'path:match("^Radio%.LockedChannels%.%d+%.jobs$")',
    )
    expect(configuratorSource).toContain(
      'if radio_job_entry_default(path) ~= nil then\n        return copy_value(saved)',
    )
    expect(configuratorSource).toMatch(
      /entryDefault = radio_job_default,[\s\S]*?mutableKeys = true,[\s\S]*?valueType = type\(radio_job_default\)/,
    )
    expect(configuratorSource).toContain('not key:match("^[a-z0-9_-]+$")')
  })

  it('shows a compact job-name input for both radio job tables', () => {
    expect(editorSource).toContain(
      "props.path === 'Radio.DisplayName.AllowedJobs'",
    )
    expect(editorSource).toContain(
      String.raw`/^Radio\.LockedChannels\[\d+\]\.jobs$/`,
    )
    expect(editorSource).toContain(
      'isJobTable ? labels.jobPlaceholder : labels.keyPlaceholder',
    )
    expect(editorSource).toContain(
      'isJobTable ? labels.addJob : labels.addField',
    )
    expect(editorSource).toContain('function updateNewObjectKey(event: Event)')
    expect(editorSource).toContain('.toLowerCase()')
    expect(editorSource).toContain(".replace(/[^a-z0-9_-]/g, '')")
    expect(editorSource).toContain('.slice(0, 64)')

    const localeDirectory = new URL(
      '../../sky_phone/config/locales/',
      import.meta.url,
    )
    for (const file of readdirSync(localeDirectory).filter((name) =>
      name.endsWith('.lua'),
    )) {
      const values = collectLuaLocaleValues(
        resourceSource(`config/locales/${file}`),
      )
      expect(values.get('Nui.AdminPanel.configurator.table.addJob')).toMatch(
        /\S/,
      )
      expect(
        values.get('Nui.AdminPanel.configurator.table.jobPlaceholder'),
      ).toMatch(/\S/)
    }
  })
})
