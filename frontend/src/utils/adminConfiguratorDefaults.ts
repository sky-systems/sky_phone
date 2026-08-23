import type { AdminConfiguratorStructure } from '@/types/admin'

function cloneConfiguratorValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(cloneConfiguratorValue)
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [
        key,
        cloneConfiguratorValue(child),
      ]),
    )
  }
  return value
}

function blankScalar(valueType: 'boolean' | 'number' | 'string'): unknown {
  if (valueType === 'boolean') return false
  if (valueType === 'number') return 0
  return ''
}

export function blankFromConfiguratorStructure(
  structure: AdminConfiguratorStructure,
): unknown {
  if (structure.kind === 'optionalString') return ''
  if (structure.kind === 'value') return blankScalar(structure.valueType)
  if (structure.kind === 'vector') {
    const axes = ['x', 'y', 'z', 'w'].slice(
      0,
      Number(structure.vectorType.slice(-1)),
    )
    return Object.fromEntries([
      ['__skyType', structure.vectorType],
      ...axes.map((axis) => [axis, 0]),
    ])
  }
  if (structure.kind === 'list') {
    return structure.items.map(blankFromConfiguratorStructure)
  }
  if (structure.kind === 'map') {
    return {
      __skyType: 'map',
      entries: structure.entries.map((entry) => ({
        key: entry.key,
        keyType: entry.keyType,
        value: blankFromConfiguratorStructure(entry.structure),
      })),
    }
  }
  return Object.fromEntries(
    Object.entries(structure.fields).map(([key, field]) => [
      key,
      blankFromConfiguratorStructure(field),
    ]),
  )
}

export function createMutableTableEntry(
  structure: Extract<AdminConfiguratorStructure, { kind: 'table' }>,
  path: string,
  key: string,
  entries: Record<string, unknown> = {},
): unknown {
  const value =
    structure.entryDefault !== undefined
      ? cloneConfiguratorValue(structure.entryDefault)
      : structure.template
        ? blankFromConfiguratorStructure(structure.template)
        : undefined

  if (
    path !== 'Companies.Definitions' ||
    value === null ||
    typeof value !== 'object' ||
    Array.isArray(value)
  ) {
    return value
  }

  const company = value as Record<string, unknown>
  company.Job = key
  company.Name = key
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase())
  company.LogoUrl = `https://picsum.photos/seed/companies-${key}-logo/180/180`
  if (Array.isArray(company.Services)) {
    if (company.Services.length === 0) {
      company.Services.push({
        Description: '',
        Id: key,
        Price: '',
        RequestsEnabled: true,
        Title: company.Name,
      })
    } else {
      const service = company.Services[0]
      if (
        service !== null &&
        typeof service === 'object' &&
        !Array.isArray(service) &&
        !(service as Record<string, unknown>).Id
      ) {
        const mutableService = service as Record<string, unknown>
        mutableService.Id = key
        mutableService.Title = company.Name
      }
    }
  }
  const serviceLine = company.ServiceLine
  if (
    serviceLine !== null &&
    typeof serviceLine === 'object' &&
    !Array.isArray(serviceLine)
  ) {
    const mutableServiceLine = serviceLine as Record<string, unknown>
    const number = String(mutableServiceLine.Number ?? '')
    const numeric = Number(number)
    if (/^\d+$/.test(number) && Number.isSafeInteger(numeric) && numeric > 0) {
      const used = new Set(
        Object.values(entries).map((entry) => {
          if (entry === null || typeof entry !== 'object') return ''
          const line = (entry as Record<string, unknown>).ServiceLine
          if (line === null || typeof line !== 'object') return ''
          return String((line as Record<string, unknown>).Number ?? '').replace(
            /\D/g,
            '',
          )
        }),
      )
      const maximum = 10 ** number.length - 1
      for (let offset = 0; offset < maximum; offset += 1) {
        const candidate = ((numeric - 1 + offset) % maximum) + 1
        const formatted = String(candidate).padStart(number.length, '0')
        if (!used.has(formatted)) {
          mutableServiceLine.Number = formatted
          break
        }
      }
    }
  }
  return company
}
