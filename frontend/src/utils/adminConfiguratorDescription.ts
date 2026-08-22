import type { AdminConfiguratorStructure } from '@/types/admin'

type ConfiguratorDescriptionTranslator = (
  key: string,
  params?: Record<string, string>,
) => string

export type AdminConfiguratorDescribe = (
  path: string,
  value: unknown,
  structure?: AdminConfiguratorStructure,
  label?: string,
) => string

const DESCRIPTION_RULES: Array<[RegExp, string]> = [
  [/(?:^|\.)(?:apikey|token|password|secret)$/i, 'credential'],
  [/(?:base|manifest|image|icon)?url$/i, 'url'],
  [/(?:allowed)?(?:gif|media)?hosts?$/i, 'hosts'],
  [
    /(?:timeout|timeoutms|milliseconds|durationms|intervalms|pollms)$/i,
    'milliseconds',
  ],
  [/(?:timeoutseconds|seconds)$/i, 'seconds'],
  [/perminute$/i, 'rateLimit'],
  [/(?:maximum|max).*bytes/i, 'byteLimit'],
  [/(?:maximum|max).*length$|length$/i, 'textLimit'],
  [/(?:distance)$/i, 'distance'],
  [/(?:location|position|rotation|coords|coordinates)$/i, 'coordinates'],
  [/(?:model|prop|propmodel|customprop|replacementprop)$/i, 'gameAsset'],
  [/(?:dictionary|dictionaries|clip|clips|pedclip|propclip)$/i, 'animation'],
  [
    /(?:permissions?|admingroups?|allowedjobs?|jobs?|minimumgrade|requiredace)$/i,
    'access',
  ],
  [/(?:framework|inventory|provider|voiceprovider|adapter)$/i, 'integration'],
  [/(?:path)$/i, 'path'],
  [/(?:color|colour|accent)$/i, 'color'],
  [
    /(?:label|name|title|description|address|district|locationlabel|devicename)$/i,
    'displayText',
  ],
  [/(?:number|callernumber|numberprefix)$/i, 'phoneNumber'],
  [/(?:routing)$/i, 'routing'],
  [/(?:command)$/i, 'command'],
  [/(?:locale)$/i, 'locale'],
  [/(?:debug)$/i, 'debug'],
  [/(?:enabled|active|public|verified)$/i, 'featureToggle'],
  [/(?:quality|bitratekbps|volume)$/i, 'mediaQuality'],
  [
    /(?:pagesize|batchsize|limit|count|maxselection|maximumplayers|samples|decimals)$/i,
    'amount',
  ],
]

export function configuratorPathName(path: string): string {
  const listEntry = path.match(/^(.*)\[(\d+)\]$/)
  const source = listEntry?.[1] ?? path
  const segment = source.split('.').at(-1) ?? source
  const name = segment
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
    .replace(/([a-z\d])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .trim()
  return listEntry ? `${name} #${listEntry[2]}` : name
}

export function configuratorDescriptionKey(
  path: string,
  value: unknown,
  structure?: AdminConfiguratorStructure,
): string {
  const segment =
    path
      .replace(/\[\d+\]$/, '')
      .split('.')
      .at(-1) ?? path
  const semanticRule = DESCRIPTION_RULES.find(([pattern]) =>
    pattern.test(segment),
  )
  if (semanticRule) return semanticRule[1]

  if (structure?.kind === 'vector') return 'coordinates'
  if (structure?.kind === 'list' || Array.isArray(value)) return 'list'
  if (structure?.kind === 'map' || structure?.kind === 'table') return 'table'
  if (structure?.kind === 'optionalString') return 'optionalText'
  if (value !== null && typeof value === 'object') return 'table'
  if (typeof value === 'boolean') return 'boolean'
  if (typeof value === 'number') return 'number'
  return 'text'
}

export function describeConfiguratorValue(
  translate: ConfiguratorDescriptionTranslator,
  path: string,
  value: unknown,
  structure?: AdminConfiguratorStructure,
  label?: string,
): string {
  return translate(
    `configurator.descriptions.${configuratorDescriptionKey(path, value, structure)}`,
    { name: label?.trim() || configuratorPathName(path) },
  )
}
