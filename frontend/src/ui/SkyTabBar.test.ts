import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyTabBar from '@/ui/SkyTabBar.vue'

describe('SkyTabBar', () => {
  const source = readFileSync(
    fileURLToPath(new URL('./SkyTabBar.vue', import.meta.url)),
    'utf8',
  )
  const foundation = readFileSync(
    fileURLToPath(new URL('./foundation.css', import.meta.url)),
    'utf8',
  )
  const controls = readFileSync(
    fileURLToPath(new URL('./controls.css', import.meta.url)),
    'utf8',
  )
  const mainCss = readFileSync(
    fileURLToPath(new URL('../assets/main.css', import.meta.url)),
    'utf8',
  )

  it('uses the Konsta-style floating glass capsule by default', async () => {
    const html = await renderToString(
      createSSRApp(SkyTabBar, { label: 'Navigation' }),
    )

    expect(html).toContain('sky-tabbar sky-tabbar--floating')
    expect(html).toContain('sky-tabbar--icons')
    expect(html).toContain('sky-tabbar--labels')
    expect(html).toContain('sky-glass')
    expect(html).toContain('sky-tabbar__blur')
    expect(html).toContain('sky-tabbar__background')
  })

  it('keeps icon and label density explicit', async () => {
    const html = await renderToString(
      createSSRApp(SkyTabBar, {
        icons: false,
        label: 'Navigation',
        labels: true,
      }),
    )

    expect(html).not.toContain('sky-tabbar--icons')
    expect(html).toContain('sky-tabbar--labels')
  })

  it('keeps migrated component and styling hooks on their intended layers', async () => {
    const html = await renderToString(
      createSSRApp(SkyTabBar, {
        bgClass: 'custom-background',
        component: 'footer',
        innerClass: 'custom-inner',
        label: 'Navigation',
      }),
    )

    expect(html).toMatch(/^<footer/)
    expect(html).toContain('sky-tabbar__background custom-background')
    expect(html).toContain('sky-tabbar__inner custom-inner')
  })

  it('matches the Konsta iOS glass, density, and moving highlight contract', () => {
    expect(foundation).toMatch(
      /\.sky-tabbar\s*\{[^}]*--sky-tabbar-pane-height:\s*48px[^}]*padding-right:\s*calc\(var\(--sky-safe-area-right\) \+ 16px\)[^}]*padding-bottom:\s*calc\(var\(--sky-safe-area-bottom\) \+ 16px\)/s,
    )
    expect(foundation).toMatch(
      /\.sky-tabbar--icons\.sky-tabbar--labels\s*\{[^}]*--sky-tabbar-pane-height:\s*64px/s,
    )
    expect(foundation).toMatch(
      /\.sky-tabbar__highlight-inner,[\s\S]*?inset:\s*4px/s,
    )
    expect(controls).toMatch(
      /\.sky-tab-button__icon\s*\{[^}]*width:\s*28px[^}]*height:\s*28px/s,
    )
    expect(controls).toMatch(
      /\.sky-tab-button__label\s*\{[^}]*font-size:\s*16px[^}]*font-weight:\s*400[^}]*line-height:\s*24px/s,
    )
    expect(controls).toMatch(
      /\.sky-tabbar \.sky-tab-button__icon \+ \.sky-tab-button__label\s*\{[^}]*font-size:\s*12px[^}]*font-weight:\s*500[^}]*line-height:\s*16px/s,
    )
    expect(controls).toMatch(
      /\.sky-tabbar \.sky-tab-button\s*\{[^}]*color:\s*var\(--sky-action-glass-text, #ffffff\)/s,
    )
    expect(foundation).not.toContain(
      '.sky-tabbar__links > button > span > span:last-child',
    )
    expect(source).toContain("attributeFilter: ['class']")
    expect(source).toContain(
      "button.classList.contains('sky-tab-button--active')",
    )
  })

  it('keeps Performance solid while Ultimate retains shared Glass', () => {
    expect(mainCss).toMatch(
      /\.phone-app--performance \.sky-tabbar__pane\s*\{[^}]*background:\s*var\(--sky-glass-solid\)[^}]*box-shadow:\s*none/s,
    )
    expect(source).toContain(
      '<SkyGlass material="clear" class="sky-tabbar__pane">',
    )
  })
})
