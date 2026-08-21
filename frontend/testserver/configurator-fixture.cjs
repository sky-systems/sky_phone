const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')

class LuaTable {
  constructor() {
    this.entries = []
    this.nextArrayIndex = 1
  }

  get(key) {
    return this.entries.find((entry) => entry.key === key)?.value
  }

  set(key, value) {
    const entry = this.entries.find((candidate) => candidate.key === key)
    if (entry) entry.value = value
    else this.entries.push({ key, value })
  }
}

function tokenize(source) {
  const tokens = []
  let index = 0

  while (index < source.length) {
    const character = source[index]
    if (/\s/.test(character)) {
      index += 1
      continue
    }
    if (source.startsWith('--[[', index)) {
      const end = source.indexOf(']]', index + 4)
      index = end < 0 ? source.length : end + 2
      continue
    }
    if (source.startsWith('--', index)) {
      const end = source.indexOf('\n', index + 2)
      index = end < 0 ? source.length : end + 1
      continue
    }
    if (character === '"' || character === "'") {
      const quote = character
      let value = ''
      index += 1
      while (index < source.length && source[index] !== quote) {
        if (source[index] !== '\\') {
          value += source[index]
          index += 1
          continue
        }

        index += 1
        const escaped = source[index]
        const escapeValues = {
          a: '\u0007',
          b: '\b',
          f: '\f',
          n: '\n',
          r: '\r',
          t: '\t',
          v: '\u000b',
        }
        value += escapeValues[escaped] ?? escaped
        index += 1
      }
      if (source[index] !== quote)
        throw new Error('Unterminated Lua string in configurator fixture.')
      index += 1
      tokens.push({ type: 'string', value })
      continue
    }
    if (/[A-Za-z_]/.test(character)) {
      const match = source.slice(index).match(/^[A-Za-z_][A-Za-z0-9_]*/)
      tokens.push({ type: 'name', value: match[0] })
      index += match[0].length
      continue
    }
    if (
      /\d/.test(character) ||
      (character === '.' && /\d/.test(source[index + 1]))
    ) {
      const match = source
        .slice(index)
        .match(/^(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/)
      tokens.push({ type: 'number', value: Number(match[0]) })
      index += match[0].length
      continue
    }

    tokens.push({ type: 'symbol', value: character })
    index += 1
  }

  return tokens
}

class LuaConfigParser {
  constructor(source) {
    this.tokens = tokenize(source)
    this.index = 0
    this.config = new LuaTable()
  }

  current(offset = 0) {
    return this.tokens[this.index + offset]
  }

  matches(value, offset = 0) {
    return this.current(offset)?.value === value
  }

  take(value) {
    const token = this.current()
    if (!token || (value !== undefined && token.value !== value)) {
      throw new Error(
        `Expected '${value}', received '${token?.value ?? 'end of file'}' in configurator fixture.`,
      )
    }
    this.index += 1
    return token
  }

  parse() {
    while (this.current()) {
      if (this.matches('Config')) {
        const start = this.index
        const path = this.parsePath()
        if (path.length && this.matches('=')) {
          this.take('=')
          this.setPath(path, this.parseExpression())
          continue
        }
        this.index = start + 1
        continue
      }
      this.index += 1
    }
    return this.config
  }

  parsePath() {
    this.take('Config')
    const path = []
    while (this.matches('.') && this.current(1)?.type === 'name') {
      this.take('.')
      path.push(this.take().value)
    }
    return path
  }

  getPath(path) {
    let value = this.config
    for (const key of path) {
      if (!(value instanceof LuaTable)) return undefined
      value = value.get(key)
    }
    return value
  }

  setPath(path, value) {
    let parent = this.config
    for (let index = 0; index < path.length - 1; index += 1) {
      const key = path[index]
      let child = parent.get(key)
      if (!(child instanceof LuaTable)) {
        child = new LuaTable()
        parent.set(key, child)
      }
      parent = child
    }
    parent.set(path.at(-1), value)
  }

  parseExpression() {
    return this.parseOr()
  }

  parseOr() {
    let value = this.parseAdditive()
    while (this.matches('or')) {
      this.take('or')
      const fallback = this.parseAdditive()
      value =
        value !== false && value !== null && value !== undefined
          ? value
          : fallback
    }
    return value
  }

  parseAdditive() {
    let value = this.parseMultiplicative()
    while (this.matches('+') || this.matches('-')) {
      const operator = this.take().value
      const right = this.parseMultiplicative()
      value =
        operator === '+'
          ? Number(value) + Number(right)
          : Number(value) - Number(right)
    }
    return value
  }

  parseMultiplicative() {
    let value = this.parseUnary()
    while (this.matches('*') || this.matches('/')) {
      const operator = this.take().value
      const right = this.parseUnary()
      value =
        operator === '*'
          ? Number(value) * Number(right)
          : Number(value) / Number(right)
    }
    return value
  }

  parseUnary() {
    if (this.matches('-')) {
      this.take('-')
      return -Number(this.parseUnary())
    }
    return this.parsePrimary()
  }

  parsePrimary() {
    const token = this.current()
    if (!token)
      throw new Error(
        'Unexpected end of Lua configuration in configurator fixture.',
      )
    if (token.type === 'number' || token.type === 'string') {
      this.index += 1
      return token.value
    }
    if (this.matches('true') || this.matches('false') || this.matches('nil')) {
      this.index += 1
      return token.value === 'true'
        ? true
        : token.value === 'false'
          ? false
          : null
    }
    if (this.matches('{')) return this.parseTable()
    if (this.matches('(')) {
      this.take('(')
      const value = this.parseExpression()
      this.take(')')
      return value
    }
    if (this.matches('Config')) return this.getPath(this.parsePath())
    if (token.type === 'name' && this.current(1)?.value === '(') {
      const name = this.take().value
      this.take('(')
      const argumentsList = []
      while (!this.matches(')')) {
        argumentsList.push(this.parseExpression())
        if (!this.matches(',')) break
        this.take(',')
      }
      this.take(')')
      if (/^vector[234]$/.test(name)) {
        const axes = ['x', 'y', 'z', 'w']
        return Object.fromEntries([
          ['__skyType', name],
          ...argumentsList.map((value, index) => [axes[index], value]),
        ])
      }
      throw new Error(`Unsupported Lua call '${name}' in configurator fixture.`)
    }

    throw new Error(
      `Unsupported Lua token '${token.value}' in configurator fixture.`,
    )
  }

  parseTable() {
    const table = new LuaTable()
    this.take('{')
    while (!this.matches('}')) {
      if (this.matches('[')) {
        this.take('[')
        const key = this.parseExpression()
        this.take(']')
        this.take('=')
        table.set(key, this.parseExpression())
      } else if (
        this.current()?.type === 'name' &&
        this.current(1)?.value === '='
      ) {
        const key = this.take().value
        this.take('=')
        table.set(key, this.parseExpression())
      } else {
        table.set(table.nextArrayIndex, this.parseExpression())
        table.nextArrayIndex += 1
      }

      if (this.matches(',') || this.matches(';')) this.index += 1
      else if (!this.matches('}')) {
        throw new Error(
          `Expected a Lua table separator, received '${this.current()?.value ?? 'end of file'}'.`,
        )
      }
    }
    this.take('}')
    return table
  }
}

function serializeLuaValue(value) {
  if (!(value instanceof LuaTable)) {
    if (Array.isArray(value)) return value.map(serializeLuaValue)
    if (value && typeof value === 'object') {
      return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [
          key,
          serializeLuaValue(child),
        ]),
      )
    }
    return value
  }

  const numericKeys = value.entries
    .filter((entry) => typeof entry.key === 'number')
    .map((entry) => entry.key)
    .sort((left, right) => left - right)
  const isSequence =
    numericKeys.length === value.entries.length &&
    numericKeys.every((key, index) => key === index + 1)
  if (isSequence) {
    return [...value.entries]
      .sort((left, right) => left.key - right.key)
      .map((entry) => serializeLuaValue(entry.value))
  }
  if (value.entries.every((entry) => typeof entry.key === 'string')) {
    return Object.fromEntries(
      value.entries.map((entry) => [entry.key, serializeLuaValue(entry.value)]),
    )
  }

  return {
    __skyType: 'map',
    entries: value.entries.map((entry) => ({
      key: entry.key,
      keyType: typeof entry.key,
      value: serializeLuaValue(entry.value),
    })),
  }
}

