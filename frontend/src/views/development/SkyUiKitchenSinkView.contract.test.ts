import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

import { SKY_UI_DEMO_CATALOG } from './sky-ui-demo/catalog'

const developmentDirectory = fileURLToPath(new URL('.', import.meta.url))
const demoDirectory = join(developmentDirectory, 'sky-ui-demo')
const pagesDirectory = join(demoDirectory, 'pages')
const viewSource = readFileSync(
  join(developmentDirectory, 'SkyUiKitchenSinkView.vue'),
  'utf8',
)
const homeSource = readFileSync(
  join(demoDirectory, 'SkyUiDemoHome.vue'),
  'utf8',
)
const demoPageSource = readFileSync(
  join(demoDirectory, 'SkyUiDemoPage.vue'),
  'utf8',
)
const demoCssSource = readFileSync(join(demoDirectory, 'demo.css'), 'utf8')
const extensionsSource = readFileSync(
  join(pagesDirectory, 'SkyExtensionsDemo.vue'),
  'utf8',
)
const toastSource = readFileSync(join(pagesDirectory, 'ToastDemo.vue'), 'utf8')
const stepperSource = readFileSync(
  join(pagesDirectory, 'StepperDemo.vue'),
  'utf8',
)
const appSource = readFileSync(
  join(developmentDirectory, '../../App.vue'),
  'utf8',
)
const routerSource = readFileSync(
  join(developmentDirectory, '../../router/index.ts'),
  'utf8',
)
const settingsSource = readFileSync(
  join(developmentDirectory, '../apps/SettingsApp.vue'),
  'utf8',
)

function sourceFiles(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return sourceFiles(path)
    return /\.(?:css|ts|vue)$/.test(entry.name) ? [path] : []
  })
}

const demoSources = sourceFiles(demoDirectory).map((path) =>
  readFileSync(path, 'utf8'),
)
const combinedDemoSource = [viewSource, ...demoSources].join('\n')
const publicIndexSources = [
  '../../ui/index.ts',
  '../../ui/controls/index.ts',
  '../../ui/overlays/index.ts',
  '../../ui/settings/index.ts',
].map((path) => readFileSync(new URL(path, import.meta.url), 'utf8'))
const publicComponents = Array.from(
  new Set(
    publicIndexSources.flatMap((source) =>
      Array.from(
        source.matchAll(/default\s+as\s+(Sky[A-Za-z0-9_]*)/g),
        ([, component]) => component,
      ),
    ),
  ),
).sort()

const referenceCatalog = [
  ['action-sheet', 'Action Sheet'],
  ['badge', 'Badge'],
  ['breadcrumbs', 'Breadcrumbs'],
  ['buttons', 'Buttons'],
  ['cards', 'Cards'],
  ['checkbox', 'Checkbox'],
  ['chips', 'Chips'],
  ['contacts-list', 'Contacts List'],
  ['content-block', 'Content Block'],
  ['data-table', 'Data Table'],
  ['dialog', 'Dialog'],
  ['fab', 'FAB (Floating Action Button)'],
  ['form-inputs', 'Form Inputs'],
  ['list', 'List'],
  ['list-button', 'List Button'],
  ['menu-list', 'Menu List'],
  ['messages', 'Messages'],
  ['navbar', 'Navbar'],
  ['notification', 'Notification'],
  ['side-panels', 'Panel / Side Panels'],
  ['popover', 'Popover'],
  ['popup', 'Popup'],
  ['preloader', 'Preloader'],
  ['progressbar', 'Progressbar'],
  ['radio', 'Radio'],
  ['range-slider', 'Range Slider'],
  ['searchbar', 'Searchbar'],
  ['segmented-control', 'Segmented Control'],
  ['sheet-modal', 'Sheet Modal'],
  ['stepper', 'Stepper'],
  ['subnavbar', 'Subnavbar'],
  ['tabbar', 'Tabbar'],
  ['toast', 'Toast'],
  ['toggle', 'Toggle'],
  ['toolbar', 'Toolbar'],
] as const

