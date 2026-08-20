import { readFileSync } from 'node:fs'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import AppProfileAuth from './AppProfileAuth.vue'

const source = readFileSync(
  new URL('./AppProfileAuth.vue', import.meta.url),
  'utf8',
)

async function renderAuth(
  mode: 'login' | 'register',
  movingModeHighlight = true,
): Promise<string> {
  return renderToString(
    createSSRApp({
      render: () =>
        h(AppProfileAuth, {
          avatarUrl: null,
          body: 'Use the linked account.',
          cameraLabel: 'Camera',
          email: 'demo@ifruit.com',
          emailLabel: 'SkyPic account',
          error: '',
          eyebrow: 'Your SkyPic account',
          galleryLabel: 'Photos',
          loginLabel: 'Continue to SkyPic',
          loginModeLabel: 'Login',
          mode,
          movingModeHighlight,
          pending: false,
          registerLabel: 'Create profile',
          registerModeLabel: 'Register',
          title: 'Welcome back',
          username: mode === 'login' ? 'alexm' : 'newprofile',
          usernameLabel: 'Handle',
        }),
    }),
  )
}

describe('AppProfileAuth', () => {
  it('uses the rounded Sky UI moving highlight for its mode switch', async () => {
    const html = await renderAuth('login')

    expect(html).toContain('sky-segmented--strong')
    expect(html).toContain('sky-segmented--rounded')
    expect(html).toContain('sky-segmented__highlight')
    expect(html).toContain('app-profile-auth__mode--moving-highlight')
    expect(html).toContain('width:calc(50% - 4px)')
    expect(html).toContain('--sky-segmented-indicator-offset:calc(0% + 0px)')
    expect(html).toContain('aria-label="Your SkyPic account"')
  })

  it('moves the highlight and keeps short mode labels separate from actions', async () => {
    const html = await renderAuth('register')

    expect(html).toContain('--sky-segmented-indicator-offset:calc(100% + 4px)')
    expect(html.match(/Login/g)).toHaveLength(1)
    expect(html.match(/Register/g)).toHaveLength(1)
    expect(html).toContain('Create profile')
    expect(html).not.toContain('>Continue to SkyPic</button>')
  })

  it('keeps the moving highlight opt-in for SkyPic', async () => {
    const html = await renderAuth('login', false)

    expect(html).not.toContain('sky-segmented--strong')
    expect(html).not.toContain('sky-segmented__highlight')
    expect(html).toContain('app-profile-auth__mode-button--login')
    expect(html).toContain('app-profile-auth__mode-button--active')
    expect(source).toContain(':strong="movingModeHighlight"')
    expect(source).toContain(
      ':not(.app-profile-auth__mode--moving-highlight)',
    )
  })
})
