import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const crewLinkSource = readFileSync(
  new URL('./CrewLinkApp.vue', import.meta.url),
  'utf8',
)
const authSource = readFileSync(
  new URL('../../components/account/AppProfileAuth.vue', import.meta.url),
  'utf8',
)
const testServerSource = readFileSync(
  new URL('../../../testserver/index.cjs', import.meta.url),
  'utf8',
)

describe('CrewLink authentication fields', () => {
  it('shows only the password on login and adds the username on registration', () => {
    expect(crewLinkSource).toContain('variant="centered"')
    expect(crewLinkSource).toContain('require-password')
    expect(authSource).toContain(
      `v-if="variant !== 'centered' || mode === 'register' || !requirePassword"`,
    )
  })

  it('starts regular browser test data with an authenticated CrewLink profile', () => {
    expect(testServerSource).toMatch(
      /crewLinkAuthenticated = !\[[\s\S]*'crewlink-login',[\s\S]*'crewlink-register',[\s\S]*\]\.includes\(testScenario\)/,
    )
  })

  it('keeps labels inside the CrewLink field surface', () => {
    expect(crewLinkSource).toContain(
      '.crewlink-auth :deep(.app-profile-auth__credential-field)',
    )
    expect(crewLinkSource).toContain('background: transparent;')
    expect(crewLinkSource).toContain(
      '.app-profile-auth__credential-field:focus-within',
    )
  })

  it('locks the selected profile photo to the square avatar surface', () => {
    expect(authSource).toContain('aspect-ratio: 1;')
    expect(authSource).toMatch(
      /\.app-profile-auth__photo img \{[\s\S]*position: absolute;[\s\S]*inset: 0;/,
    )
  })

  it('renders the mode switch as two consistently rounded tabs', () => {
    expect(crewLinkSource).toContain(
      '.crewlink-auth :deep(.app-profile-auth__mode)',
    )
    expect(crewLinkSource).toContain(
      'border-radius: var(--sky-radius-pill, 999px) !important;',
    )
    expect(crewLinkSource).toContain(
      '.crewlink-auth :deep(.app-profile-auth__mode-button--active)',
    )
    expect(crewLinkSource).toContain(
      'background: var(--sky-app-accent-shade) !important;',
    )
    expect(authSource).toContain(
      `'app-profile-auth__mode--register': mode === 'register'`,
    )
    expect(crewLinkSource).toContain('color: var(--sky-text);')
  })

  it('centres the ping count inside its navigation badge', () => {
    expect(crewLinkSource).toMatch(
      /\.crewlink-pings-badge\) \{[\s\S]*display: grid;[\s\S]*min-height: 16px;[\s\S]*place-items: center;[\s\S]*line-height: 1;/,
    )
  })
})