function demoFileName(id: string): string {
  return `${id
    .split('-')
    .map((part) => `${part[0]?.toUpperCase()}${part.slice(1)}`)
    .join('')}Demo.vue`
}

function demoPage(name: string): string {
  return readFileSync(join(pagesDirectory, `${name}Demo.vue`), 'utf8')
}

describe('development Sky UI Kitchen Sink contract', () => {
  it('mirrors the exact Konsta 5.3 Vue component submenu catalog', () => {
    expect(SKY_UI_DEMO_CATALOG.map(({ id, title }) => [id, title])).toEqual(
      referenceCatalog,
    )
    expect(new Set(SKY_UI_DEMO_CATALOG.map(({ id }) => id)).size).toBe(35)

    const missingPages = SKY_UI_DEMO_CATALOG.filter(
      ({ id }) => !existsSync(join(pagesDirectory, demoFileName(id))),
    ).map(({ id }) => id)
    expect(missingPages).toEqual([])
  })

  it('uses a real catalog and parameterized submenu navigation', () => {
    expect(homeSource).toContain('v-for="entry in SKY_UI_DEMO_CATALOG"')
    expect(homeSource).toContain('@click="demo.navigate(entry.id)"')
    expect(viewSource).toContain('params: { demo: id }')
    expect(combinedDemoSource).toContain('demo.returnToCatalog')
    expect(viewSource).toContain('defineAsyncComponent')
    expect(routerSource).toContain("path: '/development/sky-ui/:demo?'")
    expect(combinedDemoSource).toContain('./assets/demo-icon.png')
  })

  it('keeps the shared demo shell aligned with the Konsta reference', () => {
    expect(demoPageSource).not.toContain('back-appearance="surface"')
    expect(demoCssSource).toMatch(/\.sky-ui-demo-copy\s*\{\s*margin:\s*0;\s*\}/)
    expect(homeSource).not.toMatch(/<SkyPopover[\s\S]*?\sangle(?:\s|>)/)
    expect(homeSource).toContain("{ color: '#4cd964', name: 'Green'")
    expect(homeSource).toContain("{ color: '#9c27b0', name: 'Purple'")
  })

  it('preserves the locally expressible Konsta examples and states', () => {
    const cards = demoPage('Cards')
    const checkbox = demoPage('Checkbox')
    const contacts = demoPage('ContactsList')
    const dialog = demoPage('Dialog')
    const fab = demoPage('Fab')
    const list = demoPage('List')
    const listButton = demoPage('ListButton')
    const messages = demoPage('Messages')
    const menuList = demoPage('MenuList')
    const notification = demoPage('Notification')
    const panels = demoPage('SidePanels')
    const popover = demoPage('Popover')
    const popup = demoPage('Popup')
    const preloader = demoPage('Preloader')
    const sheet = demoPage('SheetModal')
    const tabbar = demoPage('Tabbar')
    const toggle = demoPage('Toggle')
    const toolbar = demoPage('Toolbar')

    expect(cards).not.toContain('linear-gradient')
    expect(cards).not.toContain('font-size: 22px')
    expect(cards).toContain('<SkyMediaCard')
    expect(cards).not.toMatch(/cards-demo__(?:image|date|copy|actions)/)
    expect(checkbox).toContain(
      '<SkyList class="checkbox-demo__children" nested>',
    )
    expect(contacts).toContain('<SkyListItem contacts group-title')
    expect(contacts).toMatch(/contacts\s+:title="name"/)
    expect(dialog).toContain(
      'margin: 0 calc(var(--sky-space-4) * -1) calc(var(--sky-space-4) * -1);',
    )
    expect(fab.match(/class="fab-demo__button/g)).toHaveLength(6)
    expect(fab).toContain('fab-demo__button--right-top sky-ui-demo-color-red')
    expect(listButton).toContain('<SkyList dividers outline strong>')
    expect(list).toContain('user, etc.')
    expect(list).not.toContain(':chevron="false"')
    expect(list).toContain("import demoIcon from '../assets/demo-icon.png'")
    expect(messages).toContain("return text.split('\\n')")
    expect(messages).toContain('<template #text>')
    expect(menuList).toContain("import demoIcon from '../assets/demo-icon.png'")
    expect(notification).toContain(
      '@click="opened.notificationWithButton = false"',
    )
    expect(notification).not.toContain('<SkyDialogButton strong')
    expect(panels).toContain('sky-ui-demo-panel-page--floating')
    expect(panels).toContain('--sky-safe-area-top: 0px;')
    expect(popover).not.toMatch(/<SkyPopover[\s\S]*?\sangle(?:\s|>)/)
    expect(popup).toContain('"Temporary Views".')
    expect(popup).toContain('Also not, that by default popup')
    expect(preloader).toContain('color: #4cd964;')
    expect(preloader).toContain('color: #9c27b0;')
    expect(sheet).toContain('Such modals allow to create custom overlays')
    expect(tabbar).not.toContain('color: var(--sky-muted)')
    expect(toggle).toMatch(/<SkyListItem[\s\S]*?\slabel[\s\S]*?<SkyToggle/)
    expect(toolbar).toContain('Cras vehicula bibendum lorem quis imperdiet.')
    expect(toolbar).toContain('sed risus aliquet, vel accumsan dolor feugiat.')
  })

  it('demonstrates every public Sky component without Konsta runtime code', () => {
    const missingComponents = publicComponents.filter(
      (component) =>
        !new RegExp(`<${component}(?:\\s|/?>)`).test(combinedDemoSource),
    )

    expect(publicComponents.length).toBeGreaterThanOrEqual(63)
    expect(missingComponents).toEqual([])
    expect(combinedDemoSource).not.toContain('konsta/vue')
    expect(combinedDemoSource).not.toMatch(/<\/?k-[a-z]/)
  })

  it('keeps the lazy route and launcher development-only', () => {
    expect(routerSource).toMatch(
      /const developmentRoutes[^=]*=\s*import\.meta\.env\.DEV[\s\S]*?import\('@\/views\/development\/SkyUiKitchenSinkView\.vue'\)/,
    )
    expect(routerSource).toContain("name: 'development-sky-ui'")
    expect(appSource).toContain("route.name === 'development-sky-ui'")
    expect(appSource).toContain(
      'isDevelopmentRoute ? String(route.name) : route.path',
    )
    expect(settingsSource).toContain(
      'const isDevelopment = import.meta.env.DEV',
    )
    expect(settingsSource).toContain('v-if="isDevelopment')
    expect(settingsSource).toContain(
      "router.push({ name: 'development-sky-ui' })",
    )
    expect(settingsSource).not.toContain('SkyUiKitchenSinkView')
    expect(viewSource).not.toContain('<SkyProvider')
    expect(viewSource).not.toContain('safe-areas')
  })

  it('keeps the demo source within the conservative CEF contract', () => {
    expect(combinedDemoSource).not.toMatch(
      /:has\(|@container|\b(?:dvh|svh|lvh)\b|color-mix\(|oklch\(|view-transition|draggable\s*=\s*["']true/,
    )
  })

  it('keeps exactly one split-navigation highlight active', () => {
    expect(extensionsSource).toContain(':strong="splitTab < 2"')
    expect(extensionsSource).toContain(':strong="splitTab === 2"')
  })

  it('matches the compact Konsta toast buttons without shrinking their hit area', () => {
    expect(toastSource).toContain('class="toast-demo__button"')
    expect(toastSource).toMatch(
      /\.toast-demo__button\s*\{[\s\S]*?height: 34px;[\s\S]*?min-height: 34px;/,
    )
    expect(toastSource).toMatch(
      /\.toast-demo__button::before\s*\{[\s\S]*?inset: -5px 0;/,
    )
  })

  it('centers the Konsta text-input stepper examples', () => {
    expect(stepperSource).toContain('sky-ui-demo-stepper-inputs')
    expect(stepperSource).toMatch(
      /\.sky-ui-demo-stepper-inputs\s*\{[\s\S]*?justify-items: center;/,
    )
  })
})