function humanize(value) {
  return String(value ?? '')
    .replace(/[_-]+/g, ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/([A-Za-z])(\d)/g, '$1 $2')
    .replace(/^./, (character) => character.toUpperCase())
}

function sensitivePath(path) {
  const leaf = path.split('.').at(-1) ?? path
  const normalized = leaf.toLowerCase().replace(/[^a-z0-9]/g, '')
  return (
    normalized.includes('apikey') ||
    normalized.includes('secret') ||
    normalized.includes('pepper') ||
    [
      'password',
      'token',
      'authorization',
      'credential',
      'connectionstring',
    ].includes(normalized)
  )
}

function maskValue(value, path) {
  if (Array.isArray(value))
    return value.map((child, index) => maskValue(child, `${path}.${index + 1}`))
  if (value?.__skyType === 'map' && Array.isArray(value.entries)) {
    return {
      __skyType: 'map',
      entries: value.entries.map((entry) => ({
        key: entry.key,
        keyType: entry.keyType,
        value: maskValue(entry.value, `${path}.${entry.key}`),
      })),
    }
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [
        key,
        maskValue(child, `${path}.${key}`),
      ]),
    )
  }
  return typeof value === 'string' && sensitivePath(path)
    ? '***REDACTED***'
    : value
}

function emptyStructure(scope, path) {
  if (scope !== 'config') return undefined
  if (path === 'Garage.VehicleImages.ModelNames') {
    return {
      entries: [],
      keyType: 'number',
      kind: 'map',
      template: { kind: 'value', valueType: 'string' },
    }
  }
  if (
    path === 'CrewLink.ExternalPingResources' ||
    path === 'CustomApps.TrustedAdapters'
  ) {
    return {
      fields: {},
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    }
  }
  if (path === 'FlipTok.MusicTracks') {
    return {
      items: [],
      kind: 'list',
      template: {
        fields: {
          Artist: { kind: 'value', valueType: 'string' },
          Id: { kind: 'value', valueType: 'string' },
          Title: { kind: 'value', valueType: 'string' },
          Url: { kind: 'value', valueType: 'string' },
        },
        kind: 'table',
      },
    }
  }
  if (path === 'Music.Tracks') {
    return {
      items: [],
      kind: 'list',
      template: {
        fields: {
          Artist: { kind: 'value', valueType: 'string' },
          Id: { kind: 'value', valueType: 'string' },
          Title: { kind: 'value', valueType: 'string' },
        },
        kind: 'table',
      },
    }
  }
  if (path === 'Payphones.CustomLocations') {
    return {
      items: [],
      kind: 'list',
      template: { kind: 'vector', vectorType: 'vector4' },
    }
  }
  if (/^Companies\.Definitions\.[^.]+\.Services$/.test(path)) {
    return {
      items: [],
      kind: 'list',
      template: {
        fields: {
          Description: { kind: 'value', valueType: 'string' },
          Id: { kind: 'value', valueType: 'string' },
          Price: { kind: 'value', valueType: 'string' },
          RequestsEnabled: { kind: 'value', valueType: 'boolean' },
          Title: { kind: 'value', valueType: 'string' },
        },
        kind: 'table',
      },
    }
  }
  return undefined
}

