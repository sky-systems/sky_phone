import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const clockView = readFileSync(
  new URL('./ClockApp.vue', import.meta.url),
  'utf8',
)
const alarmEditorView = readFileSync(
  new URL('../../components/AlarmEditor.vue', import.meta.url),
  'utf8',
)
const mainCss = readFileSync(
  new URL('../../assets/main.css', import.meta.url),
  'utf8',
)

describe('Clock app controls', () => {
  it('only renders a title navbar for the alarm tab', () => {
    expect(clockView.match(/<sky-navbar/g)).toHaveLength(1)
    expect(clockView).toContain('v-if="tab === \'alarm\'"')
    expect(clockView).toContain('class="clock-navbar clock-navbar--alarm"')
    expect(clockView).toContain('variant="large"')
    expect(clockView).not.toContain('v-else-if="tab !== \'stopwatch\'"')
    expect(mainCss).toMatch(
      /\.clock-navbar\.sky-navbar\s*\{[^}]*--sky-navbar-safe-area-top:\s*var\(--sky-space-2\);/s,
    )
    expect(mainCss).not.toContain('.clock-navbar.sky-navbar--no-navigation')
  })

  it('keeps the single world clock centered with readable line boxes', () => {
    expect(clockView).toContain('class="clock-world-now"')
    expect(clockView).not.toContain('clock-world-list')
    expect(mainCss).toMatch(
      /\.clock-world-time\s*\{[^}]*font-size:\s*74px;[^}]*line-height:\s*1;/s,
    )
  })

  it('uses the orange clock accent and state-specific circular actions', () => {
    expect(clockView).toContain(
      ":accent=\"phone.isDarkMode ? '#ff9f0a' : '#9b5800'\"",
    )
    expect(clockView).toContain('clock-action-button--start')
    expect(clockView).toContain('clock-action-button--stop')
    expect(clockView).toContain('<Play')
    expect(clockView).toContain('<Pause')
  })

  it('uses the shared full-width Sky tab bar', () => {
    expect(clockView).toContain('<sky-tab-bar')
    expect(clockView).toContain('<sky-tab-button')
    expect(clockView).not.toContain('<sky-segmented')
  })

  it('does not nest a second SkyBlock around the timer layout', () => {
    expect(clockView).toContain(
      '<section v-else class="clock-tool clock-timer">',
    )
    expect(clockView).not.toContain(
      '<sky-block v-else nested class="clock-tool clock-timer">',
    )
    expect(mainCss).toMatch(
      /\.clock-timer\s*\{[^}]*display:\s*flex;[^}]*flex-direction:\s*column;[^}]*align-items:\s*center;/s,
    )
    expect(mainCss).toMatch(/\.clock-timer-actions\s*\{[^}]*width:\s*100%;/s)
    expect(mainCss).toMatch(/\.clock-timer-settings\s*\{[^}]*width:\s*100%;/s)
  })

  it('keeps the stopwatch single-page and separates alarm actions', () => {
    expect(clockView).not.toContain('clock-stopwatch-pages')
    expect(clockView).not.toContain('clock-stopwatch-page')
    expect(clockView).toMatch(
      /<template #left>[\s\S]*?clock-navbar-action--icon[\s\S]*?<\/template>\s*<template #right>[\s\S]*?clock-navbar-action--edit/,
    )
    expect(clockView).not.toContain('clock-navbar-actions')
    expect(clockView).toMatch(
      /<sky-button\s+v-if="alarmsEditing"[\s\S]*?icon-only[\s\S]*?class="clock-alarm-remove"/,
    )
    expect(mainCss).toMatch(
      /\.clock-navbar--alarm \.sky-navbar__inner\s*\{[^}]*margin-bottom:\s*0;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-navbar--alarm \.sky-navbar__left\.sky-glass-surface,\s*\.clock-navbar--alarm \.sky-navbar__right\.sky-glass-surface\s*\{/s,
    )
    expect(mainCss).not.toMatch(/\.clock-navbar--alarm\s*\{[^}]*margin-top:/s)
    expect(mainCss).toMatch(
      /\.clock-content\s*\{[^}]*--sky-block-gutter-left:\s*0px;[^}]*--sky-block-gutter-right:\s*0px;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-stopwatch\s*\{[^}]*--sky-block-gutter-left:\s*calc\(\s*var\(--sky-page-gutter\) \+ var\(--sky-safe-area-left\)\s*\);[^}]*--sky-block-gutter-right:\s*calc\(\s*var\(--sky-page-gutter\) \+ var\(--sky-safe-area-right\)\s*\);/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-item > \.sky-toggle\s*\{[^}]*grid-column:\s*3;[^}]*justify-self:\s*end;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-remove\.sky-button--icon-only\s*\{[^}]*width:\s*28px;[^}]*height:\s*28px;[^}]*min-height:\s*28px;[^}]*padding:\s*0;[^}]*border-radius:\s*50%;/s,
    )
  })

  it('opens the alarm editor as a compact Sky sheet over the alarm page', () => {
    expect(clockView).toMatch(/<AlarmEditor\s+v-if="alarmEditor"/)
    expect(clockView).not.toContain('v-else-if="alarmEditor"')
    expect(alarmEditorView).toContain('<k-sheet')
    expect(alarmEditorView).toContain(':show-grabber="false"')
    expect(alarmEditorView).toContain('swipe-to-close')
    expect(alarmEditorView).toContain('data-sky-sheet-drag-handle')
    expect(alarmEditorView).toContain(
      '<k-scroll-area padded class="clock-alarm-editor">',
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet \.sky-sheet__panel\s*\{[^}]*height:\s*calc\(\s*100% - var\(--sky-safe-area-top\) - var\(--sky-space-2\)\s*\);[^}]*overflow:\s*hidden;[^}]*border-radius:\s*var\(--sky-radius-sheet\) var\(--sky-radius-sheet\) 0 0;[^}]*background:\s*var\(--sky-sheet-background\);/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet\s*\{[^}]*--sky-sheet-background:\s*#1c1c1d;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet \.sky-sheet__grabber\s*\{[^}]*display:\s*none;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet-surface\s*\{[^}]*height:\s*100%;[^}]*border-radius:\s*var\(--sky-radius-sheet\) var\(--sky-radius-sheet\) 0 0;[^}]*background:\s*var\(--sky-sheet-background\);/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet-navbar\.sky-navbar,[\s\S]*?\.clock-alarm-sheet-surface > \.sky-navbar\s*\{[^}]*--sky-navbar-safe-area-top:\s*var\(--sky-space-3\);/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-sheet-navbar \.sky-navbar__blur,[\s\S]*?\.clock-alarm-sheet-navbar \.sky-navbar__background\s*\{[^}]*background:\s*transparent;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-save\.sky-link\s*\{[^}]*background:\s*#ff9f0a;[^}]*color:\s*#fff;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-editor\.sky-scroll-area--padded\s*\{[^}]*--sky-page-gutter:\s*12px;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-editor \.time-wheel-picker\s*\{[^}]*width:\s*100%;[^}]*margin-right:\s*0;[^}]*margin-left:\s*0;/s,
    )
    expect(mainCss).toMatch(
      /\.clock-alarm-editor \.sky-list--strong,[\s\S]*?\.clock-alarm-editor \.sky-list--inset\s*\{[^}]*background:\s*#2c2c2e;/s,
    )
  })
})
