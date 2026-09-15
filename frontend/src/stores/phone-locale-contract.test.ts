import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import ts from 'typescript'
import { describe, expect, it } from 'vitest'
import { collectLuaLocaleValues } from '../testing/lua-locale'

const frontendSourceDirectory = fileURLToPath(new URL('../', import.meta.url))
const localeDirectory = fileURLToPath(
  new URL('../../../sky_phone/config/locales/', import.meta.url),
)
const localeSources = new Map(
  readdirSync(localeDirectory, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.lua'))
    .map((entry) => [
      entry.name.replace(/\.lua$/, ''),
      readFileSync(join(localeDirectory, entry.name), 'utf8'),
    ]),
)
const englishLocaleSource = localeSources.get('en')
const germanLocaleSource = localeSources.get('de')
if (!englishLocaleSource || !germanLocaleSource) {
  throw new Error('The bundled English and German phone locales are required.')
}
const phoneStoreSource = readFileSync(
  new URL('./phone.ts', import.meta.url),
  'utf8',
)

function collectPlaceholders(value: string): string[] {
  return (value.match(/\{[A-Za-z0-9_]+\}/g) ?? []).sort()
}

function collectNumberTokens(value: string): string[] {
  return value.match(/\d+/g) ?? []
}

function collectDefaultLocalePaths(source: string): Set<string> {
  const ast = ts.createSourceFile(
    'phone.ts',
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  )
  const declarations = new Map<string, ts.Expression>()
  const registerDeclarations = (node: ts.Node): void => {
    if (
      ts.isVariableDeclaration(node) &&
      ts.isIdentifier(node.name) &&
      node.initializer
    ) {
      declarations.set(node.name.text, node.initializer)
    }
    ts.forEachChild(node, registerDeclarations)
  }
  registerDeclarations(ast)

  const paths = new Set<string>()
  const collect = (node: ts.Expression, path: string[]): void => {
    if (
      ts.isParenthesizedExpression(node) ||
      ts.isAsExpression(node) ||
      ts.isSatisfiesExpression(node)
    ) {
      collect(node.expression, path)
      return
    }
    if (ts.isIdentifier(node) && declarations.has(node.text)) {
      collect(declarations.get(node.text)!, path)
      return
    }
    if (!ts.isObjectLiteralExpression(node)) {
      if (path.length) paths.add(path.join('.'))
      return
    }
    for (const property of node.properties) {
      if (ts.isSpreadAssignment(property)) {
        collect(property.expression, path)
        continue
      }
      if (!ts.isPropertyAssignment(property)) continue
      const name = property.name
      const key =
        ts.isIdentifier(name) ||
        ts.isStringLiteral(name) ||
        ts.isNumericLiteral(name)
          ? name.text
          : null
      if (key !== null) collect(property.initializer, [...path, key])
    }
  }

  const defaultLocales = declarations.get('defaultLocales')
  expect(defaultLocales).toBeDefined()
  collect(defaultLocales!, [])
  return paths
}

function collectFrontendFiles(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) {
      return entry.name === 'development' ? [] : collectFrontendFiles(path)
    }
    return /\.(?:ts|vue)$/.test(entry.name) && !entry.name.includes('.test.')
      ? [path]
      : []
  })
}

