import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(
    new URL(`../../sky_phone/${path}`, import.meta.url),
    'utf8',
  ).replace(/\r\n/g, '\n')

describe('housing provider contracts', () => {
  it('registers TGIANN House with server-authorized owner properties', () => {
    const adapter = readResourceFile('source/bridge/server/housing/tgiann.lua')

    expect(adapter).toContain('local resource_name = "tgiann-house"')
    expect(adapter).toContain('FROM `tgiann_house`')
    expect(adapter).toContain('WHERE `owner` = ?')
    expect(adapter).toContain('Bridge.Framework.GetIdentifier(source)')
    expect(adapter).toContain(
      'Bridge.Housing.RegisterProvider(provider_name, {',
    )
    expect(adapter).toContain('return nil, "property_access_denied"')
    expect(adapter).not.toContain('`houseKeys`')
    expect(adapter).not.toContain('tgiann-house:getPlayerHouses')
  })

  it('uses the published client export for entrance waypoints only', () => {
    const adapter = readResourceFile('source/bridge/client/housing/tgiann.lua')

    expect(adapter).toContain(
      'return exports[resource_name]:getHouseData(house)',
    )
    expect(adapter).toContain(
      'Bridge.Normalize.Coordinates(house_data.doorCoord)',
    )
    expect(adapter).toContain(
      'Bridge.Housing.RegisterClientProvider(provider_name, {',
    )
    expect(adapter).toContain('SetNewWaypoint(')
    expect(adapter).not.toContain('enterHouse(')
    expect(adapter).not.toContain('forceOpenDoorHouse')
  })

  it('advertises TGIANN in housing configuration and documentation', () => {
    const config = readResourceFile('config/config.lua')
    const readme = readFileSync(
      new URL('../../README.md', import.meta.url),
      'utf8',
    )

    expect(config).toContain(
      '"rtx", "quasar", "tgiann", "vms", "rx", "nolag", "sn"',
    )
    expect(readme).toContain('Quasar Housing, TGIANN House, VMS Housing')
    expect(readme).toContain('`quasar`, `tgiann`, `vms`')
    expect(readme).toContain(
      'expects `tgiann-core` to start before `tgiann-house`',
    )
    expect(readme).toContain(
      'lists server-authorized owner properties, and supports entrance waypoints',
    )
  })
})