function buildStructure(value, scope, path) {
  if (scope === 'config' && path === 'Phone.Keybind') {
    return { kind: 'optionalString' }
  }
  if (
    scope === 'config' &&
    path === 'Companies.Definitions' &&
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value)
  ) {
    const keys = Object.keys(value).sort()
    const fields = Object.fromEntries(
      keys.map((key) => [
        key,
        buildStructure(value[key], scope, `${path}.${key}`),
      ]),
    )
    return {
      fields,
      kind: 'table',
      mutableKeys: true,
      template: keys[0] ? fields[keys[0]] : undefined,
    }
  }
  const configuredEmptyStructure =
    Array.isArray(value) && value.length === 0
      ? emptyStructure(scope, path)
      : undefined
  if (configuredEmptyStructure) {
    return configuredEmptyStructure
  }
  if (Array.isArray(value)) {
    const items = value.map((child, index) =>
      buildStructure(child, scope, `${path}.${index + 1}`),
    )
    return {
      kind: 'list',
      items,
      template: items[0],
    }
  }
  if (value?.__skyType === 'map' && Array.isArray(value.entries)) {
    const entries = value.entries.map((entry) => ({
      key: entry.key,
      keyType: entry.keyType,
      structure: buildStructure(entry.value, scope, `${path}.${entry.key}`),
    }))
    const keyTypes = new Set(entries.map((entry) => entry.keyType))
    return {
      kind: 'map',
      entries,
      keyType: keyTypes.size === 1 ? entries[0]?.keyType : undefined,
      template: entries[0]?.structure,
    }
  }
  if (/^vector[234]$/.test(value?.__skyType ?? '')) {
    return { kind: 'vector', vectorType: value.__skyType }
  }
  if (value !== null && typeof value === 'object') {
    return {
      kind: 'table',
      fields: Object.fromEntries(
        Object.entries(value).map(([key, child]) => [
          key,
          buildStructure(child, scope, `${path}.${key}`),
        ]),
      ),
    }
  }
  return { kind: 'value', valueType: typeof value }
}