describe('phone locale contract', () => {
  const localeValues = new Map(
    [...localeSources].map(([locale, source]) => [
      locale,
      collectLuaLocaleValues(source),
    ]),
  )
  const englishValues = localeValues.get('en')!
  const germanValues = localeValues.get('de')!
  const translatedLocaleValues = [...localeValues].filter(
    ([locale]) => locale !== 'en',
  )
  const englishPaths = new Set(englishValues.keys())

  it('bundles all fifteen supported languages', () => {
    expect([...localeSources.keys()].sort()).toEqual([
      'ar',
      'cn',
      'cz',
      'de',
      'en',
      'es',
      'fi',
      'fr',
      'it',
      'nl',
      'pl',
      'pt',
      'rs',
      'ru',
      'se',
    ])
  })

  it.each([...localeSources])(
    'registers the %s locale under its file name',
    (locale, source) => {
      expect(source.match(/^Locales\["([^"]+)"\]/)?.[1]).toBe(locale)
    },
  )

  it.each([...localeSources])(
    'keeps %s in one expanded locale table without appended overrides',
    (_locale, source) => {
      expect(source.match(/\bLocales\s*\[/g)).toHaveLength(1)
      expect(source).not.toMatch(
        /^\s*(?:[A-Za-z_][A-Za-z0-9_]*|\["[^"]+"\])\s*=\s*\{[^\r\n}]*=/m,
      )
    },
  )

  it('keeps every bundled frontend fallback in en.lua', () => {
    const missing = [...collectDefaultLocalePaths(phoneStoreSource)].filter(
      (path) => !englishPaths.has(`Nui.${path}`),
    )

    expect(missing).toEqual([])
  })

  it('defines every static frontend translation key in en.lua', () => {
    const missing: string[] = []
    for (const file of collectFrontendFiles(frontendSourceDirectory)) {
      const source = readFileSync(file, 'utf8')
      for (const match of source.matchAll(
        /phone\.t\(\s*(['"])([^'"`]+)\1\s*[,)]/g,
      )) {
        if (!englishPaths.has(`Nui.${match[2]}`)) {
          missing.push(
            `${relative(frontendSourceDirectory, file)}: ${match[2]}`,
          )
        }
      }
    }

    expect(missing).toEqual([])
  })

  it('keeps the VaultX browser fallback complete for auth and transfers', () => {
    const fallbackPaths = collectDefaultLocalePaths(phoneStoreSource)

    for (const path of [
      'Apps.crypto.auth.network',
      'Apps.crypto.auth.confirmPassword',
      'Apps.crypto.quick.send',
      'Apps.crypto.transfer.walletKey',
      'Apps.crypto.profile.copyKey',
      'Apps.crypto.profile.shareKey',
      'Apps.crypto.activityTypes.transfer_in',
      'Apps.crypto.activityTypes.transfer_out',
      'Apps.crypto.errors.invalid_wallet_key',
    ]) {
      expect(fallbackPaths.has(path), path).toBe(true)
    }
  })

  it.each(translatedLocaleValues)(
    'keeps %s structurally aligned with English',
    (_locale, values) => {
      expect([...values.keys()].sort()).toEqual([...englishPaths].sort())
    },
  )

  it.each(translatedLocaleValues)(
    'keeps %s interpolation placeholders aligned with English',
    (_locale, values) => {
      const mismatches = [...englishValues].flatMap(([path, englishValue]) => {
        const translatedValue = values.get(path)
        return translatedValue !== undefined &&
          JSON.stringify(collectPlaceholders(translatedValue)) !==
            JSON.stringify(collectPlaceholders(englishValue))
          ? [
              `${path}: ${collectPlaceholders(englishValue).join(', ')} != ${collectPlaceholders(translatedValue).join(', ')}`,
            ]
          : []
      })

      expect(mismatches).toEqual([])
    },
  )

  it.each(translatedLocaleValues)(
    'keeps %s numeric source values intact',
    (_locale, values) => {
      const mismatches = [...englishValues].flatMap(([path, englishValue]) => {
        const expected = collectNumberTokens(englishValue)
        if (!expected.length) return []

        const remaining = collectNumberTokens(values.get(path) ?? '')
        for (const token of expected) {
          const index = remaining.indexOf(token)
          if (index >= 0) remaining.splice(index, 1)
          else return [`${path}: missing numeric token ${token}`]
        }
        return []
      })

      expect(mismatches).toEqual([])
    },
  )

  it('keeps standard app names German and custom game names unchanged', () => {
    const standardAppNames = {
      health: 'Gesundheit',
      messages: 'Nachrichten',
      companies: 'Unternehmen',
      phone: 'Telefon',
      radio: 'Funk',
      billing: 'Rechnungen',
      house: 'Haus',
      calculator: 'Rechner',
      camera: 'Kamera',
      calendar: 'Kalender',
      clock: 'Uhr',
      localPages: 'Lokale Seiten',
      map: 'Karte',
      weather: 'Wetter',
      music: 'Musik',
      notes: 'Notizen',
      photos: 'Fotos',
      settings: 'Einstellungen',
    }

    for (const [app, name] of Object.entries(standardAppNames)) {
      expect(germanValues.get(`Nui.Apps.${app}.name`), app).toBe(name)
    }

    for (const app of [
      'snake',
      'memory',
      'numberMerge',
      'minesweeper',
      'towerStack',
      'skyFlappy',
      'neonDrop',
    ]) {
      const path = `Nui.Apps.${app}.name`
      expect(germanValues.get(path), app).toBe(englishValues.get(path))
    }
  })

  it('keeps common German UI terms semantically correct', () => {
    expect(germanValues.get('Nui.Apps.phone.cancelled')).toBe('Abgebrochen')
    expect(germanValues.get('Nui.Apps.flare.interests')).toBe('Interessen')
    expect(germanValues.get('Nui.Apps.picstagram.emptyFeed')).toBe(
      'Dein Feed ist ruhig',
    )
    expect(germanValues.get('Nui.Apps.clock.lap')).toBe('Runde')
    expect(germanValues.get('Nui.Apps.easyShare.incoming')).toBe(
      'Eingehende Freigabe',
    )
    expect(germanValues.get('Nui.Apps.settings.phoneScale')).toBe(
      'Telefongröße',
    )
  })
})
