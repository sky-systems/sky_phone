import type {
  AdminConfiguratorField,
  AdminConfiguratorSection,
} from '@/types/admin'

export const GENERAL_CONFIGURATOR_GROUPS = [
  {
    id: 'device',
    paths: [
      'Phone.Unique',
      'Sim.Enabled',
      'Phone.Item',
      'Phone.DeviceName',
      'Sim.NumberPrefix',
      'Sim.NumberLength',
    ],
  },
  {
    id: 'system',
    paths: [
      'Bridge.Framework',
      'Bridge.Inventory',
      'Bridge.Locale',
      'Calls.VoiceProvider',
    ],
  },
  {
    id: 'usage',
    paths: [
      'Phone.BlockWhenDead',
      'Phone.BlockWhenCuffed',
      'Phone.AllowMovement',
      'Phone.HoldToLook.Enabled',
    ],
  },
  {
    id: 'keys',
    paths: [
      'Phone.Keybind',
      'CrewLink.QuickPing.Enabled',
      'CrewLink.QuickPing.DefaultKey',
      'Phone.HoldToLook.Control',
      'Command',
      'Phone.DevelopmentCommand',
    ],
  },
] as const

export function resolveGeneralConfiguratorField(
  sections: AdminConfiguratorSection[],
  drafts: Record<string, unknown>,
  path: string,
): {
  field: AdminConfiguratorField
  value: unknown
  rootValue: unknown
  parts: string[]
} | null {
  const field = sections
    .flatMap((section) => section.fields)
    .find(
      (candidate) =>
        candidate.scope === 'config' &&
        (path === candidate.path || path.startsWith(`${candidate.path}.`)),
    )
  if (!field) return null
  const draftKey = `config:${field.path}`
  // Read even an absent draft so Vue tracks the first edit to this root field.
  const draftValue = drafts[draftKey]
  const rootValue = Object.prototype.hasOwnProperty.call(drafts, draftKey)
    ? draftValue
    : field.value
  const parts =
    path === field.path ? [] : path.slice(field.path.length + 1).split('.')
  let value = rootValue
  for (const part of parts) {
    if (
      !value ||
      typeof value !== 'object' ||
      !Object.prototype.hasOwnProperty.call(value, part)
    )
      return null
    value = (value as Record<string, unknown>)[part]
  }
  return { field, value, rootValue, parts }
}

export function patchGeneralConfiguratorValue(
  value: unknown,
  parts: string[],
  next: unknown,
): unknown {
  if (!parts.length) return next
  const [key, ...rest] = parts
  if (
    !key ||
    !value ||
    typeof value !== 'object' ||
    !Object.prototype.hasOwnProperty.call(value, key)
  ) {
    throw new Error(
      '[sky_phone] General configuration path is missing from the server schema.',
    )
  }
  const record = value as Record<string, unknown>
  return {
    ...record,
    [key]: patchGeneralConfiguratorValue(record[key], rest, next),
  }
}
