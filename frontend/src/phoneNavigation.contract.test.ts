import { readFileSync } from 'node:fs'
import { join } from 'node:path'

import { describe, expect, it } from 'vitest'

const rootDirectory = join(import.meta.dirname, '..')
const appSource = readFileSync(join(rootDirectory, 'src/App.vue'), 'utf8')
const navigationSource = readFileSync(
  join(rootDirectory, '../sky_phone/source/client/navigation.lua'),
  'utf8',
)

describe('neutral phone navigation contract', () => {
  it('synchronizes installed renderer apps before acknowledging an opened phone', () => {
    expect(appSource).toContain("return nuiCall('navigation:state'")
    expect(appSource).toContain(
      "void syncNavigationState().then(() => nuiCall('ui:opened'))",
    )
    expect(navigationSource).toContain(
      'RegisterNUICallback("navigation:state"',
    )
  })

  it('routes only installed apps and closes only the requested current app', () => {
    expect(appSource).toContain("event.data?.type === 'navigation:open-app'")
    expect(appSource).toContain('appStore.isInstalled(data.appId)')
    expect(appSource).toContain("event.data?.type === 'navigation:close-app'")
    expect(appSource).toContain('currentApp === data.appId')
    expect(navigationSource).toContain('if not installed_apps[normalized_app_id] then')
    expect(navigationSource).toContain('if current_app_id ~= normalized_app_id then')
  })

  it('defers command-driven app routes until setup or device unlock completes', () => {
    expect(appSource).toContain('if (setupRequired.value || isLocked.value)')
    expect(appSource).toContain('pendingUnlockRoute.value = requestedRoute')
    expect(appSource).toContain("void router.replace(requestedRoute ?? '/')")
  })
})