function addField(fields, scope, path, value) {
  const valueType = Array.isArray(value) ? 'json' : typeof value
  const sensitive = typeof value === 'string' && sensitivePath(path)
  fields.push({
    configured: sensitive ? value !== '' : undefined,
    label:
      scope === 'config' && path === 'Companies.Definitions'
        ? 'Jobs'
        : humanize(path.split('.').at(-1)),
    path,
    scope,
    sensitive,
    structure:
      value !== null && typeof value === 'object'
        ? buildStructure(value, scope, path)
        : undefined,
    type:
      scope === 'config' && path === 'Phone.Keybind'
        ? 'stringOrFalse'
        : value !== null && typeof value === 'object'
          ? 'json'
          : valueType,
    value: sensitive ? '' : maskValue(value, path),
  })
}

function flattenCompanyFields(fields, path, value) {
  if (
    path === 'Companies.Definitions' ||
    value === null ||
    typeof value !== 'object' ||
    Array.isArray(value) ||
    value.__skyType ||
    Object.keys(value).length === 0
  ) {
    addField(fields, 'config', path, value)
    return
  }

  for (const key of Object.keys(value).sort()) {
    flattenCompanyFields(fields, `${path}.${key}`, value[key])
  }
}

function buildSections(scope, payload) {
  const sections = []
  const generalFields = []
  for (const key of Object.keys(payload).sort()) {
    const value = payload[key]
    if (scope === 'config' && key === 'Companies') {
      const fields = []
      flattenCompanyFields(fields, 'Companies', value)
      fields.sort((left, right) => {
        if (left.path === 'Companies.Definitions') return 1
        if (right.path === 'Companies.Definitions') return -1
        return left.path.localeCompare(right.path)
      })
      sections.push({
        fields,
        id: 'config:Companies',
        label: humanize(key),
        scope,
      })
    } else if (
      value !== null &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      !value.__skyType &&
      Object.keys(value).length > 0
    ) {
      const fields = []
      addField(fields, scope, key, value)
      sections.push({
        fields,
        id: `${scope}:${key}`,
        label: humanize(key),
        scope,
      })
    } else {
      addField(generalFields, scope, key, value)
    }
  }
  if (generalFields.length) {
    const general = {
      fields: generalFields,
      id: `${scope}:general`,
      label: 'General',
      scope,
    }
    if (scope === 'config') sections.unshift(general)
    else sections.push(general)
  }
  return sections
}

function loadConfiguratorSections() {
  const resourceRoot = resolve(__dirname, '../..')
  const config = serializeLuaValue(
    new LuaConfigParser(
      readFileSync(
        resolve(resourceRoot, 'sky_phone/config/config.lua'),
        'utf8',
      ),
    ).parse(),
  )
  const mediaRoot = serializeLuaValue(
    new LuaConfigParser(
      readFileSync(resolve(resourceRoot, 'sky_phone/config/media.lua'), 'utf8'),
    ).parse(),
  )
  const media = mediaRoot.Media
  delete config.PhoneConfigurator
  delete config.Media
  return [...buildSections('config', config), ...buildSections('media', media)]
}

module.exports = { loadConfiguratorSections }
