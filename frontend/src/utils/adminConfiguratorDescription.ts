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

const MEDIA_DESCRIPTIONS: Record<string, string> = {
  GiphyApiKey: 'giphyApiKey',
  GifRating: 'gifRating',
  'FiveManage.ApiKey': 'fiveManageApiKey',
  'FiveManage.BaseUrl': 'fiveManageBaseUrl',
  'Import.Enabled': 'importEnabled',
  'Import.Websites': 'importWebsites',
  'Wallpaper.CustomUploadEnabled': 'wallpaperImport',
  'Photo.Encoding': 'photoEncoding',
  'Photo.Quality': 'photoQuality',
  'Video.BitrateKbps': 'videoBitrate',
}

const IMPORT_SOURCE_DESCRIPTIONS: Record<string, string> = {
  Id: 'importSourceId',
  Label: 'importSourceLabel',
  Enabled: 'importSourceEnabled',
  Adapter: 'importAdapter',
  ApiKey: 'importApiKey',
  BaseUrl: 'fiveManageBaseUrl',
  Path: 'importPath',
  MediaTypes: 'importMediaTypes',
  AllowedMediaHosts: 'importHosts',
  ManifestUrl: 'importManifestUrl',
  RequiredAce: 'importRequiredAce',
  Auth: 'importAuth',
  'Auth.Type': 'importAuth',
  'Auth.TokenConvar': 'importAuthConvar',
  'Auth.ValueConvar': 'importAuthConvar',
  'Auth.Header': 'importAuthHeader',
}

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
  if (path === 'Calls.VoiceProvider') return 'callsVoiceProvider'
  if (path === 'Speaker.Enabled') return 'phoneSpeaker'
  if (path === 'Security.FaceIdMaskWhitelist') return 'faceIdMaskWhitelist'
  const faceIdMask = path.match(
    /^Security\.FaceIdMaskWhitelist(?:\[\d+\]|\.\d+)\.(Model|Drawable|Texture)$/,
  )
  if (faceIdMask) return `faceIdMask${faceIdMask[1]}`
  if (path === 'CrewLink.PingCooldownSeconds') return 'crewlinkPingCooldown'
  const crewlink = path.match(/^CrewLink\.(Blip|QuickPing)\.([^.]+)$/)
  if (crewlink) return `crewlink${crewlink[1]}${crewlink[2]}`
  const mediaPath = path.replace(/^Media\./, '').replace(/\[\d+\]$/, '')
  const source = path
    .replace(/^Media\./, '')
    .match(/^Import\.Websites(?:\[\d+\]|\.\d+)(?:\.(.*))?$/)
  if (source) {
    if (!source[1]) return 'importSource'
    const field = source[1].replace(/\[\d+\]$/, '')
    if (IMPORT_SOURCE_DESCRIPTIONS[field])
      return IMPORT_SOURCE_DESCRIPTIONS[field]
  }
  if (MEDIA_DESCRIPTIONS[mediaPath]) return MEDIA_DESCRIPTIONS[mediaPath]
  const citywarnBlip = path.match(
    /^CityWarn\.Blip\.(Sprite|Display|ShortRange|CategoryId|CategoryName|GroupByCategory|RadiusEnabled|Radius)$/,
  )
  if (citywarnBlip) return `citywarnBlip${citywarnBlip[1]}`
  if (/^CityWarn\.CategoryColors(?:\.[^.]+)?$/.test(path))
    return 'citywarnCategoryColor'
  if (path === 'Garage.System') return 'garageSystem'
  if (/^Companies\.Definitions\.[^.]+\.ServiceLine\.Routing$/.test(path))
    return 'companyCallRouting'
  if (path === 'Companies.CallRouting.MaxAttempts') return 'companyCallAttempts'
  if (path === 'Companies.CallRouting.RingSeconds')
    return 'companyCallRingSeconds'
  if (/^Companies\.Definitions\.[^.]+\.Name$/.test(path)) return 'companyName'
  if (/^Companies\.Definitions\.[^.]+\.LogoUrl$/.test(path))
    return 'companyLogo'
  if (/^Companies\.Definitions\.[^.]+\.CoverUrl$/.test(path))
    return 'companyCover'
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
