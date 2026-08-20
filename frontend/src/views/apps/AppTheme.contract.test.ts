import { readdirSync, readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const appShellSource = readFileSync(
  new URL('../../App.vue', import.meta.url),
  'utf8',
)
const mainCssSource = readFileSync(
  new URL('../../assets/main.css', import.meta.url),
  'utf8',
)
const appDirectory = new URL('.', import.meta.url)
const appSources = readdirSync(appDirectory)
  .filter((file) => file.endsWith('.vue'))
  .map((file) => ({
    file,
    source: readFileSync(new URL(file, appDirectory), 'utf8'),
  }))

describe('phone app theme contract', () => {
  it('provides the reactive phone theme to every routed app', () => {
    expect(appShellSource).toContain('import { SkyProvider }')
    expect(appShellSource).toContain('class="phone-app-theme"')
    expect(appShellSource).toContain(':dark="displayedDarkMode"')
    expect(appShellSource).toMatch(
      /<SkyProvider[\s\S]*?<RouterView[\s\S]*?<component/,
    )
  })

  it('does not force a routed app permanently into one color mode', () => {
    for (const { file, source } of appSources) {
      expect(source, file).not.toMatch(/:dark="(?:true|false)"/)
    }
    expect(appShellSource).not.toContain("'phone-app--darkchat'")
    expect(mainCssSource).not.toContain('.phone-app--darkchat')
  })

  it('keeps shared app surfaces and known custom apps theme-aware', () => {
    expect(mainCssSource).toContain('background: var(--sky-bg);')
    expect(mainCssSource).toContain('color: var(--sky-text);')
    expect(mainCssSource).toContain('.phone-app--light .banking-app')

    const calculator = appSources.find(
      ({ file }) => file === 'CalculatorApp.vue',
    )?.source
    const mail = appSources.find(({ file }) => file === 'MailApp.vue')?.source

    expect(calculator).toContain("'calculator-app--light': !phone.isDarkMode")
    expect(mail).toContain('background: var(--sky-bg) !important;')
    expect(mail).toContain('color: var(--sky-text);')
  })
})
