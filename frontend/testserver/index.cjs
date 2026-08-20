const { randomUUID } = require('node:crypto')

const cors = require('cors')
const express = require('express')

const app = express()
const port = Number(process.argv[2]) || 3001

app.use(cors())
app.use(express.json({ limit: '3mb' }))

const lifecycleEndpoints = new Set([
  'camera:setActive',
  'camera:setLocked',
  'camera:setFacing',
  'camera:setFlash',
  'camera:setFocus',
  'camera:setOrientation',
  'camera:setZoom',
  'close',
  'custom-app:lifecycle',
  'device:notification-open',
  'notification:focus',
  'sim:picker-close',
  'ui:opened',
  'ui:ready',
])

function calendarTime(dayOffset, hour, minute = 0) {
  const value = new Date()
  value.setDate(value.getDate() + dayOffset)
  value.setHours(hour, minute, 0, 0)
  return value.getTime()
}

function isoTime(offsetMilliseconds) {
  return new Date(Date.now() + offsetMilliseconds).toISOString()
}

function unixTime(offsetSeconds = 0) {
  return Math.floor(Date.now() / 1000) + offsetSeconds
}

function healthDate(dayOffset) {
  const value = new Date()
  value.setDate(value.getDate() + dayOffset)
  return value.toISOString().slice(0, 10)
}

const healthStepSamples = [4289, 6312, 3421, 7024, 8618, 4302, 6420]
let healthMedicalId = {
  allergies: '',
  bloodType: 'O+',
  conditions: '',
  emergencyName: 'Jamie Morgan',
  emergencyPhone: '5550102211',
  emergencyRelation: 'Sibling',
  medication: '',
  playerName: 'Alex Morgan',
}

function healthOverview() {
  return {
    dailyStepGoal: 8000,
    days: healthStepSamples.map((steps, index) => ({
      activeSeconds: Math.round(steps * 0.36),
      date: healthDate(index - 6),
      distanceMeters: Math.round(steps * 0.75),
      energyKcal: Math.round(steps * 0.045),
      steps,
    })),
    emergencyNumber: '911',
    medicalId: healthMedicalId,
    previousWeekSteps: 36980,
  }
}

function memoWaveform(phase = 0) {
  return Array.from({ length: 48 }, (_, index) =>
    Number(
      (0.12 + Math.abs(Math.sin((index + phase) * 0.67)) * 0.76).toFixed(3),
    ),
  )
}

let authenticated = true
let draft = null
let mockMailboxes = [{ count: 0, id: 7, name: 'Projects', sort_order: 0 }]
let nextMockMailboxId = 8
const radioData = {
  badge: '231',
  badgeEnabled: true,
  badgeMaxLength: 8,
  connected: false,
  displayName: 'Unit 21',
  displayNameAllowed: true,
  displayNameEnabled: true,
  displayNameMaxLength: 32,
  frequency: 0,
  frequencyMax: 999.9,
  frequencyMin: 0.1,
  frequencyStep: 0.1,
  history: [
    { primary: 120.5, secondary: 130.7 },
    { primary: 42.1, secondary: 0 },
  ],
  members: [],
  provider: 'saltychat',
  secondaryFrequency: 0,
  secondarySupported: true,
  speakerEnabled: false,
  speakerSupported: true,
  settings: { autoRejoin: false, notifications: true },
  volume: 50,
}
let musicSequence = 3
const musicServerTracks = [
  {
    id: 'city-after-dark',
    source: 'server',
    title: 'City After Dark',
    artist: 'Sky Records',
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    artwork: 'https://picsum.photos/seed/sky-music-city/600/600',
  },
  {
    id: 'pacific-drive',
    source: 'server',
    title: 'Pacific Drive',
    artist: 'Vespucci FM',
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    artwork: 'https://picsum.photos/seed/sky-music-pacific/600/600',
  },
  {
    id: 'neon-rain',
    source: 'server',
    title: 'Neon Rain',
    artist: 'Mirror Park',
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    artwork: 'https://picsum.photos/seed/sky-music-neon/600/600',
  },
]
let musicYoutubeTracks = [
  {
    id: 'music-youtube-1',
    source: 'youtube',
    videoId: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    artist: 'Rick Astley',
    artwork: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    createdAt: Date.now() - 120000,
  },
]
let musicPlaylists = [
  {
    id: 'music-playlist-1',
    name: 'Night Ride',
    createdAt: Date.now() - 86400000,
    entries: [
      { source: 'server', songId: 'city-after-dark' },
      { source: 'server', songId: 'neon-rain' },
      { source: 'youtube', songId: 'music-youtube-1' },
    ],
  },
]

function musicBootstrap() {
  return {
    serverTracks: musicServerTracks,
    youtubeTracks: musicYoutubeTracks,
    playlists: musicPlaylists,
  }
}

async function fetchYoutubeMetadata(videoId) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 4500)
  try {
    const watchUrl = `https://www.youtube.com/watch?v=${videoId}`
    const response = await fetch(
      `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(watchUrl)}`,
      {
        headers: { Accept: 'application/json' },
        signal: controller.signal,
      },
    )
    if (!response.ok) return null
    const data = await response.json()
    const title = typeof data.title === 'string' ? data.title.trim() : ''
    const artist =
      typeof data.author_name === 'string' ? data.author_name.trim() : ''
    return title && artist ? { artist, title } : null
  } catch {
    return null
  } finally {
    clearTimeout(timeout)
  }
}
let mockBankBalance = 24787
let cryptoAuthenticated = true
let cryptoRegistered = true
let cryptoCashBalance = 18420
let cryptoQuote = null
let nextCryptoActivityId = 5
let cryptoPassword = 'VaultX123!'
function createCryptoMarket({
  changePercent,
  color,
  id,
  logo,
  name,
  price,
  supply,
  symbol,
}) {
  const numericPrice = Number(price)
  const direction = changePercent >= 0 ? 1 : -1
  const rawSparkline = Array.from({ length: 12 }, (_, index) => {
    const wave = Math.sin((index + id.length) * 1.17) * 0.13
    return 0.28 + index * 0.045 * direction + wave
  })
  const minimum = Math.min(...rawSparkline)
  const maximum = Math.max(...rawSparkline)
  const span = Math.max(0.01, maximum - minimum)
  const normalizedSparkline = rawSparkline.map(
    (value) => (value - minimum) / span,
  )
  const startPrice = numericPrice / (1 + changePercent / 100)
  const priceHistory = normalizedSparkline.map((value, index) => {
    const progress = index / (normalizedSparkline.length - 1)
    const trend = startPrice + (numericPrice - startPrice) * progress
    const fluctuation =
      numericPrice * 0.018 * (value - 0.5) * Math.sin(Math.PI * progress)
    return Math.max(0.01, trend + fluctuation).toFixed(2)
  })
  priceHistory[priceHistory.length - 1] = numericPrice.toFixed(2)
  return {
    changePercent,
    color,
    enabled: true,
    high24h: (numericPrice * (1.025 + Math.abs(changePercent) / 100)).toFixed(
      2,
    ),
    id,
    issuedSupply: String(supply),
    logo,
    low24h: (
      numericPrice * Math.max(0.1, 0.975 - Math.abs(changePercent) / 100)
    ).toFixed(2),
    name,
    price,
    priceHistory,
    sparkline: normalizedSparkline,
    symbol,
    treasuryAvailable: String(Math.floor(supply * 0.82)),
  }
}
const cryptoMarkets = [
  createCryptoMarket({
    id: 'aurora',
    symbol: 'AUR',
    name: 'Aurora',
    logo: '◈',
    color: '#25d9ad',
    price: '128.50',
    changePercent: 4.82,
    supply: 1000000,
  }),
  createCryptoMarket({
    id: 'vertex',
    symbol: 'VTX',
    name: 'Vertex',
    logo: '◆',
    color: '#4d8cff',
    price: '42.75',
    changePercent: -1.37,
    supply: 2500000,
  }),
  createCryptoMarket({
    id: 'ember',
    symbol: 'EMB',
    name: 'Ember',
    logo: '✦',
    color: '#ff9d54',
    price: '9.80',
    changePercent: 7.21,
    supply: 8000000,
  }),
  createCryptoMarket({
    id: 'titan',
    symbol: 'TTN',
    name: 'Titan',
    logo: '⬢',
    color: '#8f7cff',
    price: '4250000.00',
    changePercent: 1.18,
    supply: 21000,
  }),
  createCryptoMarket({
    id: 'crown',
    symbol: 'CRN',
    name: 'Crown',
    logo: '♛',
    color: '#f6c453',
    price: '1280000.00',
    changePercent: -0.42,
    supply: 64000,
  }),
  createCryptoMarket({
    id: 'atlas',
    symbol: 'ATL',
    name: 'Atlas',
    logo: '▲',
    color: '#e66f9e',
    price: '120000.00',
    changePercent: 2.66,
    supply: 250000,
  }),
  createCryptoMarket({
    id: 'zenith',
    symbol: 'ZNT',
    name: 'Zenith',
    logo: '✥',
    color: '#6b8cff',
    price: '680000.00',
    changePercent: 0.84,
    supply: 125000,
  }),
  createCryptoMarket({
    id: 'celestium',
    symbol: 'CLS',
    name: 'Celestium',
    logo: '✧',
    color: '#8ad8ff',
    price: '84500.00',
    changePercent: -2.14,
    supply: 420000,
  }),
  createCryptoMarket({
    id: 'orbit',
    symbol: 'ORB',
    name: 'Orbit',
    logo: '◎',
    color: '#57c7ff',
    price: '12440.00',
    changePercent: 3.06,
    supply: 900000,
  }),
  createCryptoMarket({
    id: 'helix',
    symbol: 'HLX',
    name: 'Helix',
    logo: '⌁',
    color: '#c47cff',
    price: '5820.00',
    changePercent: 5.42,
    supply: 1400000,
  }),
  createCryptoMarket({
    id: 'nova',
    symbol: 'NVA',
    name: 'Nova',
    logo: '✺',
    color: '#ff6f91',
    price: '3250.00',
    changePercent: -4.72,
    supply: 2200000,
  }),
  createCryptoMarket({
    id: 'prism',
    symbol: 'PRM',
    name: 'Prism',
    logo: '◇',
    color: '#5ee1c4',
    price: '745.00',
    changePercent: 6.18,
    supply: 3800000,
  }),
  createCryptoMarket({
    id: 'quantum',
    symbol: 'QTM',
    name: 'Quantum',
    logo: '◉',
    color: '#7a9cff',
    price: '214.00',
    changePercent: -3.22,
    supply: 5200000,
  }),
  createCryptoMarket({
    id: 'drift',
    symbol: 'DRF',
    name: 'Drift',
    logo: '≋',
    color: '#4ecdc4',
    price: '76.00',
    changePercent: 2.47,
    supply: 12000000,
  }),
  createCryptoMarket({
    id: 'pulse',
    symbol: 'PLS',
    name: 'Pulse',
    logo: '◍',
    color: '#ff5f7f',
    price: '18.40',
    changePercent: 8.84,
    supply: 18000000,
  }),
  createCryptoMarket({
    id: 'moss',
    symbol: 'MOS',
    name: 'Moss',
    logo: '♧',
    color: '#64c987',
    price: '4.60',
    changePercent: -5.06,
    supply: 36000000,
  }),
  createCryptoMarket({
    id: 'flux',
    symbol: 'FLX',
    name: 'Flux',
    logo: 'ϟ',
    color: '#a777e3',
    price: '2.38',
    changePercent: 11.24,
    supply: 44000000,
  }),
  createCryptoMarket({
    id: 'tide',
    symbol: 'TDE',
    name: 'Tide',
    logo: '≈',
    color: '#46a6ff',
    price: '1.25',
    changePercent: 3.78,
    supply: 60000000,
  }),
  createCryptoMarket({
    id: 'spark',
    symbol: 'SPK',
    name: 'Spark',
    logo: '✹',
    color: '#ffb84d',
    price: '0.74',
    changePercent: 14.62,
    supply: 85000000,
  }),
  createCryptoMarket({
    id: 'pebble',
    symbol: 'PBL',
    name: 'Pebble',
    logo: '●',
    color: '#9aa8b8',
    price: '0.22',
    changePercent: -7.36,
    supply: 150000000,
  }),
  createCryptoMarket({
    id: 'nano',
    symbol: 'NNO',
    name: 'Nano',
    logo: 'η',
    color: '#5bd6ff',
    price: '0.09',
    changePercent: 18.44,
    supply: 260000000,
  }),
  createCryptoMarket({
    id: 'shard',
    symbol: 'SHD',
    name: 'Shard',
    logo: '△',
    color: '#70e0d0',
    price: '0.05',
    changePercent: -12.18,
    supply: 420000000,
  }),
  createCryptoMarket({
    id: 'pixel',
    symbol: 'PXL',
    name: 'Pixel',
    logo: '▦',
    color: '#ff78c8',
    price: '0.03',
    changePercent: 21.52,
    supply: 700000000,
  }),
  createCryptoMarket({
    id: 'dust',
    symbol: 'DST',
    name: 'Dust',
    logo: '·',
    color: '#c4b5a5',
    price: '0.01',
    changePercent: -9.74,
    supply: 1200000000,
  }),
]
const cryptoMarketDynamics = new Map()
const cryptoGlobalCycle = {
  bias: 0,
  direction: 0,
  remainingTicks: 0,
  target: 0,
}
function advanceCryptoCycle(
  cycle,
  minimumTicks,
  maximumTicks,
  minimumStrength,
  maximumStrength,
) {
  if (cycle.remainingTicks <= 0) {
    cycle.direction =
      cycle.direction === 0 ? (Math.random() < 0.5 ? -1 : 1) : -cycle.direction
    cycle.remainingTicks = Math.floor(
      minimumTicks + Math.random() * (maximumTicks - minimumTicks + 1),
    )
    cycle.target =
      cycle.direction *
      (minimumStrength + Math.random() * (maximumStrength - minimumStrength))
  }
  cycle.bias += (cycle.target - cycle.bias) * 0.18
  cycle.remainingTicks -= 1
  return cycle.bias
}
function advanceCryptoMarkets() {
  const updatedAt = Date.now()
  const globalBias = advanceCryptoCycle(
    cryptoGlobalCycle,
    24,
    54,
    0.00008,
    0.00024,
  )
  for (const market of cryptoMarkets) {
    const currentPrice = Number(market.price)
    const fractionDigits = currentPrice < 1 ? 4 : 2
    const minimumStep = 10 ** -fractionDigits
    const volatility =
      currentPrice >= 100_000
        ? 0.00018
        : currentPrice >= 100
          ? 0.00055
          : currentPrice >= 1
            ? 0.0012
            : 0.004
    const dynamics = cryptoMarketDynamics.get(market.id) ?? {
      bias: 0,
      direction: 0,
      momentum: 0,
      remainingTicks: 0,
      target: 0,
    }
    const cycleBias = advanceCryptoCycle(
      dynamics,
      14,
      30,
      volatility * 0.28,
      volatility * 0.52,
    )
    const impulse = (Math.random() * 2 - 1) * volatility * 0.2
    dynamics.momentum = dynamics.momentum * 0.8 + impulse * 0.2
    cryptoMarketDynamics.set(market.id, dynamics)
    const movement = Math.max(
      -volatility * 0.9,
      Math.min(
        volatility * 0.9,
        cycleBias + globalBias + dynamics.momentum + impulse,
      ),
    )
    const direction = movement < 0 ? -1 : 1
    let nextPrice = Number(
      Math.max(minimumStep, currentPrice * (1 + movement)).toFixed(
        fractionDigits,
      ),
    )
    if (nextPrice === currentPrice) {
      nextPrice = Math.max(minimumStep, currentPrice + direction * minimumStep)
    }

    const formattedPrice = nextPrice.toFixed(fractionDigits)
    const priceHistory = [...(market.priceHistory ?? []), formattedPrice].slice(
      -48,
    )
    const numericHistory = priceHistory.map(Number)
    const minimum = Math.min(...numericHistory)
    const maximum = Math.max(...numericHistory)
    const span = Math.max(minimumStep, maximum - minimum)

    market.changePercent =
      ((nextPrice - numericHistory[0]) / numericHistory[0]) * 100
    market.high24h = Math.max(Number(market.high24h), nextPrice).toFixed(
      fractionDigits,
    )
    market.low24h = Math.min(Number(market.low24h), nextPrice).toFixed(
      fractionDigits,
    )
    market.price = formattedPrice
    market.priceHistory = priceHistory
    market.sparkline = numericHistory.map((price) => (price - minimum) / span)
    market.updatedAt = updatedAt
  }
  return cryptoMarkets
}
let cryptoProfile = {
  createdAt: Date.now() - 42 * 86400000,
  handle: 'skyline',
  hideBalances: false,
  id: 'crypto-profile-demo',
  priceAlerts: true,
  status: 'active',
  totalTrades: 12,
  totalVolume: '18462.80',
  tradeConfirmations: true,
  walletKey: 'VX-7F3A-92C1-44BE-810D',
}
const cryptoRecipient = {
  handle: 'receiver',
  walletKey: 'VX-DEAD-BEEF-C0DE-2026',
}
let cryptoHoldings = [
  {
    assetId: 'aurora',
    averagePrice: '112.30',
    quantity: '32.500000',
    value: '4176.25',
  },
  {
    assetId: 'vertex',
    averagePrice: '46.10',
    quantity: '85.250000',
    value: '3644.44',
  },
]
let cryptoActivity = [
  {
    id: 'crypto-4',
    type: 'buy',
    amount: '3650',
    marketId: 'vertex',
    status: 'completed',
    createdAt: Date.now() - 2 * 3600000,
  },
  {
    id: 'crypto-3',
    type: 'sell',
    amount: '920',
    marketId: 'ember',
    status: 'completed',
    createdAt: Date.now() - 26 * 3600000,
  },
  {
    id: 'crypto-2',
    type: 'buy',
    amount: '4020',
    marketId: 'aurora',
    status: 'completed',
    createdAt: Date.now() - 3 * 86400000,
  },
  {
    id: 'crypto-1',
    type: 'deposit',
    amount: '25000',
    status: 'completed',
    createdAt: Date.now() - 4 * 86400000,
  },
]
let mockCashBalance = 2350
let nextBankTransactionId = 7
let mockMapMarkers = [
  {
    color: 'blue',
    coords: { x: -75.2, y: -818.9, z: 0 },
    id: 'mock-map-marker-1',
    label: 'Meeting point',
  },
]
let crewLinkProfile = {
  activeGroupId: 'crewlink-group-night-shift',
  avatarMediaId: 1,
  avatarUrl: 'https://picsum.photos/seed/crewlink-skyline/240/240',
  id: 'crewlink-profile-skyline',
  mapVisible: true,
  overheadVisible: false,
  username: 'Skyline',
}
const crewLinkTestPassword = 'CrewLink123!'
let crewLinkAuthenticated = false
let crewLinkGroups = [
  {
    allowMemberPings: true,
    colour: 'cyan',
    id: 'crewlink-group-night-shift',
    inviteCode: 'N1GHT247',
    isOwner: true,
    memberCount: 6,
    name: 'Night Shift',
    overheadAllowed: true,
    role: 'owner',
  },
  {
    allowMemberPings: false,
    colour: 'violet',
    id: 'crewlink-group-coastline',
    isOwner: false,
    memberCount: 4,
    name: 'Coastline Crew',
    overheadAllowed: true,
    role: 'member',
  },
]
const crewLinkMembers = {
  'crewlink-group-night-shift': [
    {
      coords: { x: -155.2, y: -1005.8, z: 28.4 },
      avatarUrl: 'https://picsum.photos/seed/crewlink-skyline/240/240',
      id: 'crewlink-profile-skyline',
      joinedAt: Date.now() - 36 * 86400000,
      mapVisible: true,
      online: true,
      overheadVisible: false,
      role: 'owner',
      source: 1,
      username: 'Skyline',
    },
    {
      coords: { x: -67.6, y: -818.1, z: 326.2 },
      id: 'crewlink-profile-nova',
      joinedAt: Date.now() - 30 * 86400000,
      mapVisible: true,
      online: true,
      overheadVisible: true,
      role: 'coordinator',
      source: 22,
      username: 'Nova',
    },
    {
      coords: { x: 214.8, y: -810.4, z: 30.7 },
      id: 'crewlink-profile-ghost',
      joinedAt: Date.now() - 20 * 86400000,
      mapVisible: true,
      online: true,
      overheadVisible: true,
      role: 'moderator',
      source: 38,
      username: 'Ghost',
    },
    {
      id: 'crewlink-profile-luna',
      joinedAt: Date.now() - 12 * 86400000,
      mapVisible: false,
      online: true,
      overheadVisible: false,
      role: 'member',
      source: 41,
      username: 'Luna',
    },
    {
      id: 'crewlink-profile-mason',
      joinedAt: Date.now() - 8 * 86400000,
      mapVisible: true,
      online: false,
      overheadVisible: false,
      role: 'member',
      username: 'Mason',
    },
    {
      id: 'crewlink-profile-raven',
      joinedAt: Date.now() - 2 * 86400000,
      mapVisible: true,
      online: false,
      overheadVisible: false,
      role: 'guest',
      username: 'Raven',
    },
  ],
  'crewlink-group-coastline': [
    {
      coords: { x: -1204.3, y: -1488.9, z: 4.4 },
      id: 'crewlink-profile-skyline',
      joinedAt: Date.now() - 5 * 86400000,
      mapVisible: true,
      online: true,
      overheadVisible: false,
      role: 'member',
      source: 1,
      username: 'Skyline',
    },
    {
      coords: { x: -1315.5, y: -1520.2, z: 4.4 },
      id: 'crewlink-profile-wave',
      joinedAt: Date.now() - 40 * 86400000,
      mapVisible: true,
      online: true,
      overheadVisible: true,
      role: 'owner',
      source: 18,
      username: 'Wave',
    },
    {
      id: 'crewlink-profile-sunset',
      joinedAt: Date.now() - 20 * 86400000,
      mapVisible: true,
      online: false,
      overheadVisible: false,
      role: 'moderator',
      username: 'Sunset',
    },
    {
      id: 'crewlink-profile-finn',
      joinedAt: Date.now() - 10 * 86400000,
      mapVisible: false,
      online: true,
      overheadVisible: false,
      role: 'guest',
      source: 56,
      username: 'Finn',
    },
  ],
}
const crewLinkPings = {
  'crewlink-group-night-shift': [
    {
      coords: { x: 233.1, y: -876.4, z: 30.5 },
      createdAt: Date.now() - 45000,
      creatorProfileId: 'crewlink-profile-ghost',
      creatorUsername: 'Ghost',
      expiresAt: Date.now() + 255000,
      id: 'crewlink-ping-meeting',
      label: 'Meet behind the garage',
      type: 'meeting',
    },
    {
      coords: { x: 452.6, y: -980.2, z: 30.7 },
      createdAt: Date.now() - 110000,
      creatorProfileId: 'crewlink-profile-nova',
      creatorUsername: 'Nova',
      expiresAt: Date.now() + 190000,
      id: 'crewlink-ping-danger',
      label: 'Avoid Mission Row',
      type: 'danger',
    },
    {
      coords: { x: -1034.2, y: -2732.1, z: 20.1 },
      createdAt: Date.now() - 25000,
      creatorProfileId: null,
      creatorUsername: 'sky_mission',
      expiresAt: Date.now() + 275000,
      id: 'crewlink-ping-target',
      label: 'Airport pickup',
      sourceResource: 'sky_mission',
      type: 'target',
    },
  ],
  'crewlink-group-coastline': [
    {
      coords: { x: -1302.2, y: -1541.4, z: 4.2 },
      createdAt: Date.now() - 80000,
      creatorProfileId: 'crewlink-profile-wave',
      creatorUsername: 'Wave',
      expiresAt: Date.now() + 220000,
      id: 'crewlink-ping-coast',
      label: 'Boardwalk meeting',
      type: 'info',
    },
  ],
}
let crewLinkInvitations = [
  {
    colour: 'orange',
    expiresAt: Date.now() + 25000,
    groupId: 'crewlink-group-sandy',
    groupName: 'Sandy Trails',
    id: 'crewlink-invite-sandy',
    inviterUsername: 'Dusty',
  },
]
const crewLinkNearby = [
  { distance: 2.4, source: 72, username: 'Echo' },
  { distance: 4.7, source: 83, username: 'Atlas' },
]
const crewLinkLimits = {
  maximumGroups: 5,
  maximumMembers: 16,
  nearbyDistance: 5,
  overheadDistance: 50,
  pingLifetimeSeconds: 300,
}

function crewLinkBootstrap(testScenario = '') {
  if (!crewLinkAuthenticated) {
    return { authenticated: false, groups: [], invitations: [], profile: null }
  }
  if (
    testScenario === 'crewlink-onboarding' ||
    (testScenario === 'crewlink-register' && !crewLinkProfile)
  ) {
    return { authenticated: true, groups: [], invitations: [], profile: null }
  }
  if (testScenario === 'crewlink-empty') {
    return {
      authenticated: true,
      activeGroup: null,
      groups: [],
      invitations: crewLinkInvitations,
      limits: crewLinkLimits,
      profile: { ...crewLinkProfile, activeGroupId: null },
    }
  }
  const activeSummary = crewLinkGroups.find(
    (group) => group.id === crewLinkProfile.activeGroupId,
  )
  return {
    authenticated: true,
    activeGroup: activeSummary
      ? {
          ...activeSummary,
          members: crewLinkMembers[activeSummary.id] ?? [],
          pings: crewLinkPings[activeSummary.id] ?? [],
        }
      : null,
    groups: crewLinkGroups,
    invitations: crewLinkInvitations,
    limits: crewLinkLimits,
    profile: crewLinkProfile,
  }
}
const flipTokProfile = {
  id: 1,
  avatar_media_id: null,
  avatar_url: null,
  handle: 'skyline',
  display_name: 'Skyline',
  bio: 'Life around Los Santos.',
  account_type: 'media',
  verified: true,
  is_following: false,
  is_owner: true,
  followers: 18400,
  following: 128,
  video_count: 2,
}
let flipTokAuthenticated = true
const flipTokMusicTracks = [
  {
    id: 'night-drive',
    title: 'Night Drive',
    artist: 'Los Santos Radio',
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
  },
]
const flipTokMusicExtensions = new Set([
  'aac',
  'm4a',
  'mp3',
  'oga',
  'ogg',
  'opus',
  'wav',
  'webm',
])
function validFlipTokMusicUrl(value) {
  if (
    typeof value !== 'string' ||
    value.length === 0 ||
    value.length > 2048 ||
    /[\s\u0000-\u001f\u007f]/.test(value)
  ) {
    return false
  }
  try {
    const url = new URL(value)
    const host = url.hostname.toLowerCase()
    if (
      url.protocol !== 'https:' ||
      url.username ||
      url.password ||
      url.port ||
      !host.includes('.') ||
      host === 'localhost' ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      /^\d+\.\d+\.\d+\.\d+$/.test(host) ||
      !/^[a-z0-9.-]+$/.test(host) ||
      host
        .split('.')
        .some(
          (label) =>
            !label ||
            label.length > 63 ||
            label.startsWith('-') ||
            label.endsWith('-'),
        )
    ) {
      return false
    }
    const extension = url.pathname.match(/\.([a-z0-9]+)$/i)?.[1]?.toLowerCase()
    return Boolean(extension && flipTokMusicExtensions.has(extension))
  } catch {
    return false
  }
}
function parseFlipTokYoutubeId(value) {
  if (typeof value !== 'string' || value.length > 500) return ''
  try {
    const url = new URL(value)
    if (url.protocol !== 'https:' || url.username || url.password || url.port) {
      return ''
    }
    const host = url.hostname.toLowerCase()
    let videoId = ''
    if (host === 'youtu.be' || host === 'www.youtu.be') {
      videoId = url.pathname.split('/')[1] || ''
    } else if (
      [
        'youtube.com',
        'www.youtube.com',
        'm.youtube.com',
        'music.youtube.com',
        'youtube-nocookie.com',
        'www.youtube-nocookie.com',
      ].includes(host)
    ) {
      videoId =
        url.searchParams.get('v') ||
        url.pathname.match(/^\/(?:shorts|embed|live)\/([a-z0-9_-]+)/i)?.[1] ||
        ''
    }
    return /^[a-z0-9_-]{11}$/i.test(videoId) ? videoId : ''
  } catch {
    return ''
  }
}
function mockYoutubeMetadata(videoId) {
  if (videoId === 'dQw4w9WgXcQ') {
    return { artist: 'Rick Astley', title: 'Never Gonna Give You Up' }
  }
  return { artist: 'YouTube', title: `YouTube ${videoId}` }
}
let flipTokVideos = [
  {
    avatar_url: null,
    id: 'fliptok-1',
    profile_id: 2,
    handle: 'novals',
    display_name: 'Nova',
    verified: true,
    caption: 'A quiet minute above Vinewood. #LosSantos',
    location: 'Vinewood Hills',
    trim_start_ms: 0,
    trim_end_ms: null,
    cover_time_ms: 1200,
    original_volume: 100,
    music_volume: 0,
    music_track: '',
    music_title: '',
    music_artist: '',
    music_source: '',
    music_url: '',
    music_video_id: '',
    media_type: 'video',
    media: [
      {
        id: 2,
        mediaType: 'video',
        url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
      },
    ],
    url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
    comments_enabled: true,
    is_liked: false,
    is_saved: false,
    is_following: false,
    is_owner: false,
    like_count: 12840,
    comment_count: 384,
    view_count: 245100,
    share_count: 932,
    created_at: Date.now() - 3600000,
  },
  {
    avatar_url: null,
    id: 'fliptok-2',
    profile_id: 1,
    handle: 'skyline',
    display_name: 'Skyline',
    verified: true,
    caption: 'Tonight in the city.',
    location: 'Downtown Los Santos',
    trim_start_ms: 800,
    trim_end_ms: 12000,
    cover_time_ms: 2200,
    original_volume: 70,
    music_volume: 25,
    music_track: 'night-drive',
    music_title: 'Night Drive',
    music_artist: 'Los Santos Radio',
    music_source: 'audio',
    music_url: flipTokMusicTracks[0].url,
    music_video_id: '',
    media_type: 'video',
    media: [
      {
        id: 6,
        mediaType: 'video',
        url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
      },
    ],
    url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
    comments_enabled: true,
    is_liked: true,
    is_saved: true,
    is_following: false,
    is_owner: true,
    like_count: 4921,
    comment_count: 97,
    view_count: 88300,
    share_count: 220,
    created_at: Date.now() - 7200000,
  },
  {
    avatar_url: null,
    id: 'fliptok-3',
    profile_id: 1,
    handle: 'skyline',
    display_name: 'Skyline',
    verified: true,
    caption: 'Three stops through Los Santos. #CityLife',
    location: '',
    trim_start_ms: 0,
    trim_end_ms: null,
    cover_time_ms: 0,
    original_volume: 0,
    music_volume: 0,
    music_track: '',
    music_title: '',
    music_artist: '',
    music_source: '',
    music_url: '',
    music_video_id: '',
    media_type: 'photo',
    media: [
      {
        id: 1,
        mediaType: 'photo',
        url: mockGalleryImage('City Night', '#172554', '#111827', '#7c3aed'),
      },
      {
        id: 3,
        mediaType: 'photo',
        url: mockGalleryImage('Beach Drive', '#0369a1', '#164e63', '#fbbf24'),
      },
      {
        id: 4,
        mediaType: 'photo',
        url: mockGalleryImage('Mountain Road', '#475569', '#334155', '#e2e8f0'),
      },
    ],
    url: mockGalleryImage('City Night', '#172554', '#111827', '#7c3aed'),
    comments_enabled: true,
    is_liked: false,
    is_saved: false,
    is_following: false,
    is_owner: true,
    like_count: 812,
    comment_count: 0,
    view_count: 17300,
    share_count: 64,
    created_at: Date.now() - 10800000,
  },
]
let flipTokComments = [
  {
    avatar_url: null,
    id: 'comment-1',
    is_liked: false,
    like_count: 7,
    parent_id: null,
    video_id: 'fliptok-1',
    profile_id: 2,
    reply_to_handle: null,
    handle: 'nova',
    display_name: 'Nova',
    verified: true,
    body: 'This view is perfect.',
    created_at: Date.now() - 300000,
  },
]
let flipTokActivities = [
  {
    avatar_url: null,
    id: 'activity-1',
    profile_id: 2,
    handle: 'nova',
    display_name: 'Nova',
    verified: true,
    kind: 'like',
    video_id: 'fliptok-2',
    read_at: null,
    created_at: Date.now() - 240000,
  },
]
let flipTokReports = [
  {
    id: 'report-1',
    video_id: 'fliptok-1',
    reason: 'dangerous',
    details: 'Please review the driving shown in this clip.',
    created_at: Date.now() - 600000,
    caption: flipTokVideos[0].caption,
    url: flipTokVideos[0].url,
    reporter_handle: 'skyline',
    reporter_display_name: 'Skyline',
    creator_handle: 'novals',
    creator_display_name: 'Nova',
  },
]
let picstagramAuthenticated = true
const picstagramProfiles = [
  {
    avatar_media_id: null,
    avatar_url:
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=240&q=80',
    bio: 'Street light, rain, and the quiet side of Los Santos.',
    display_name: 'Skyline',
    follow_status: null,
    followers: 1842,
    following: 128,
    handle: 'skyline',
    id: 'pic-profile-1',
    is_following: false,
    is_owner: true,
    is_requested: false,
    locked: false,
    post_count: 1,
    private: false,
    status: 'active',
    verified: true,
  },
  {
    avatar_media_id: null,
    avatar_url:
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80',
    bio: 'Golden-hour wanderer.',
    display_name: 'Nova',
    follow_status: 'accepted',
    followers: 9214,
    following: 91,
    handle: 'nova.ls',
    id: 'pic-profile-2',
    is_following: true,
    is_owner: false,
    is_requested: false,
    locked: false,
    post_count: 2,
    private: false,
    status: 'active',
    verified: true,
  },
  {
    avatar_media_id: null,
    avatar_url: null,
    bio: 'Private film diary.',
    display_name: 'Milo Reed',
    follow_status: null,
    followers: 318,
    following: 44,
    handle: 'milo.reed',
    id: 'pic-profile-3',
    is_following: false,
    is_owner: false,
    is_requested: false,
    locked: true,
    post_count: 0,
    private: true,
    status: 'active',
    verified: false,
  },
]
let picstagramPosts = [
  {
    avatar_url: picstagramProfiles[1].avatar_url,
    caption: 'The city holds its breath right before sunrise. #LosSantos',
    comment_count: 2,
    comments_enabled: true,
    created_at: Date.now() - 32 * 60 * 1000,
    display_name: picstagramProfiles[1].display_name,
    handle: picstagramProfiles[1].handle,
    id: 'pic-post-1',
    is_liked: false,
    is_owner: false,
    is_saved: true,
    like_count: 842,
    location: 'Vinewood Hills',
    media: [
      {
        id: 8101,
        media_type: 'photo',
        position: 0,
        url: 'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=900&q=85',
      },
      {
        id: 8102,
        media_type: 'photo',
        position: 1,
        url: 'https://images.unsplash.com/photo-1444723121867-7a241cacace9?auto=format&fit=crop&w=900&q=85',
      },
    ],
    private: false,
    profile_id: picstagramProfiles[1].id,
    verified: true,
  },
  {
    avatar_url: picstagramProfiles[0].avatar_url,
    caption: 'Neon after rain.',
    comment_count: 1,
    comments_enabled: true,
    created_at: Date.now() - 3 * 60 * 60 * 1000,
    display_name: picstagramProfiles[0].display_name,
    handle: picstagramProfiles[0].handle,
    id: 'pic-post-2',
    is_liked: true,
    is_owner: true,
    is_saved: false,
    like_count: 216,
    location: 'Downtown Los Santos',
    media: [
      {
        id: 8103,
        media_type: 'photo',
        position: 0,
        url: 'https://images.unsplash.com/photo-1519608487953-e999c86e7455?auto=format&fit=crop&w=900&q=85',
      },
    ],
    private: false,
    profile_id: picstagramProfiles[0].id,
    verified: true,
  },
]
let picstagramComments = [
  {
    avatar_url: picstagramProfiles[1].avatar_url,
    body: 'That reflection is unreal.',
    created_at: Date.now() - 18 * 60 * 1000,
    display_name: picstagramProfiles[1].display_name,
    handle: picstagramProfiles[1].handle,
    id: 'pic-comment-1',
    is_liked: false,
    is_owner: false,
    like_count: 4,
    parent_id: null,
    profile_id: picstagramProfiles[1].id,
    reply_to_handle: null,
    verified: true,
  },
]
let picstagramStories = [
  {
    avatar_url: picstagramProfiles[1].avatar_url,
    body: 'First light over Vinewood.',
    created_at: Date.now() - 12 * 60 * 1000,
    display_name: picstagramProfiles[1].display_name,
    expires_at: Date.now() + 22 * 60 * 60 * 1000,
    handle: picstagramProfiles[1].handle,
    id: 'pic-story-1',
    is_owner: false,
    media_type: 'photo',
    profile_id: picstagramProfiles[1].id,
    seen: false,
    url: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=85',
    verified: true,
    view_count: 42,
  },
]
let picstagramActivities = [
  {
    avatar_url: picstagramProfiles[1].avatar_url,
    created_at: Date.now() - 9 * 60 * 1000,
    display_name: picstagramProfiles[1].display_name,
    handle: picstagramProfiles[1].handle,
    id: 'pic-activity-1',
    kind: 'like',
    post_id: 'pic-post-2',
    post_url: picstagramPosts[1].media[0].url,
    profile_id: picstagramProfiles[1].id,
    read_at: null,
    verified: true,
  },
]
let picstagramReports = [
  {
    created_at: Date.now() - 45 * 60 * 1000,
    details: 'Please review the caption and location.',
    id: 'pic-report-1',
    reason: 'spam',
    reporter_display_name: 'Skyline',
    reporter_handle: 'skyline',
    target_id: 'pic-post-1',
    target_type: 'post',
  },
]
const mockBankTransactions = [
  {
    id: 1,
    kind: 'transfer_in',
    amount: 3200,
    label: 'Sofia Turner',
    reference: 'mock-1',
    createdAt: Date.now() - 45 * 60 * 1000,
  },
  {
    id: 2,
    kind: 'transfer_out',
    amount: 680,
    label: 'Vincent Cole',
    reference: 'mock-2',
    createdAt: Date.now() - 5 * 60 * 60 * 1000,
  },
  {
    id: 3,
    kind: 'deposit',
    amount: 1250,
    label: '',
    reference: 'mock-3',
    createdAt: Date.now() - 25 * 60 * 60 * 1000,
  },
  {
    id: 4,
    kind: 'transfer_out',
    amount: 420,
    label: 'Maya Brooks',
    reference: 'mock-4',
    createdAt: Date.now() - 50 * 60 * 60 * 1000,
  },
  {
    id: 5,
    kind: 'withdrawal',
    amount: 300,
    label: '',
    reference: 'mock-5',
    createdAt: Date.now() - 76 * 60 * 60 * 1000,
  },
  {
    id: 6,
    kind: 'transfer_in',
    amount: 950,
    label: 'Noah Bennett',
    reference: 'mock-6',
    createdAt: Date.now() - 120 * 60 * 60 * 1000,
  },
]
let mockBillingInvoices = [
  {
    id: '31cc4342-1abd-4c34-a283-fc653632e54f',
    amount: 1300,
    currency: '$',
    description: 'Emergency treatment and medication.',
    direction: 'inbox',
    dueAt: Date.now() + 2 * 86400000,
    issuedAt: Date.now() - 2 * 3600000,
    issuerAccount: 'ambulance',
    issuerLabel: 'Los Santos Medical',
    isUnread: true,
    paidAt: null,
    paymentReference: '',
    status: 'open',
    title: 'Medical treatment',
  },
  {
    id: '1098d704-a8e7-4050-99c9-a496399669ae',
    amount: 999,
    currency: '$',
    description: 'Vehicle repair and replacement parts.',
    direction: 'inbox',
    dueAt: Date.now() - 86400000,
    issuedAt: Date.now() - 4 * 86400000,
    issuerAccount: 'mechanic',
    issuerLabel: 'Benny’s Motorworks',
    isUnread: true,
    paidAt: null,
    paymentReference: '',
    status: 'open',
    title: 'Vehicle repair',
  },
  {
    id: '666f23e1-747e-4df9-b3bb-603340e0af98',
    amount: 480,
    currency: '$',
    description: 'Tow service from Vespucci Boulevard.',
    direction: 'inbox',
    dueAt: Date.now() - 10 * 86400000,
    issuedAt: Date.now() - 14 * 86400000,
    issuerAccount: 'mechanic',
    issuerLabel: 'Los Santos Customs',
    isUnread: false,
    paidAt: Date.now() - 9 * 86400000,
    paymentReference: 'mock-payment-1',
    status: 'paid',
    title: 'Tow service',
  },
  {
    id: '6c6817ae-c859-459c-9934-7ae0ff3b55fb',
    amount: 750,
    currency: '$',
    description: 'Consulting services.',
    direction: 'sent',
    dueAt: Date.now() + 5 * 86400000,
    issuedAt: Date.now() - 86400000,
    issuerAccount: 'consulting',
    issuerLabel: 'Alex Morgan',
    isUnread: false,
    paidAt: null,
    paymentReference: '',
    status: 'open',
    title: 'Consulting',
  },
]
const mockGarageVehicles = [
  {
    id: 'vehicle-1',
    plate: 'SKY 204',
    vin: '1S9SKY204LS000001',
    nickname: 'Midnight',
    model: 'sultanrs',
    name: 'Karin Sultan RS',
    kind: 'car',
    status: 'garaged',
    location: 'Legion Square',
    fuel: 82,
    engine: 96,
    body: 91,
  },
  {
    id: 'vehicle-2',
    plate: 'NOVA 77',
    vin: '1S9NOVA77LS000002',
    nickname: '',
    model: 'comet6',
    name: 'Pfister Comet S2',
    kind: 'car',
    status: 'out',
    location: '',
    fuel: 46,
    engine: 88,
    body: 73,
  },
  {
    id: 'vehicle-3',
    plate: 'SEA 911',
    vin: '1S9SEA911LS000003',
    nickname: 'Blue Current',
    model: 'speeder',
    name: 'Pegassi Speeder',
    kind: 'boat',
    status: 'garaged',
    location: 'La Puerta Pier',
    fuel: 67,
    engine: 84,
    body: 79,
  },
  {
    id: 'vehicle-4',
    plate: 'AIR 404',
    vin: '1S9AIR404LS000004',
    nickname: '',
    model: 'maverick',
    name: 'Buckingham Maverick',
    kind: 'helicopter',
    status: 'impounded',
    location: 'Impound Heli',
    fuel: 23,
    engine: 58,
    body: 44,
  },
]

let mockGarageValet = null

const skyRideProfile = {
  acceptanceRate: 96,
  avatarMediaId: 1,
  avatarUrl:
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=240&q=80',
  cancelledRides: 3,
  completedRides: 146,
  currency: '$',
  defaultPaymentMethod: 'bank',
  earningsToday: 284,
  id: 'skyride-profile-demo',
  memberSince: unixTime(-214 * 24 * 60 * 60),
  name: 'Alex Morgan',
  rating: 4.92,
}
const skyRideDriver = {
  avatarUrl:
    'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=240&q=80',
  id: 'skyride-driver-nova',
  location: { x: -121.8, y: -904.6, z: 29.3 },
  name: 'Nova Hayes',
  phoneNumber: '5550199',
  rating: 4.97,
  trips: 842,
  vehicle: {
    color: 'Obsidian Black',
    model: 'Enus Deity',
    plate: 'RIDE 01',
  },
}
const skyRidePassenger = {
  avatarUrl: skyRideProfile.avatarUrl,
  id: skyRideProfile.id,
  name: skyRideProfile.name,
  phoneNumber: '5550142',
  rating: skyRideProfile.rating,
  trips: skyRideProfile.completedRides,
}

function skyRideWithoutLiveContact(ride) {
  const passenger = { ...ride.passenger }
  delete passenger.phoneNumber
  let driver = null
  if (ride.driver) {
    driver = { ...ride.driver }
    delete driver.location
    delete driver.phoneNumber
  }
  return { ...ride, driver, passenger }
}

const skyRideQuickLocations = [
  {
    coords: { x: -265.1, y: -960.2, z: 31.2 },
    id: 'legion-square',
    label: 'Legion Square',
  },
  {
    coords: { x: 925.2, y: 46.4, z: 81.1 },
    id: 'diamond-casino',
    label: 'Diamond Casino',
  },
  {
    coords: { x: -1037.7, y: -2737.8, z: 20.2 },
    id: 'airport',
    label: 'Los Santos Airport',
  },
  {
    coords: { x: -594.4, y: -929.9, z: 23.9 },
    id: 'vinewood',
    label: 'Vinewood',
  },
]
let skyRideSequence = 4
let skyRideDriverOnline = false
let skyRideActiveRide = null
let skyRidePendingRating = null
let skyRideAvailableRequests = [
  {
    createdAt: unixTime(-90),
    currency: '$',
    destination: skyRideQuickLocations[1],
    distanceMeters: 4200,
    driver: null,
    durationSeconds: 480,
    id: 'skyride-request-demo',
    passenger: {
      avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80',
      id: 'skyride-passenger-jordan',
      name: 'Jordan Lee',
      rating: 4.84,
      trips: 38,
    },
    pickup: skyRideQuickLocations[0],
    price: 42,
    serviceClass: 'comfort',
    status: 'searching',
    updatedAt: unixTime(-90),
  },
]
let skyRideHistory = [
  skyRideWithoutLiveContact({
    createdAt: unixTime(-22 * 60 * 60),
    currency: '$',
    destination: skyRideQuickLocations[3],
    distanceMeters: 4800,
    driver: skyRideDriver,
    durationSeconds: 620,
    finalPrice: 31,
    id: 'skyride-history-1',
    passenger: skyRidePassenger,
    pickup: skyRideQuickLocations[0],
    price: 31,
    serviceClass: 'taxi',
    status: 'completed',
    updatedAt: unixTime(-21 * 60 * 60),
  }),
  skyRideWithoutLiveContact({
    createdAt: unixTime(-3 * 24 * 60 * 60),
    currency: '$',
    destination: skyRideQuickLocations[2],
    distanceMeters: 18700,
    driver: skyRideDriver,
    durationSeconds: 1380,
    finalPrice: 68,
    id: 'skyride-history-2',
    passenger: skyRidePassenger,
    pickup: skyRideQuickLocations[1],
    price: 68,
    serviceClass: 'premium',
    status: 'completed',
    updatedAt: unixTime(-3 * 24 * 60 * 60 + 18 * 60),
  }),
]
const skyRideQuotes = new Map()

function skyRideBootstrap() {
  return {
    activeRide: skyRideActiveRide,
    availableRequests: skyRideAvailableRequests,
    driverEligible: true,
    driverOnline: skyRideDriverOnline,
    history: skyRideHistory,
    pendingRating: skyRidePendingRating,
    profile: skyRideProfile,
    quickLocations: skyRideQuickLocations,
  }
}

function skyRideUpdate(fields) {
  return Object.fromEntries(
    fields.map((field) => [field, skyRideBootstrap()[field]]),
  )
}

const mockHousingOverview = {
  available: true,
  provider: 'esx_property',
  properties: [
    {
      id: 'esx_property:1',
      providerId: '1',
      name: 'Alta Street Apartment',
      access: 'owner',
      locked: true,
      entrance: { x: -268.9, y: -962.3, z: 31.2 },
      capabilities: {
        lock: true,
        keys: true,
        waypoint: true,
        cctv: true,
        garageStatus: true,
      },
      cctv: { enabled: true },
      garage: { enabled: true, storedVehicles: 2 },
      keys: [
        { identifier: 'char2:mock', name: 'Jamie Rivera', online: true },
        { identifier: 'char7:mock', name: 'Sofia Turner', online: false },
        {
          identifier: 'char18:mock',
          name: 'Property Manager',
          online: true,
          revocable: false,
        },
      ],
    },
    {
      id: 'esx_property:3',
      providerId: '3',
      name: 'Rockford Hills Penthouse',
      access: 'owner',
      locked: false,
      entrance: { x: -842.4, y: -25.1, z: 40.4 },
      capabilities: {
        lock: true,
        keys: true,
        waypoint: true,
        cctv: true,
        garageStatus: true,
      },
      cctv: { enabled: true },
      garage: { enabled: true, storedVehicles: 4 },
      keys: [
        { identifier: 'char11:mock', name: 'Mia Bennett', online: true },
        { identifier: 'char14:mock', name: 'Noah Williams', online: false },
      ],
    },
    {
      id: 'esx_property:4',
      providerId: '4',
      name: 'Mirror Park Family Home',
      access: 'owner',
      locked: true,
      entrance: { x: 1260.8, y: -582.1, z: 68.9 },
      capabilities: {
        lock: true,
        keys: true,
        waypoint: true,
        cctv: false,
        garageStatus: true,
      },
      cctv: { enabled: false },
      garage: { enabled: true, storedVehicles: 1 },
      keys: [],
    },
    {
      id: 'esx_property:5',
      providerId: '5',
      name: 'Eclipse Towers Loft',
      access: 'owner',
      locked: false,
      entrance: { x: -777.1, y: 312.4, z: 85.7 },
      capabilities: {
        lock: true,
        keys: true,
        waypoint: true,
        cctv: true,
        garageStatus: true,
      },
      cctv: { enabled: true },
      garage: { enabled: true, storedVehicles: 3 },
      keys: [
        { identifier: 'char5:mock', name: 'Liam Carter', online: true },
        { identifier: 'char9:mock', name: 'Emma Collins', online: true },
        { identifier: 'char22:mock', name: 'Vincent Cole', online: false },
      ],
    },
    {
      id: 'esx_property:2',
      providerId: '2',
      name: 'Vespucci Beach House',
      access: 'keyholder',
      locked: false,
      entrance: { x: -1150.1, y: -1520.8, z: 10.6 },
      capabilities: {
        lock: true,
        keys: false,
        waypoint: true,
        cctv: false,
        garageStatus: false,
      },
      cctv: { enabled: false },
      garage: null,
    },
    {
      id: 'esx_property:6',
      providerId: '6',
      name: 'Del Perro Heights Suite',
      access: 'keyholder',
      locked: true,
      entrance: { x: -1447.8, y: -537.4, z: 34.7 },
      capabilities: {
        lock: true,
        keys: false,
        waypoint: true,
        cctv: true,
        garageStatus: true,
      },
      cctv: { enabled: true },
      garage: { enabled: true, storedVehicles: 1 },
    },
    {
      id: 'esx_property:7',
      providerId: '7',
      name: 'Sandy Shores Ranch',
      access: 'owner',
      locked: true,
      entrance: { x: 1967.2, y: 3819.4, z: 33.4 },
      capabilities: {
        lock: true,
        keys: true,
        waypoint: true,
        cctv: false,
        garageStatus: true,
      },
      cctv: { enabled: false },
      garage: { enabled: false, storedVehicles: 0 },
      keys: [
        { identifier: 'char30:mock', name: 'Bryce Walker', online: false },
      ],
    },
    {
      id: 'esx_property:8',
      providerId: '8',
      name: 'Paleto Bay Cabin',
      access: 'keyholder',
      locked: false,
      entrance: { x: -109.7, y: 6334.1, z: 31.6 },
      capabilities: {
        lock: true,
        keys: false,
        waypoint: true,
        cctv: false,
        garageStatus: false,
      },
      cctv: { enabled: false },
      garage: null,
    },
  ],
}

const mockHousingCandidates = [
  { id: 27, name: 'Alex Morgan' },
  { id: 31, name: 'Jordan Lee' },
  { id: 42, name: 'Taylor Brooks' },
  { id: 56, name: 'Casey Miller' },
  { id: 63, name: 'Morgan Reed' },
  { id: 78, name: 'Avery Parker' },
]

let contactSequence = 40
let smsSequence = 1
const contacts = [
  {
    avatar_media_id: 1,
    avatar_url: 'https://picsum.photos/seed/sky-phone-1/600/800',
    created_at: isoTime(-42 * 86_400_000),
    favorite: true,
    email: 'alex.rivera@ifruit.com',
    id: 'contact-alex',
    name: 'Alex Rivera',
    notes: 'Meeting on Friday at 18:00 near the bank.',
    organization: 'Maze Bank',
    phone_number: '5551110001',
    updated_at: isoTime(-6 * 86_400_000),
  },
  {
    created_at: isoTime(-38 * 86_400_000),
    id: 'contact-alexander',
    name: 'Alexander Stone',
    phone_number: '5551110002',
    updated_at: isoTime(-8 * 86_400_000),
  },
  {
    created_at: isoTime(-21 * 86_400_000),
    id: 'contact-andre',
    name: 'Andre Heinicke',
    phone_number: '5551110003',
    updated_at: isoTime(-4 * 86_400_000),
  },
  {
    created_at: isoTime(-34 * 86_400_000),
    favorite: true,
    id: 'contact-benni',
    name: 'Benni Parker',
    notes: 'Call about the Sultan RS repair estimate.',
    organization: "Benny's Motor Works",
    phone_number: '5551110004',
    updated_at: isoTime(-12 * 86_400_000),
  },
  {
    avatar_media_id: 3,
    avatar_url: 'https://picsum.photos/seed/sky-phone-3/800/600',
    created_at: isoTime(-18 * 86_400_000),
    id: 'contact-bryce',
    name: 'Bryce Walker',
    phone_number: '5551110005',
    updated_at: isoTime(-7 * 86_400_000),
  },
  {
    created_at: isoTime(-27 * 86_400_000),
    id: 'contact-charlie',
    name: 'Charlie Davis',
    phone_number: '5551110006',
    updated_at: isoTime(-11 * 86_400_000),
  },
  {
    created_at: '2026-08-04 12:00:00',
    id: 'contact-1',
    name: 'Jenica Chong',
    phone_number: '5558675309',
    updated_at: '2026-08-04 12:00:00',
  },
  {
    canCall: true,
    canMessage: false,
    companyId: 'police',
    avatar_url: 'https://picsum.photos/seed/companies-police-logo/180/180',
    id: 'company:police',
    name: 'Los Santos Police',
    organization: 'Los Santos Police',
    phone_number: '911',
    readonly: true,
    source: 'company',
    verified: true,
  },
  {
    canCall: true,
    canMessage: false,
    companyId: 'ambulance',
    avatar_url: 'https://picsum.photos/seed/companies-ems-logo/180/180',
    id: 'company:ambulance',
    name: 'Los Santos Medical',
    organization: 'Los Santos Medical',
    phone_number: '912',
    readonly: true,
    source: 'company',
    verified: true,
  },
  {
    canCall: true,
    canMessage: true,
    companyId: 'bennys',
    avatar_url: 'https://picsum.photos/seed/companies-bennys-logo/180/180',
    id: 'company:bennys',
    name: "Benny's Motor Works",
    organization: "Benny's Motor Works",
    phone_number: '5550102',
    readonly: true,
    source: 'company',
    verified: true,
  },
  {
    created_at: isoTime(-14 * 86_400_000),
    id: 'contact-morgan',
    name: 'Morgan Reed',
    phone_number: '5550192847',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-30 * 86_400_000),
    id: 'contact-jamie',
    name: 'Jamie Chen',
    phone_number: '5559876543',
    updated_at: isoTime(-30 * 86_400_000),
  },
  {
    created_at: isoTime(-5 * 86_400_000),
    id: 'contact-mechanic',
    name: 'Downtown Customs',
    phone_number: '5550100101',
    updated_at: isoTime(-5 * 86_400_000),
  },
  {
    avatar_media_id: 4,
    avatar_url: 'https://picsum.photos/seed/sky-phone-4/800/600',
    created_at: isoTime(-3 * 86_400_000),
    favorite: true,
    id: 'contact-taxi',
    name: 'Los Santos Taxi',
    organization: 'Los Santos Taxi Co.',
    phone_number: '5552222222',
    updated_at: isoTime(-3 * 86_400_000),
  },
  {
    created_at: isoTime(-22 * 86_400_000),
    id: 'contact-daniel',
    name: 'Daniel Price',
    phone_number: '5551110007',
    updated_at: isoTime(-3 * 86_400_000),
  },
  {
    created_at: isoTime(-20 * 86_400_000),
    id: 'contact-emily',
    name: 'Emily Hart',
    phone_number: '5551110008',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-31 * 86_400_000),
    id: 'contact-franklin',
    name: 'Franklin Miles',
    phone_number: '5551110009',
    updated_at: isoTime(-9 * 86_400_000),
  },
  {
    created_at: isoTime(-25 * 86_400_000),
    id: 'contact-grace',
    name: 'Grace Carter',
    phone_number: '5551110010',
    updated_at: isoTime(-4 * 86_400_000),
  },
  {
    created_at: isoTime(-19 * 86_400_000),
    id: 'contact-hannah',
    name: 'Hannah Brooks',
    phone_number: '5551110011',
    updated_at: isoTime(-5 * 86_400_000),
  },
  {
    created_at: isoTime(-17 * 86_400_000),
    id: 'contact-ivan',
    name: 'Ivan Petrov',
    phone_number: '5551110012',
    updated_at: isoTime(-6 * 86_400_000),
  },
  {
    created_at: isoTime(-16 * 86_400_000),
    id: 'contact-kevin',
    name: 'Kevin Adams',
    phone_number: '5551110013',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-15 * 86_400_000),
    id: 'contact-naomi',
    name: 'Naomi King',
    phone_number: '5551110014',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-13 * 86_400_000),
    id: 'contact-olivia',
    name: 'Olivia Moore',
    phone_number: '5551110015',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-12 * 86_400_000),
    id: 'contact-paul',
    name: 'Paul Walker',
    phone_number: '5551110016',
    updated_at: isoTime(-4 * 86_400_000),
  },
  {
    created_at: isoTime(-11 * 86_400_000),
    id: 'contact-quinn',
    name: 'Quinn Bailey',
    phone_number: '5551110017',
    updated_at: isoTime(-3 * 86_400_000),
  },
  {
    created_at: isoTime(-10 * 86_400_000),
    id: 'contact-riley',
    name: 'Riley Cooper',
    phone_number: '5551110018',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-9 * 86_400_000),
    id: 'contact-sofia',
    name: 'Sofia Bennett',
    phone_number: '5551110019',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-8 * 86_400_000),
    id: 'contact-thomas',
    name: 'Thomas Reed',
    phone_number: '5551110020',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-7 * 86_400_000),
    id: 'contact-ursula',
    name: 'Ursula Grant',
    phone_number: '5551110021',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-6 * 86_400_000),
    id: 'contact-victor',
    name: 'Victor Young',
    phone_number: '5551110022',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-5 * 86_400_000),
    id: 'contact-wendy',
    name: 'Wendy Clark',
    phone_number: '5551110023',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-4 * 86_400_000),
    id: 'contact-xavier',
    name: 'Xavier Cole',
    phone_number: '5551110024',
    updated_at: isoTime(-2 * 86_400_000),
  },
  {
    created_at: isoTime(-3 * 86_400_000),
    id: 'contact-yakup',
    name: 'Yakup Broooooo',
    phone_number: '5551110025',
    updated_at: isoTime(-86_400_000),
  },
  {
    created_at: isoTime(-2 * 86_400_000),
    id: 'contact-zoe',
    name: 'Zoe Martinez',
    phone_number: '5551110026',
    updated_at: isoTime(-86_400_000),
  },
  {
    created_at: isoTime(-86_400_000),
    id: 'contact-market',
    name: '24/7 Supermarket',
    phone_number: '5552470000',
    updated_at: isoTime(-3_600_000),
  },
]
const attachmentAssets = {
  gif: new Set(['celebrate', 'hearts', 'party', 'thumbs_up', 'wow']),
  image: new Set([
    'camera-1',
    'camera-2',
    'camera-3',
    'city-lights',
    'desert-road',
    'ocean-air',
    'sunset-drive',
  ]),
  video: new Set(['city-loop', 'ocean-loop', 'sunset-loop']),
}
const gifMocks = [
  ['ICOgUNjpvO0PC', 'Cat reaction'],
  ['MDJ9IbxxvDUQM', 'Happy dog'],
  ['l0HlPystfePnAI3G8', 'Celebrate'],
  ['26ufdipQqU2lhNA4g', 'Wow'],
  ['3o7abKhOpu0NwenH3O', 'Perfect'],
  ['xT0xeJpnrWC4XWblEk', 'Party'],
  ['111ebonMs90YLu', 'Thumbs up'],
  ['5GoVLqeAOo6PK', 'Excited'],
  ['TdfyKrN7HGTIY', 'Happy dance'],
  ['14udF3WUwwGMaA', 'Surprised'],
  ['3o6Zt6ML6BklcajjsA', 'Applause'],
  ['13CoXDiaCcCoyk', 'Let us go'],
  ['R6gvnAxj2ISzJdbA63', 'Yes'],
  ['xUPGcEliCc7bETyfO8', 'Laughing'],
  ['26BRuo6sLetdllPAQ', 'Dancing'],
  ['l46CyJmS9KUbokzsI', 'Amazing'],
  ['g9582DNuQppxC', 'Celebration'],
  ['artj92V8o75VPL7AeQ', 'High five'],
]
const accountDevices = [
  {
    created_at: '2026-08-04 12:00:00',
    current: true,
    device_name: 'iFruit Phone',
    imei: '356938035643809',
    updated_at: '2026-08-04 12:00:00',
  },
]
const messages = [
  {
    body: '## Welcome to iFruit Mail\n\nYour shared mailbox is **ready to use**.\n\n- Send formatted messages\n- Keep drafts on every linked device\n- Reply without losing the conversation\n\n> Tip: use the small formatting bar while composing.',
    // Database dates may cross the NUI boundary as Unix timestamps.
    // Keep one received message numeric so the browser preview covers that contract.
    created_at: Date.parse('2026-08-04T11:30:00'),
    folder: 'inbox',
    id: 1,
    is_read: false,
    message_id: 'b73f3872-54cc-4d74-a058-6caa24f0dfff',
    preview:
      'Your shared mailbox is **ready to use**. Send formatted messages and keep drafts on every linked device.',
    recipients: ['demo@ifruit.com'],
    sender: 'support@ifruit.com',
    subject: 'Welcome to iFruit Mail',
    trashed_at: null,
  },
  {
    body: 'The meet is behind the casino at nine. Bring the blue car.',
    created_at: '2026-08-04 10:15:00',
    folder: 'inbox',
    id: 2,
    is_read: true,
    message_id: '79042d13-f86d-4418-a490-8b558539c20b',
    preview: 'The meet is behind the casino at nine. Bring the blue car.',
    recipients: ['demo@ifruit.com', 'jamie@ifruit.com'],
    sender: 'morgan@ifruit.com',
    subject: 'Tonight',
    trashed_at: null,
  },
  {
    body: 'I will be there.',
    created_at: '2026-08-03 18:05:00',
    folder: 'sent',
    id: 3,
    is_read: true,
    message_id: 'c4414c1e-5fe3-46ea-bc0b-b5b9785c91bd',
    preview: 'I will be there.',
    recipients: ['morgan@ifruit.com'],
    sender: 'demo@ifruit.com',
    subject: 'Re: Tonight',
    trashed_at: null,
  },
  {
    body: 'This is an old message.',
    created_at: '2026-08-02 09:20:00',
    folder: 'inbox',
    id: 4,
    is_read: true,
    message_id: 'd99669ab-c1ac-42d4-8ed4-3c4fe7fa37fb',
    preview: 'This is an old message.',
    recipients: ['demo@ifruit.com'],
    sender: 'news@ifruit.com',
    subject: 'Old mail',
    trashed_at: '2026-08-04 08:00:00',
  },
]
const smsMessages = [
  {
    body: 'Bin gleich am Würfelpark. Kommst du auch?',
    created_at: '2026-08-06 13:04:00',
    direction: 'received',
    id: 'sms-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5558675309',
  },
  {
    body: 'Ja, gib mir fünf Minuten.',
    created_at: '2026-08-06 13:05:00',
    direction: 'sent',
    id: 'sms-2',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5558675309',
    sender_number: '5551234567',
  },
  {
    body: 'Das Fahrzeug ist fertig. Du kannst es jederzeit abholen.',
    created_at: isoTime(-26 * 60 * 60_000),
    direction: 'received',
    id: 'sms-customs-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: isoTime(-25 * 60 * 60_000),
    recipient_number: '5551234567',
    sender_number: '5550100101',
  },
  {
    body: 'Perfekt, ich komme heute Abend vorbei.',
    created_at: isoTime(-25 * 60 * 60_000),
    direction: 'sent',
    id: 'sms-customs-2',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: isoTime(-25 * 60 * 60_000),
    recipient_number: '5550100101',
    sender_number: '5551234567',
  },
  {
    body: 'Treffen wir uns um 20 Uhr am Casino?',
    created_at: isoTime(-7 * 60 * 60_000),
    direction: 'received',
    id: 'sms-morgan-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: isoTime(-6 * 60 * 60_000),
    recipient_number: '5551234567',
    sender_number: '5550192847',
  },
  {
    body: 'Ja, passt. Ich bin puenktlich da.',
    created_at: isoTime(-6 * 60 * 60_000),
    direction: 'sent',
    id: 'sms-morgan-2',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: isoTime(-6 * 60 * 60_000),
    recipient_number: '5550192847',
    sender_number: '5551234567',
  },
  {
    body: 'Bin in zehn Minuten bei dir.',
    created_at: isoTime(-95 * 60_000),
    direction: 'received',
    id: 'sms-jamie-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5559876543',
  },
  {
    body: 'Dein Taxi wartet vor dem Haupteingang.',
    created_at: isoTime(-38 * 60_000),
    direction: 'received',
    id: 'sms-taxi-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5552222222',
  },
  {
    body: 'Danke, ich komme sofort raus.',
    created_at: isoTime(-36 * 60_000),
    direction: 'sent',
    id: 'sms-taxi-2',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: isoTime(-35 * 60_000),
    recipient_number: '5552222222',
    sender_number: '5551234567',
  },
  {
    body: 'Denk bitte an die Unterlagen fuer morgen.',
    created_at: isoTime(-12 * 60_000),
    direction: 'received',
    id: 'sms-alex-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: null,
    media_waveform: null,
    message_type: 'text',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5551110001',
  },
  {
    body: 'Samantha Cole',
    contact: {
      avatar_url: 'https://picsum.photos/seed/shared-samantha/240/240',
      name: 'Samantha Cole',
      organization: 'Downtown Cab Co.',
      phone_number: '5553330044',
    },
    created_at: isoTime(-8 * 60_000),
    direction: 'received',
    id: 'sms-contact-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: {
      avatar_url: 'https://picsum.photos/seed/shared-samantha/240/240',
      name: 'Samantha Cole',
      organization: 'Downtown Cab Co.',
      phone_number: '5553330044',
    },
    media_waveform: null,
    message_type: 'contact',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5551110001',
  },
  {
    body: 'Neon nights in Vinewood',
    created_at: isoTime(-4 * 60_000),
    direction: 'received',
    id: 'sms-share-1',
    media_duration_ms: null,
    media_mime: null,
    media_payload: {
      appId: 'picstagram',
      copyText: 'Die besten Lichter der Stadt – direkt aus Vinewood.',
      id: 'picstagram-post-neon-nights',
      imageUrl: 'https://picsum.photos/seed/easyshare-neon/720/720',
      kind: 'post',
      link: 'skyphone://picstagram/post/picstagram-post-neon-nights',
      subtitle: '@morgan',
      title: 'Neon nights in Vinewood',
    },
    media_waveform: null,
    message_type: 'share',
    media_asset_id: null,
    read_at: null,
    recipient_number: '5551234567',
    sender_number: '5551110001',
  },
]
const darkChatProfile = {
  id: 1,
  darkId: 'dark:7X4K-P92D',
  inviteCode: 'DC-7X4K-NOVA',
  alias: 'Nightshade',
  avatarSeed: 267,
  notificationMode: 'private',
  activityVisible: false,
  createdAt: '2026-08-01 21:20:00',
}
let darkChatProfileActive = true
const darkChatPeers = [
  {
    id: 2,
    darkId: 'dark:N0VA-41KQ',
    alias: 'Nova',
    originalAlias: 'Nova',
    avatarSeed: 142,
    activityVisible: true,
    isContact: true,
    blocked: false,
  },
  {
    id: 3,
    darkId: 'dark:ECH0-77LM',
    alias: 'Echo',
    originalAlias: 'Echo',
    avatarSeed: 311,
    activityVisible: false,
    isContact: true,
    blocked: false,
  },
]
const darkChatConversations = [
  {
    id: 'dc-conversation-nova-0000-000000000001',
    peer: darkChatPeers[0],
    disappearingSeconds: 3600,
    notificationsEnabled: true,
    readReceipts: true,
    blockedByPeer: false,
    createdAt: '2026-08-03 22:12:00',
  },
]
const darkChatMessages = [
  {
    id: 'dc-message-00000000-0000-000000000001',
    conversationId: darkChatConversations[0].id,
    direction: 'received',
    senderProfileId: 2,
    messageType: 'text',
    body: 'The east gate is clear. Are you close?',
    reactions: {},
    createdAt: '2026-08-06 22:42:00',
    readAt: '2026-08-06 22:43:00',
  },
  {
    id: 'dc-message-00000000-0000-000000000002',
    conversationId: darkChatConversations[0].id,
    direction: 'sent',
    senderProfileId: 1,
    messageType: 'text',
    body: 'Two minutes. Keep this channel quiet. 🟣',
    reactions: { 2: '👍' },
    createdAt: '2026-08-06 22:43:00',
    readAt: '2026-08-06 22:43:30',
  },
  {
    id: 'dc-message-00000000-0000-000000000003',
    conversationId: darkChatConversations[0].id,
    direction: 'received',
    senderProfileId: 2,
    messageType: 'gif',
    body: '',
    mediaPayload: 'https://media.giphy.com/media/ICOgUNjpvO0PC/giphy.gif',
    reactions: {},
    createdAt: '2026-08-06 22:44:00',
    readAt: null,
  },
  {
    id: 'dc-message-00000000-0000-000000000004',
    conversationId: darkChatConversations[0].id,
    direction: 'received',
    senderProfileId: 2,
    messageType: 'share',
    body: 'Downtown is awake',
    reactions: {},
    sharePayload: {
      appId: 'feather',
      copyText: 'Vinewood after midnight. No filters, just city light.',
      id: 'feather-post-downtown-awake',
      imageUrl: 'https://picsum.photos/seed/easyshare-downtown/900/600',
      kind: 'post',
      link: 'skyphone://feather/post/feather-post-downtown-awake',
      subtitle: '@nightowl',
      title: 'Downtown is awake',
    },
    createdAt: isoTime(-3 * 60_000),
    readAt: null,
  },
]

function darkChatBootstrap() {
  if (!darkChatProfileActive) {
    return { profile: null, contacts: [], conversations: [] }
  }
  return {
    profile: darkChatProfile,
    contacts: darkChatPeers
      .filter((peer) => peer.isContact)
      .map((peer) => ({ ...peer, createdAt: '2026-08-03 22:12:00' })),
    conversations: darkChatConversations.map((conversation) => {
      const thread = darkChatMessages.filter(
        (message) => message.conversationId === conversation.id,
      )
      const last = thread.at(-1)
      return {
        id: conversation.id,
        peer: conversation.peer,
        disappearingSeconds: conversation.disappearingSeconds,
        blocked: conversation.peer.blocked,
        lastMessage: last?.body ?? '',
        lastMessageType: last?.messageType ?? 'system',
        lastMessageAt: last?.createdAt ?? conversation.createdAt,
        unread: thread.filter(
          (message) => message.direction === 'received' && !message.readAt,
        ).length,
      }
    }),
  }
}
const marketplaceListings = [
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf01',
    seller_account_id: 2,
    seller_name: 'morgan',
    seller_since: '2026-07-02 10:00:00',
    seller_active: 2,
    title: 'Sultan RS in excellent condition',
    description:
      'Clean Sultan RS with fresh service, tidy interior and no known damage. Viewing and test drive available in Vinewood.',
    category: 'vehicles',
    item_condition: 'very_good',
    price_type: 'negotiable',
    price: 185000,
    district: 'vinewood',
    status: 'active',
    revision: 1,
    show_phone: 0,
    phone_number: null,
    created_at: '2026-08-06 09:20:00',
    updated_at: '2026-08-06 09:20:00',
    expires_at: '2026-08-13 09:20:00',
    image: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
    is_favorite: false,
    images: [
      {
        media_id: 'capture-car',
        gradient: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
        sort_order: 1,
      },
      {
        media_id: 'city-lights',
        gradient: 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
        sort_order: 2,
      },
      {
        media_id: 'ocean-air',
        gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
        sort_order: 3,
      },
    ],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf02',
    seller_account_id: 3,
    seller_name: 'jamie',
    seller_since: '2026-06-14 10:00:00',
    seller_active: 1,
    title: 'Modern apartment near Vespucci',
    description:
      'Bright apartment with a city view, underground parking and modern furniture. Available immediately after viewing.',
    category: 'property',
    item_condition: 'very_good',
    price_type: 'fixed',
    price: 420000,
    district: 'vespucci',
    status: 'active',
    revision: 1,
    show_phone: 0,
    phone_number: null,
    created_at: '2026-08-05 17:10:00',
    updated_at: '2026-08-05 17:10:00',
    expires_at: '2026-08-12 17:10:00',
    image: null,
    is_favorite: true,
    images: [],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf03',
    seller_account_id: 4,
    seller_name: 'citytech',
    seller_since: '2026-05-22 10:00:00',
    seller_active: 3,
    title: 'Nearly new gaming laptop',
    description:
      'Fast gaming laptop including charger and carrying bag. Runs quietly and can be tested before purchase.',
    category: 'electronics',
    item_condition: 'very_good',
    price_type: 'fixed',
    price: 3500,
    district: 'los_santos',
    status: 'reserved',
    revision: 2,
    show_phone: 0,
    phone_number: null,
    created_at: '2026-08-05 12:30:00',
    updated_at: '2026-08-06 08:00:00',
    expires_at: '2026-08-12 12:30:00',
    image: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
    is_favorite: false,
    images: [
      {
        media_id: 'ocean-air',
        gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
        sort_order: 1,
      },
    ],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf04',
    seller_account_id: 1,
    seller_name: 'demo',
    seller_since: '2026-08-04 12:00:00',
    seller_active: 1,
    title: 'Complete mechanic tool set',
    description:
      'Complete mechanic tool set with trolley, sockets and diagnostic equipment. Everything is clean and ready for work.',
    category: 'tools',
    item_condition: 'very_good',
    price_type: 'fixed',
    price: 7800,
    district: 'south_los_santos',
    status: 'active',
    revision: 1,
    show_phone: 1,
    phone_number: '5551234567',
    created_at: '2026-08-06 10:45:00',
    updated_at: '2026-08-06 10:45:00',
    expires_at: '2026-08-13 10:45:00',
    image: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
    is_favorite: false,
    images: [
      {
        media_id: 'capture-tools',
        gradient: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
        sort_order: 1,
      },
    ],
  },
]
let marketplaceProfile = {
  avatar_media_id: 1,
  avatar_url: 'https://picsum.photos/seed/citymarkt-demo-avatar/240/240',
  bio: 'Fair prices, quick replies, and meetups anywhere in Los Santos.',
  display_name: 'Skyline Deals',
  email: 'demo@ifruit.com',
  exists: true,
  listing_count: marketplaceListings.filter(
    (listing) => listing.seller_account_id === 1,
  ).length,
}
let linkedAccount = {
  devices: accountDevices,
  email: 'demo@ifruit.com',
  id: 1,
}
let mockNotes = [
  {
    body: 'Meet Morgan in Vinewood and inspect the Sultan RS.',
    createdAt: Date.now() - 3_600_000,
    id: 'demo-note-marketplace',
    pinned: true,
    revision: 1,
    title: 'CityMarkt viewing',
    updatedAt: Date.now() - 3_600_000,
  },
  {
    body: 'Repair kit\nRadio\nFlashlight\nTwo bottles of water',
    createdAt: Date.now() - 7_200_000,
    id: 'demo-note-packing-list',
    pinned: true,
    revision: 2,
    title: 'Patrol equipment',
    updatedAt: Date.now() - 1_800_000,
  },
  {
    body: 'Call Jamie after the garage inspection and confirm the final price.',
    createdAt: Date.now() - 86_400_000,
    id: 'demo-note-call-jamie',
    pinned: false,
    revision: 1,
    title: 'Call Jamie',
    updatedAt: Date.now() - 86_400_000,
  },
  {
    body: 'Observatory, Vespucci Pier, Paleto lookout, Sandy airfield.',
    createdAt: Date.now() - 172_800_000,
    id: 'demo-note-photo-spots',
    pinned: false,
    revision: 1,
    title: 'Photo locations',
    updatedAt: Date.now() - 172_800_000,
  },
]
let mockMemos = [
  {
    createdAt: Date.now() - 25 * 60_000,
    durationMs: 42_100,
    id: '4b918e0e-840e-4f35-99d7-c93b047bc3f7',
    mediaId: 9101,
    mimeType: 'audio/ogg',
    note: 'Patrol route via Mission Row, Pillbox Hill and the Vespucci canals.',
    pinned: true,
    revision: 2,
    sizeBytes: 132_840,
    title: 'Night shift briefing',
    updatedAt: Date.now() - 18 * 60_000,
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    waveform: memoWaveform(1),
  },
  {
    createdAt: Date.now() - 3 * 60 * 60_000,
    durationMs: 18_600,
    id: '7df6287a-a3f1-49cc-a722-a950fc9a5dd2',
    mediaId: 9102,
    mimeType: 'audio/ogg',
    note: 'Check the paint, engine sound and service history before making an offer.',
    pinned: false,
    revision: 1,
    sizeBytes: 61_920,
    title: 'Sultan RS inspection',
    updatedAt: Date.now() - 3 * 60 * 60_000,
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    waveform: memoWaveform(5),
  },
  {
    createdAt: Date.now() - 26 * 60 * 60_000,
    durationMs: 7_400,
    id: '0b2a0d0d-3eb7-4623-873e-829a96a9d525',
    mediaId: 9103,
    mimeType: 'audio/ogg',
    note: 'Repair kit, flashlight and two bottles of water.',
    pinned: false,
    revision: 1,
    sizeBytes: 26_480,
    title: 'Supply reminder',
    updatedAt: Date.now() - 26 * 60 * 60_000,
    url: 'https://media.w3.org/2010/07/bunny/04-Death_Becomes_Fur.oga',
    waveform: memoWaveform(9),
  },
]
let calendarEvents = [
  {
    endsAt: calendarTime(0, 10),
    id: 'calendar-team-briefing',
    note: 'Meet in the Mission Row briefing room. Bring the updated patrol plan.',
    remindedAt: null,
    reminderMinutes: 30,
    revision: 1,
    startsAt: calendarTime(0, 9),
    title: 'Team briefing',
  },
  {
    endsAt: calendarTime(0, 21, 30),
    id: 'calendar-citymarkt-viewing',
    note: 'Inspect the blue Sultan RS at the Vinewood garage and take a short test drive.',
    remindedAt: null,
    reminderMinutes: 60,
    revision: 2,
    startsAt: calendarTime(0, 20),
    title: 'CityMarkt vehicle viewing',
  },
  {
    endsAt: calendarTime(1, 15, 30),
    id: 'calendar-garage-service',
    note: 'Routine service, wheel alignment and diagnostics.',
    remindedAt: null,
    reminderMinutes: 10,
    revision: 1,
    startsAt: calendarTime(1, 14),
    title: 'Garage appointment',
  },
  {
    endsAt: calendarTime(3, 22),
    id: 'calendar-birthday-dinner',
    note: 'Table is booked on the terrace. Pick up the cake first.',
    remindedAt: null,
    reminderMinutes: 1440,
    revision: 1,
    startsAt: calendarTime(3, 19, 30),
    title: "Jamie's birthday dinner",
  },
  {
    endsAt: calendarTime(-2, 18),
    id: 'calendar-past-beach-cruise',
    note: 'Vespucci Pier to the Paleto lookout.',
    remindedAt: calendarTime(-2, 16),
    reminderMinutes: 60,
    revision: 1,
    startsAt: calendarTime(-2, 17),
    title: 'Beach cruise',
  },
]
const demoInstalledAppIds = [
  'citywarn',
  'crypto',
  'health',
  'weazel-news',
  'companies',
  'music',
  'picstagram',
  'skypic',
  'feather',
  'fliptok',
  'flare',
  'calendar',
  'radio',
  'local-pages',
  'crewlink',
  'phone',
  'messages',
  'darkchat',
  'garage',
  'house',
  'map',
  'skyride',
  'banking',
  'billing',
  'mail',
  'notes',
  'memos',
  'calculator',
  'camera',
  'clock',
  'weather',
  'photos',
  'app-store',
  'settings',
  'snake',
  'memory',
  'number-merge',
  'minesweeper',
  'tower-stack',
  'sky-flappy',
  'citymarkt',
  'neon-drop',
]
const demoWallpaperUrl = '/img/wallpapers/sky-phone-demo-gradient.png'
const deviceData = {
  appAuth: {
    payload: {
      accountEmail: 'demo@ifruit.com',
      signedIn: ['citymarkt', 'local-pages', 'feather', 'crewlink', 'skypic'],
      version: 1,
    },
    revision: 1,
  },
  alarms: {
    payload: [
      {
        enabled: true,
        id: 'demo-weekday-alarm',
        lastTriggeredMinute: null,
        note: 'Morning patrol',
        sound: 'radar',
        time: '07:15',
        weekdays: [1, 2, 3, 4, 5],
      },
      {
        enabled: true,
        id: 'demo-garage-alarm',
        lastTriggeredMinute: null,
        note: 'Garage appointment',
        sound: 'chimes',
        time: '13:30',
        weekdays: [],
      },
      {
        enabled: false,
        id: 'demo-weekend-alarm',
        lastTriggeredMinute: null,
        note: 'Weekend drive',
        sound: 'apex',
        time: '09:30',
        weekdays: [0, 6],
      },
    ],
    revision: 3,
  },
  apps: {
    payload: {
      claimedApps: [...demoInstalledAppIds],
    },
    revision: 2,
  },
  games: {
    payload: {
      memory: {
        best: {
          small: { moves: 12, timeMs: 38_400 },
          medium: { moves: 29, timeMs: 92_100 },
        },
        soundEnabled: true,
      },
      minesweeper: {
        best: {
          quick: { timeMs: 44_200 },
          classic: { timeMs: 128_700 },
        },
        elapsedMs: 0,
        game: null,
        soundEnabled: true,
      },
      'neon-drop': { bestLines: 18, bestScore: 12_450, soundEnabled: true },
      'number-merge': {
        bestScore: 8_920,
        game: null,
        highestTile: 1024,
        soundEnabled: true,
      },
      'sky-flappy': { design: 'neon', highScore: 23, soundEnabled: true },
      snake: { highScore: 17, speed: 'normal' },
      'tower-stack': { highHeight: 21, highScore: 4_850, soundEnabled: true },
    },
    revision: 4,
  },
  media: {
    payload: {
      captures: [
        {
          capturedAt: Date.now() - 1_200_000,
          gradient: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
          id: 'capture-car',
          titleKey: 'Apps.photos.samples.capture',
        },
        {
          capturedAt: Date.now() - 5_400_000,
          gradient: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
          id: 'capture-tools',
          titleKey: 'Apps.photos.samples.capture',
        },
      ],
      claimedApps: [],
    },
    revision: 2,
  },
  notifications: {
    payload: {
      items: [
        {
          appId: 'messages',
          id: 'demo-notification-message',
          route: '/apps/messages?phoneNumber=5551110001',
          subtitle: 'Alex Rivera',
          text: 'Meet us at the observatory after sunset.',
          title: 'Messages',
        },
        {
          appId: 'companies',
          id: 'demo-notification-company',
          route: '/apps/companies?area=requests',
          subtitle: 'Los Santos Customs',
          text: 'Your repair request has been accepted.',
          title: 'Companies',
        },
        {
          appId: 'billing',
          id: 'demo-notification-billing',
          route: '/apps/billing',
          subtitle: 'Los Santos Customs',
          text: 'A new invoice for $1,850 is ready.',
          title: 'Billing',
        },
      ],
      version: 1,
    },
    revision: 1,
  },
  settings: {
    payload: {
      settings: {
        airplaneMode: false,
        appearanceMode: 'automatic',
        frame: 'black',
        lockWallpaper: 'custom',
        lockWallpaperImageUrl: demoWallpaperUrl,
        notificationDurationSeconds: 10,
        notificationSound: 'chime',
        notificationVolume: 70,
        phoneScale: 100,
        ringtone: 'skyline',
        ringtoneVolume: 80,
        streamerMode: false,
        wallpaper: 'custom',
        wallpaperHistory: [{ imageUrl: demoWallpaperUrl, wallpaper: 'custom' }],
        wallpaperImageUrl: demoWallpaperUrl,
      },
      version: 1,
    },
    revision: 1,
  },
}
let mockPasscode = ''
let mockSecurity = { enabled: false, length: null, lockedUntil: 0 }
let mockSim = {
  id: 'development-sim',
  number: '5551234567',
  removable: true,
  registered: true,
  type: 'registered',
}
let mockPayphoneCall = null
const blockedCallNumbers = new Set()
let recentCalls = [
  {
    call_id: 'call-alex-incoming',
    created_at: isoTime(-8 * 60_000),
    direction: 'incoming',
    duration_seconds: 184,
    id: 1,
    other_number: '5551110001',
    status: 'completed',
  },
  {
    call_id: 'call-morgan-incoming',
    created_at: isoTime(-18 * 60_000),
    direction: 'incoming',
    duration_seconds: 246,
    id: 2,
    other_number: '5550192847',
    status: 'completed',
  },
  {
    call_id: 'call-taxi-outgoing',
    created_at: isoTime(-42 * 60_000),
    direction: 'outgoing',
    duration_seconds: 39,
    id: 3,
    other_number: '5552222222',
    status: 'completed',
  },
  {
    call_id: 'call-jamie-missed',
    created_at: isoTime(-95 * 60_000),
    direction: 'incoming',
    duration_seconds: 0,
    id: 4,
    other_number: '5559876543',
    status: 'missed',
  },
  {
    call_id: 'call-emily-no-answer',
    created_at: isoTime(-4 * 60 * 60_000),
    direction: 'outgoing',
    duration_seconds: 0,
    id: 5,
    other_number: '5551110008',
    status: 'no_answer',
  },
  {
    call_id: 'call-yakup-incoming',
    created_at: isoTime(-8 * 60 * 60_000),
    direction: 'incoming',
    duration_seconds: 521,
    id: 6,
    other_number: '5551110025',
    status: 'completed',
  },
  {
    call_id: 'call-customs-outgoing',
    created_at: isoTime(-25 * 60 * 60_000),
    direction: 'outgoing',
    duration_seconds: 83,
    id: 7,
    other_number: '5550100101',
    status: 'completed',
  },
  {
    call_id: 'call-unknown-declined',
    created_at: isoTime(-27 * 60 * 60_000),
    direction: 'incoming',
    duration_seconds: 0,
    id: 8,
    other_number: '5554040404',
    status: 'declined',
  },
  {
    call_id: 'call-morgan-outgoing',
    created_at: isoTime(-2 * 86_400_000),
    direction: 'outgoing',
    duration_seconds: 72,
    id: 9,
    other_number: '5550192847',
    status: 'completed',
  },
  {
    call_id: 'call-alex-missed',
    created_at: isoTime(-3 * 86_400_000),
    direction: 'incoming',
    duration_seconds: 0,
    id: 10,
    other_number: '5551110001',
    status: 'missed',
  },
  {
    call_id: 'call-benni-busy',
    created_at: isoTime(-4 * 86_400_000),
    direction: 'outgoing',
    duration_seconds: 0,
    id: 11,
    other_number: '5551110004',
    status: 'busy',
  },
  {
    call_id: 'call-sofia-incoming',
    created_at: isoTime(-5 * 86_400_000),
    direction: 'incoming',
    duration_seconds: 116,
    id: 12,
    other_number: '5551110019',
    status: 'completed',
  },
  {
    call_id: 'call-xavier-unavailable',
    created_at: isoTime(-6 * 86_400_000),
    direction: 'outgoing',
    duration_seconds: 0,
    id: 13,
    other_number: '5551110024',
    status: 'unavailable',
  },
  {
    call_id: 'call-market-outgoing',
    created_at: isoTime(-7 * 86_400_000),
    direction: 'outgoing',
    duration_seconds: 51,
    id: 14,
    other_number: '5552470000',
    status: 'completed',
  },
  {
    call_id: 'call-unknown-missed',
    created_at: isoTime(-8 * 86_400_000),
    direction: 'incoming',
    duration_seconds: 0,
    id: 15,
    other_number: '5559090909',
    status: 'missed',
  },
]
function mockGalleryImage(title, sky, landscape, accent) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1200"><defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${sky}"/><stop offset="1" stop-color="${accent}"/></linearGradient><linearGradient id="land" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${landscape}"/><stop offset="1" stop-color="#101114"/></linearGradient></defs><rect width="900" height="1200" fill="url(#sky)"/><circle cx="690" cy="260" r="105" fill="#fff" opacity=".72"/><path d="M0 690 210 440 390 650 585 360 900 720V1200H0Z" fill="${landscape}" opacity=".84"/><path d="M0 790 230 620 410 765 650 525 900 770V1200H0Z" fill="url(#land)"/><path d="M360 1200 475 690 560 690 690 1200Z" fill="${accent}" opacity=".48"/><text x="54" y="1100" fill="#fff" font-family="system-ui,sans-serif" font-size="62" font-weight="700">${title}</text><text x="57" y="1160" fill="#fff" opacity=".72" font-family="system-ui,sans-serif" font-size="30">Sky Phone test media</text></svg>`
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`
}

let mockMedia = [
  {
    createdAt: Date.now() - 4 * 60_000,
    favorite: false,
    id: 1,
    mediaType: 'photo',
    url: mockGalleryImage('City Night', '#172554', '#111827', '#7c3aed'),
  },
  {
    createdAt: Date.now() - 18 * 60_000,
    favorite: true,
    id: 2,
    mediaType: 'video',
    thumbnailUrl: mockGalleryImage(
      'Flower Video',
      '#7f1d1d',
      '#365314',
      '#fb7185',
    ),
    url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
  },
  {
    createdAt: Date.now() - 47 * 60_000,
    favorite: true,
    id: 3,
    mediaType: 'photo',
    url: mockGalleryImage('Beach Drive', '#0369a1', '#164e63', '#fbbf24'),
  },
  {
    createdAt: Date.now() - 2 * 60 * 60_000,
    favorite: false,
    id: 4,
    mediaType: 'photo',
    url: mockGalleryImage('Mountain Road', '#475569', '#334155', '#e2e8f0'),
  },
  {
    createdAt: Date.now() - 5 * 60 * 60_000,
    favorite: false,
    id: 5,
    mediaType: 'photo',
    url: mockGalleryImage('Downtown', '#312e81', '#1e293b', '#f472b6'),
  },
  {
    createdAt: Date.now() - 8 * 60 * 60_000,
    favorite: false,
    id: 6,
    mediaType: 'video',
    thumbnailUrl: mockGalleryImage(
      'Sintel Video',
      '#9a3412',
      '#431407',
      '#fdba74',
    ),
    url: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
  },
  {
    createdAt: Date.now() - 12 * 60 * 60_000,
    favorite: false,
    id: 7,
    mediaType: 'photo',
    url: mockGalleryImage('Palm Sunset', '#c2410c', '#422006', '#facc15'),
  },
  {
    createdAt: Date.now() - 26 * 60 * 60_000,
    favorite: true,
    id: 8,
    mediaType: 'photo',
    url: mockGalleryImage('Sports Car', '#1f2937', '#111827', '#ef4444'),
  },
  {
    createdAt: Date.now() - 31 * 60 * 60_000,
    favorite: false,
    id: 9,
    mediaType: 'photo',
    url: mockGalleryImage('Boardwalk', '#0e7490', '#713f12', '#67e8f9'),
  },
  {
    createdAt: Date.now() - 46 * 60 * 60_000,
    favorite: false,
    id: 10,
    mediaType: 'video',
    thumbnailUrl: mockGalleryImage(
      'Bunny Video',
      '#166534',
      '#14532d',
      '#86efac',
    ),
    url: 'https://www.w3schools.com/html/mov_bbb.mp4',
  },
  {
    createdAt: Date.now() - 3 * 86_400_000,
    favorite: false,
    id: 11,
    mediaType: 'photo',
    url: mockGalleryImage('Vinewood', '#1d4ed8', '#166534', '#f8fafc'),
  },
  {
    createdAt: Date.now() - 5 * 86_400_000,
    favorite: true,
    id: 12,
    mediaType: 'photo',
    url: mockGalleryImage('Friends', '#7e22ce', '#4c1d95', '#f0abfc'),
  },
]
mockMedia.push(
  ...[
    ['Airport Lights', '#172554', '#1e3a8a', '#38bdf8'],
    ['Desert Route', '#fb923c', '#7c2d12', '#fde047'],
    ['Harbor Morning', '#0e7490', '#164e63', '#a5f3fc'],
    ['Forest Trail', '#166534', '#14532d', '#bef264'],
    ['Neon Alley', '#581c87', '#1e1b4b', '#f472b6'],
    ['Lake House', '#0369a1', '#3f6212', '#fef08a'],
    ['Snow Pass', '#94a3b8', '#334155', '#f8fafc'],
    ['Night Drive', '#111827', '#312e81', '#22d3ee'],
    ['Canyon View', '#b45309', '#78350f', '#fdba74'],
    ['Green Hills', '#15803d', '#365314', '#86efac'],
    ['Purple Sky', '#6b21a8', '#312e81', '#e879f9'],
    ['Ocean Road', '#0284c7', '#0f766e', '#67e8f9'],
    ['City Park', '#4d7c0f', '#14532d', '#facc15'],
    ['Sunrise Pier', '#ea580c', '#7c2d12', '#fef3c7'],
    ['Rainy Street', '#334155', '#0f172a', '#60a5fa'],
    ['Golden Fields', '#ca8a04', '#713f12', '#fef08a'],
    ['Metro Station', '#1f2937', '#374151', '#f43f5e'],
    ['Island Bay', '#0891b2', '#115e59', '#f0fdfa'],
    ['Cliff Road', '#7c3aed', '#3f3f46', '#c4b5fd'],
    ['Old Town', '#9a3412', '#451a03', '#fed7aa'],
    ['Racing Night', '#991b1b', '#111827', '#fb7185'],
    ['Quiet Beach', '#0ea5e9', '#155e75', '#fde68a'],
    ['Hilltop', '#65a30d', '#3f6212', '#d9f99d'],
    ['Downtown Rain', '#3730a3', '#1e293b', '#93c5fd'],
    ['Coastal Sunset', '#be123c', '#7c2d12', '#fbbf24'],
    ['Country Road', '#854d0e', '#365314', '#fde047'],
    ['Blue Mountains', '#1d4ed8', '#334155', '#bfdbfe'],
    ['Palm Beach', '#0d9488', '#166534', '#fcd34d'],
    ['Skyline', '#4338ca', '#111827', '#a78bfa'],
    ['Campfire', '#c2410c', '#431407', '#fef08a'],
  ].map(([title, sky, landscape, accent], index) => ({
    createdAt: Date.now() - (6 + index) * 86_400_000,
    favorite: index % 7 === 0,
    id: 13 + index,
    mediaType: 'photo',
    url: mockGalleryImage(title, sky, landscape, accent),
  })),
)

function mockPhotoUrls(ids) {
  return ids.map((id) => {
    const photo = mockMedia.find(
      (item) => item.id === id && item.mediaType === 'photo',
    )
    if (!photo) {
      throw new Error(`Missing mock gallery photo ${id}`)
    }
    return photo.url
  })
}

function skyPicCaption(value) {
  const caption = typeof value === 'string' ? value.trim() : ''
  return [...caption].length <= 160 ? caption : null
}

function skyPicTextOverlay(value) {
  const textOverlay = typeof value === 'string' ? value.trim() : ''
  return [...textOverlay].length <= 160 ? textOverlay : null
}

function skyPicAvatarSeed(value, fallback) {
  const candidate = value === undefined ? fallback : value
  return Number.isInteger(candidate) &&
    candidate >= 1 &&
    candidate <= 2_147_483_647
    ? candidate
    : null
}

function skyPicRecipientIds(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20) {
    return null
  }
  const seen = new Set()
  const ids = []
  for (const profileId of value) {
    if (
      typeof profileId !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        profileId,
      ) ||
      seen.has(profileId)
    ) {
      return null
    }
    seen.add(profileId)
    ids.push(profileId)
  }
  return ids
}

function skyPicMediaItems(body) {
  const legacy = body.mediaIds === undefined
  if (
    !legacy &&
    (body.mediaId !== undefined ||
      (body.mediaType !== undefined && body.mediaType !== 'photo'))
  ) {
    return null
  }
  const submitted = legacy ? [body.mediaId] : body.mediaIds
  if (
    !Array.isArray(submitted) ||
    submitted.length < 1 ||
    submitted.length > 10 ||
    Object.keys(submitted).length !== submitted.length
  ) {
    return null
  }
  const seen = new Set()
  const mediaItems = []
  for (const mediaId of submitted) {
    if (!Number.isInteger(mediaId) || mediaId < 1 || seen.has(mediaId)) {
      return null
    }
    const media = mockMedia.find((item) => item.id === mediaId)
    if (
      !media ||
      media.mediaType !==
        (legacy && body.mediaType === 'video' ? 'video' : 'photo')
    ) {
      return null
    }
    seen.add(mediaId)
    mediaItems.push(media)
  }
  return mediaItems
}

function skyPicMessageBody(value) {
  const body = typeof value === 'string' ? value.trim() : ''
  if (!body) return { error: 'message_empty' }
  if ([...body].length > 2000) return { error: 'message_too_long' }
  return { body }
}

function skyPicOffset(value) {
  const offset = value === undefined ? 0 : value
  return Number.isInteger(offset) && offset >= 0 && offset <= 100_000
    ? offset
    : null
}

const skyPicProfiles = [
  {
    avatarSeed: 8,
    avatarUrl: mockPhotoUrls([12])[0],
    displayName: 'Alex Morgan',
    handle: 'alexm',
    id: '10000000-0000-4000-8000-000000000001',
    snapScore: 1842,
  },
  {
    avatarSeed: 3,
    avatarUrl: mockPhotoUrls([3])[0],
    displayName: 'Maya Rivera',
    handle: 'mayar',
    id: '10000000-0000-4000-8000-000000000002',
    snapScore: 5214,
  },
  {
    avatarSeed: 11,
    avatarUrl: mockPhotoUrls([7])[0],
    displayName: 'Noah Williams',
    handle: 'noahw',
    id: '10000000-0000-4000-8000-000000000003',
    snapScore: 2940,
  },
  {
    avatarSeed: 19,
    avatarUrl: mockPhotoUrls([11])[0],
    displayName: 'Sofia Chen',
    handle: 'sofiac',
    id: '10000000-0000-4000-8000-000000000004',
    snapScore: 4091,
  },
  {
    avatarSeed: 27,
    avatarUrl: mockPhotoUrls([9])[0],
    displayName: 'Jade Brooks',
    handle: 'jadeb',
    id: '10000000-0000-4000-8000-000000000005',
    snapScore: 1678,
  },
]
const skyPicStoryReplyEnabledProfileIds = new Set([
  skyPicProfiles[1].id,
  skyPicProfiles[2].id,
  skyPicProfiles[3].id,
  skyPicProfiles[4].id,
])
let skyPicProfile = {
  ...skyPicProfiles[0],
  allowStoryReplies: true,
  avatarMediaId: 12,
  bio: 'Night drives, neon skies and the people who make the city feel small.',
  friendCount: 1,
  friendshipStatus: 'none',
  showInQuickAdd: true,
  storyPrivacy: 'friends',
}
let skyPicOnboardingProfile = null
let skyPicFriends = [
  {
    bestStreak: 18,
    createdAt: isoTime(-46 * 86_400_000),
    friendshipId: '20000000-0000-4000-8000-000000000001',
    profile: skyPicProfiles[1],
    streakCount: 7,
  },
]
let skyPicRequests = [
  {
    createdAt: isoTime(-35 * 60_000),
    direction: 'incoming',
    friendshipId: '20000000-0000-4000-8000-000000000002',
    profile: skyPicProfiles[2],
  },
  {
    createdAt: isoTime(-2 * 60 * 60_000),
    direction: 'outgoing',
    friendshipId: '20000000-0000-4000-8000-000000000003',
    profile: skyPicProfiles[4],
  },
]
let skyPicConversations = [
  {
    bestStreak: 18,
    friendshipId: '20000000-0000-4000-8000-000000000001',
    lastItem: {
      createdAt: isoTime(-4 * 60_000),
      direction: 'received',
      id: '30000000-0000-4000-8000-000000000001',
      openedAt: null,
      type: 'snap_photo',
    },
    profile: skyPicProfiles[1],
    streakCount: 7,
    unreadCount: 2,
  },
]
let skyPicSnaps = [
  {
    allowReplay: true,
    createdAt: isoTime(-4 * 60_000),
    direction: 'received',
    durationSeconds: 7,
    expiresAt: isoTime(23 * 60 * 60_000),
    friendshipId: '20000000-0000-4000-8000-000000000001',
    id: '30000000-0000-4000-8000-000000000001',
    openedAt: null,
    replayedAt: null,
    sender: skyPicProfiles[1],
    type: 'snap_photo',
  },
  {
    allowReplay: false,
    createdAt: isoTime(-48 * 60_000),
    direction: 'sent',
    durationSeconds: 5,
    expiresAt: isoTime(23 * 60 * 60_000),
    friendshipId: '20000000-0000-4000-8000-000000000001',
    id: '30000000-0000-4000-8000-000000000002',
    openedAt: isoTime(-42 * 60_000),
    replayedAt: null,
    sender: skyPicProfiles[0],
    type: 'snap_photo',
  },
]
const skyPicSnapContents = new Map([
  [
    '30000000-0000-4000-8000-000000000001',
    {
      caption: 'Meet me where the city meets the ocean.',
      mediaType: 'photo',
      mimeType: 'image/jpeg',
      overlayColor: '#24c7ff',
      textOverlay: 'Vespucci after dark',
      url: mockPhotoUrls([9])[0],
    },
  ],
  [
    '30000000-0000-4000-8000-000000000002',
    {
      caption: 'One last lap.',
      mediaType: 'photo',
      mimeType: 'image/jpeg',
      overlayColor: '#ffffff',
      textOverlay: 'Night drive',
      url: mockPhotoUrls([8])[0],
    },
  ],
])
let skyPicStories = [
  {
    author: skyPicProfiles[1],
    createdAt: isoTime(-52 * 60_000),
    durationSeconds: 7,
    expiresAt: isoTime(22 * 60 * 60_000),
    id: '40000000-0000-4000-8000-000000000001',
    isOwner: false,
    seen: false,
    viewCount: 14,
  },
  {
    author: skyPicProfiles[0],
    createdAt: isoTime(-3 * 60 * 60_000),
    durationSeconds: 5,
    expiresAt: isoTime(20 * 60 * 60_000),
    id: '40000000-0000-4000-8000-000000000002',
    isOwner: true,
    seen: true,
    viewCount: 3,
  },
]
const skyPicStoryContents = new Map([
  [
    '40000000-0000-4000-8000-000000000001',
    {
      caption: 'Blue hour.',
      mediaType: 'photo',
      mimeType: 'image/jpeg',
      overlayColor: '#24c7ff',
      textOverlay: 'Vespucci',
      url: mockPhotoUrls([7])[0],
    },
  ],
  [
    '40000000-0000-4000-8000-000000000002',
    {
      caption: 'The skyline never gets old.',
      mediaType: 'photo',
      mimeType: 'image/jpeg',
      overlayColor: '#ffffff',
      textOverlay: 'Los Santos',
      url: mockPhotoUrls([11])[0],
    },
  ],
])
const skyPicStoryViewers = new Map([
  [
    '40000000-0000-4000-8000-000000000002',
    [
      {
        ...skyPicProfiles[1],
        viewedAt: isoTime(-95 * 60_000),
      },
      {
        ...skyPicProfiles[2],
        viewedAt: isoTime(-64 * 60_000),
      },
      {
        ...skyPicProfiles[3],
        viewedAt: isoTime(-22 * 60_000),
      },
    ],
  ],
])
const skyPicMessages = new Map([
  [
    '20000000-0000-4000-8000-000000000001',
    [
      {
        body: 'That route looks unreal.',
        createdAt: isoTime(-24 * 60_000),
        direction: 'sent',
        friendshipId: '20000000-0000-4000-8000-000000000001',
        id: '50000000-0000-4000-8000-000000000001',
        readAt: isoTime(-21 * 60_000),
        savedAt: null,
        type: 'text',
      },
      {
        body: 'Wait until you see it after sunset.',
        createdAt: isoTime(-6 * 60_000),
        direction: 'received',
        friendshipId: '20000000-0000-4000-8000-000000000001',
        id: '50000000-0000-4000-8000-000000000002',
        readAt: null,
        savedAt: null,
        type: 'text',
      },
    ],
  ],
])
const skyPicBlockedProfileIds = new Set()

function skyPicFriendshipStatus(profileId) {
  if (skyPicFriends.some((friend) => friend.profile.id === profileId)) {
    return 'friends'
  }
  const request = skyPicRequests.find((item) => item.profile.id === profileId)
  return request?.direction ?? 'none'
}

function skyPicSummary(profile) {
  const friendship =
    skyPicFriends.find((friend) => friend.profile.id === profile.id) ??
    skyPicRequests.find((request) => request.profile.id === profile.id)
  return {
    ...profile,
    ...(friendship ? { friendshipId: friendship.friendshipId } : {}),
    friendshipStatus: skyPicFriendshipStatus(profile.id),
  }
}

function skyPicDiscoveryProfile(profile) {
  return skyPicSummary(profile)
}

function skyPicFriendView(friend) {
  return {
    ...friend,
    profile: skyPicSummary(friend.profile),
  }
}

function skyPicRequestView(request) {
  return {
    ...request,
    profile: skyPicSummary(request.profile),
  }
}

function skyPicSnapView(snap) {
  return {
    ...snap,
    sender: skyPicSummary(snap.sender),
  }
}

function skyPicStoryView(story) {
  return {
    ...story,
    author: skyPicSummary(story.author),
  }
}

function skyPicUnreadCount() {
  return skyPicConversations.reduce(
    (sum, conversation) => sum + Math.max(0, conversation.unreadCount),
    0,
  )
}

function skyPicIncrementOwnScore(amount = 1) {
  skyPicProfiles[0].snapScore += amount
  if (skyPicProfile) skyPicProfile.snapScore = skyPicProfiles[0].snapScore
}

function skyPicStoryVisible(story) {
  return story.isOwner || !skyPicBlockedProfileIds.has(story.author.id)
}

function skyPicBootstrap(testScenario = '') {
  if (testScenario === 'skypic-onboarding') {
    const profile = skyPicOnboardingProfile
      ? { ...skyPicOnboardingProfile }
      : null
    return {
      blockedProfiles: [],
      conversations: [],
      friends: [],
      inbox: [],
      profile,
      requests: [],
      stories: [],
      suggestions: profile
        ? skyPicProfiles
            .slice(1)
            .filter(
              (item) =>
                !skyPicBlockedProfileIds.has(item.id) &&
                skyPicFriendshipStatus(item.id) === 'none',
            )
            .map(skyPicDiscoveryProfile)
        : [],
      unreadCount: 0,
    }
  }

  if (!skyPicProfile) {
    return {
      blockedProfiles: [],
      conversations: [],
      friends: [],
      inbox: [],
      profile: null,
      requests: [],
      stories: [],
      suggestions: [],
      unreadCount: 0,
    }
  }

  return {
    blockedProfiles: skyPicProfiles
      .filter((profile) => skyPicBlockedProfileIds.has(profile.id))
      .map(skyPicSummary),
    conversations: skyPicConversations.map((conversation) => ({
      ...conversation,
      profile: skyPicSummary(conversation.profile),
    })),
    friends: skyPicFriends.map(skyPicFriendView),
    inbox: skyPicSnaps
      .filter((snap) => snap.direction === 'received')
      .map(skyPicSnapView),
    profile: skyPicProfile ? { ...skyPicProfile } : null,
    requests: skyPicRequests.map(skyPicRequestView),
    stories: skyPicStories.filter(skyPicStoryVisible).map(skyPicStoryView),
    suggestions: skyPicProfiles
      .slice(1)
      .filter(
        (item) =>
          !skyPicBlockedProfileIds.has(item.id) &&
          skyPicFriendshipStatus(item.id) === 'none',
      )
      .map(skyPicDiscoveryProfile),
    unreadCount: skyPicUnreadCount(),
  }
}

function skyPicOpenedSnap(snap) {
  const contents = skyPicSnapContents.get(snap.id)
  if (!contents) return null
  return {
    ...contents,
    allowReplay: snap.allowReplay,
    durationSeconds: snap.durationSeconds,
    expiresAt: snap.expiresAt,
    id: snap.id,
    openedAt: snap.openedAt,
    replayedAt: snap.replayedAt,
  }
}

function skyPicViewedStory(story, viewedAt) {
  const contents = skyPicStoryContents.get(story.id)
  if (!contents) return null
  const friendship = skyPicFriends.find(
    (friend) => friend.profile.id === story.author.id,
  )
  return {
    ...contents,
    author: skyPicSummary(story.author),
    canReply:
      !story.isOwner &&
      Boolean(friendship) &&
      skyPicStoryReplyEnabledProfileIds.has(story.author.id),
    durationSeconds: story.durationSeconds,
    expiresAt: story.expiresAt,
    id: story.id,
    viewedAt,
  }
}

function skyPicConversation(friendshipId) {
  return skyPicConversations.find(
    (conversation) => conversation.friendshipId === friendshipId,
  )
}

function skyPicUpdateConversation(friendshipId, lastItem) {
  const conversation = skyPicConversation(friendshipId)
  if (conversation) {
    conversation.lastItem = lastItem
    return conversation
  }
  const friend = skyPicFriends.find(
    (item) => item.friendshipId === friendshipId,
  )
  if (!friend) return null
  const created = {
    bestStreak: friend.bestStreak,
    friendshipId,
    lastItem,
    profile: friend.profile,
    streakCount: friend.streakCount,
    unreadCount: 0,
  }
  skyPicConversations.unshift(created)
  return created
}

const weazelNewsCategoryIds = ['official', 'events', 'jobs', 'news', 'business']
const weazelNewsMaxImages = 6
let weazelNewsSequence = 8
let weazelNewsArticles = [
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000001',
    title: 'Port Authority announces temporary harbor restrictions',
    body: 'The Port Authority has announced temporary navigation restrictions around the southern harbor while maintenance crews inspect the main shipping channel. Commercial operators should follow marked diversion routes and expect short delays through the afternoon. Emergency traffic will continue without interruption.',
    excerpt:
      'Temporary navigation restrictions are in effect around the southern harbor while crews inspect the main shipping channel.',
    category: 'official',
    images: weazelNewsImages([15, 13, 20]),
    authorName: 'Avery Brooks',
    createdAt: Date.now() - 35 * 60 * 1000,
    updatedAt: Date.now() - 28 * 60 * 1000,
    publishedAt: Date.now() - 30 * 60 * 1000,
    status: 'published',
    revision: 2,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000002',
    title: 'Vinewood summer festival opens this weekend',
    body: "Vinewood Boulevard will welcome food stands, live performers, and classic cars during this weekend's summer festival. Organizers recommend using public parking near the eastern entrance and arriving early for the evening concert. The event is free and runs from noon until late.",
    excerpt:
      'Food stands, live performers, and classic cars are coming to Vinewood Boulevard this weekend.',
    category: 'events',
    images: weazelNewsImages([11]),
    authorName: 'Maya Chen',
    createdAt: Date.now() - 2 * 60 * 60 * 1000,
    updatedAt: Date.now() - 2 * 60 * 60 * 1000,
    publishedAt: Date.now() - 2 * 60 * 60 * 1000,
    status: 'published',
    revision: 1,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000003',
    title: 'City services expand recruitment drive',
    body: 'Several city departments have opened a coordinated recruitment drive for new staff. Positions are available across emergency response, transport, and public administration. Applicants should review individual department requirements before attending the recruitment office at City Hall.',
    excerpt:
      'City departments are recruiting new staff across emergency response, transport, and public administration.',
    category: 'jobs',
    images: [],
    authorName: 'Jordan Hayes',
    createdAt: Date.now() - 4 * 60 * 60 * 1000,
    updatedAt: Date.now() - 3 * 60 * 60 * 1000,
    publishedAt: Date.now() - 3 * 60 * 60 * 1000,
    status: 'published',
    revision: 2,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000004',
    title: 'Traffic returns to normal after Del Perro closure',
    body: 'Traffic is moving normally again through Del Perro after crews cleared an earlier road obstruction. Police have reopened every lane and removed the temporary diversion signs. Drivers may still encounter brief congestion while the remaining queue disperses.',
    excerpt:
      'Every lane through Del Perro has reopened after crews cleared an earlier road obstruction.',
    category: 'news',
    images: weazelNewsImages([9]),
    authorName: 'Avery Brooks',
    createdAt: Date.now() - 7 * 60 * 60 * 1000,
    updatedAt: Date.now() - 6 * 60 * 60 * 1000,
    publishedAt: Date.now() - 6 * 60 * 60 * 1000,
    status: 'published',
    revision: 3,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000005',
    title: 'Downtown retailers report strong evening trade',
    body: 'Independent retailers across downtown Los Santos reported stronger evening trade following the launch of extended opening hours. Business owners credited increased foot traffic and a busy restaurant district. The trial will continue through the end of the month before a permanent schedule is considered.',
    excerpt:
      'Independent downtown retailers are seeing stronger evening trade during a trial of extended opening hours.',
    category: 'business',
    images: weazelNewsImages([5]),
    authorName: 'Maya Chen',
    createdAt: Date.now() - 26 * 60 * 60 * 1000,
    updatedAt: Date.now() - 25 * 60 * 60 * 1000,
    publishedAt: Date.now() - 25 * 60 * 60 * 1000,
    status: 'published',
    revision: 2,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000006',
    title: 'Interview: preparing for the next racing season',
    body: 'Local racing teams are preparing new vehicles and reviewing safety procedures before the next sanctioned season begins. Weazel News spoke with organizers about the revised technical checks, route planning, and what spectators can expect at the opening round.',
    excerpt:
      'Local racing teams are preparing vehicles and reviewing safety procedures for the next sanctioned season.',
    category: 'events',
    images: weazelNewsImages([3, 7]),
    authorName: 'Jordan Hayes',
    createdAt: Date.now() - 55 * 60 * 1000,
    updatedAt: Date.now() - 12 * 60 * 1000,
    publishedAt: null,
    status: 'draft',
    revision: 4,
  },
  {
    id: '34c0ec54-bfb1-4ad7-81da-000000000007',
    title: 'Draft briefing for Monday morning',
    body: 'The editorial desk is collecting confirmed service notices and transport updates for Monday morning. This working draft will be expanded when the final statements arrive from the relevant city departments.',
    excerpt:
      'The editorial desk is collecting confirmed service notices and transport updates for Monday morning.',
    category: 'official',
    images: [],
    authorName: 'Jordan Hayes',
    createdAt: Date.now() - 18 * 60 * 1000,
    updatedAt: Date.now() - 8 * 60 * 1000,
    publishedAt: null,
    status: 'draft',
    revision: 2,
  },
].map(syncWeazelNewsArticleImages)

function weazelNewsExcerpt(body) {
  const normalized = body.replace(/\s+/g, ' ').trim()
  return normalized.length <= 240
    ? normalized
    : `${normalized.slice(0, 237).trimEnd()}...`
}

function weazelNewsImageUrl(imageMediaId) {
  if (imageMediaId === null) return null
  const media = mockMedia.find(
    (item) => item.id === imageMediaId && item.mediaType === 'photo',
  )
  return media?.url ?? null
}

function weazelNewsImages(imageMediaIds) {
  return imageMediaIds.map((mediaId) => ({
    mediaId,
    url: weazelNewsImageUrl(mediaId),
  }))
}

function syncWeazelNewsArticleImages(article) {
  const images = Array.isArray(article.images) ? article.images : []
  const firstImage = images[0] ?? null
  return {
    ...article,
    imageMediaId: firstImage?.mediaId ?? null,
    imageUrl: firstImage?.url ?? null,
    images,
  }
}

function validateWeazelNewsDraft(data) {
  const title = typeof data.title === 'string' ? data.title.trim() : ''
  const body = typeof data.body === 'string' ? data.body.trim() : ''
  const status = data.status
  const minimumTitleLength = 1
  const minimumBodyLength = 1
  if (
    Array.from(title).length < minimumTitleLength ||
    Array.from(title).length > 160 ||
    Array.from(body).length < minimumBodyLength ||
    Array.from(body).length > 12000 ||
    !weazelNewsCategoryIds.includes(data.category) ||
    !['draft', 'published'].includes(status)
  ) {
    return { error: status === 'draft' ? 'invalid_draft' : 'invalid_publish' }
  }

  const requestedImageMediaIds =
    data.imageMediaIds === undefined
      ? data.imageMediaId === null || data.imageMediaId === undefined
        ? []
        : [data.imageMediaId]
      : data.imageMediaIds
  if (
    !Array.isArray(requestedImageMediaIds) ||
    requestedImageMediaIds.length > weazelNewsMaxImages
  ) {
    return { error: 'invalid_attachment' }
  }

  const imageMediaIds = []
  const seenImageMediaIds = new Set()
  for (const requestedImageMediaId of requestedImageMediaIds) {
    const imageMediaId = Number(requestedImageMediaId)
    if (
      !Number.isSafeInteger(imageMediaId) ||
      seenImageMediaIds.has(imageMediaId) ||
      !weazelNewsImageUrl(imageMediaId)
    ) {
      return { error: 'invalid_attachment' }
    }
    seenImageMediaIds.add(imageMediaId)
    imageMediaIds.push(imageMediaId)
  }

  const images = weazelNewsImages(imageMediaIds)
  const firstImage = images[0] ?? null

  return {
    article: {
      body,
      category: data.category,
      excerpt: weazelNewsExcerpt(body),
      imageMediaId: firstImage?.mediaId ?? null,
      imageUrl: firstImage?.url ?? null,
      images,
      status,
      title,
    },
  }
}

function pageWeazelNewsArticles(items, data) {
  const offset = Math.max(0, Math.floor(Number(data.offset) || 0))
  const requestedLimit = Math.floor(Number(data.limit) || 20)
  const limit = Math.min(50, Math.max(1, requestedLimit))
  return {
    hasMore: offset + limit < items.length,
    items: items.slice(offset, offset + limit).map((article) => {
      const summary = { ...article }
      delete summary.body
      return summary
    }),
  }
}

const mockImportSources = [
  {
    id: 'media_archive',
    label: 'Media Archive',
    mediaTypes: ['photo', 'video'],
  },
  { id: 'event_cdn', label: 'Event CDN', mediaTypes: ['photo'] },
]
const mockImportMedia = [
  {
    externalId: 'archive-photo-1',
    filename: 'Vespucci Sunset.jpg',
    imported: false,
    mediaType: 'photo',
    size: 2_481_152,
    sourceId: 'media_archive',
    url: 'https://picsum.photos/seed/sky-import-1/900/1200',
  },
  {
    externalId: 'archive-photo-2',
    filename: 'Downtown Meet.jpg',
    imported: false,
    mediaType: 'photo',
    size: 3_114_205,
    sourceId: 'media_archive',
    url: 'https://picsum.photos/seed/sky-import-2/1200/900',
  },
  {
    externalId: 'archive-video-1',
    filename: 'Flower Clip.mp4',
    imported: false,
    mediaType: 'video',
    size: 8_241_152,
    sourceId: 'media_archive',
    url: 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
  },
  {
    externalId: 'event-photo-1',
    filename: 'Opening Night.jpg',
    imported: false,
    mediaType: 'photo',
    size: 1_824_331,
    sourceId: 'event_cdn',
    url: 'https://picsum.photos/seed/sky-event-1/900/1200',
  },
]
const marketplaceInquiries = [
  {
    id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    listing_id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf01',
    seller_account_id: 2,
    buyer_account_id: 1,
    seller_name: 'morgan',
    buyer_name: 'demo',
    title: 'Sultan RS in excellent condition',
    price: 185000,
    price_type: 'negotiable',
    status: 'active',
    image: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
    other_name: 'morgan',
    last_message: 'Sure, come by the Vinewood garage around 8 PM.',
    offer_id: 2,
    offer_amount: 178000,
    offer_proposer_account_id: 2,
    offer_status: 'pending',
    offer_revision: 2,
    unread: 2,
    updated_at: '2026-08-06 11:42:00',
  },
  {
    id: '4903b923-409a-437e-971f-b7a2b10e9e32',
    listing_id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf04',
    seller_account_id: 1,
    buyer_account_id: 3,
    seller_name: 'demo',
    buyer_name: 'jamie',
    title: 'Complete mechanic tool set',
    price: 7800,
    price_type: 'fixed',
    status: 'active',
    image: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
    other_name: 'jamie',
    last_message: 'I can collect it today and pay the full price.',
    offer_id: 3,
    offer_amount: 7000,
    offer_proposer_account_id: 3,
    offer_status: 'pending',
    offer_revision: 1,
    unread: 3,
    updated_at: '2026-08-06 11:55:00',
  },
]
const marketplaceMessages = [
  {
    id: 1,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    sender_account_id: 1,
    body: 'Hi, is the Sultan still available?',
    created_at: '2026-08-06 11:35:00',
    read_at: '2026-08-06 11:36:00',
  },
  {
    id: 2,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    sender_account_id: 2,
    body: 'Yes, it is. You can also take it for a short test drive.',
    created_at: '2026-08-06 11:38:00',
    read_at: '2026-08-06 11:39:00',
  },
  {
    id: 3,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    sender_account_id: 2,
    body: 'Sure, come by the Vinewood garage around 8 PM.',
    created_at: '2026-08-06 11:42:00',
    read_at: null,
  },
  {
    id: 4,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e32',
    sender_account_id: 3,
    body: 'Hello, does the diagnostic equipment work with every vehicle?',
    created_at: '2026-08-06 11:51:00',
    read_at: null,
  },
  {
    id: 5,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e32',
    sender_account_id: 3,
    body: 'I can collect it today and pay the full price.',
    created_at: '2026-08-06 11:55:00',
    read_at: null,
  },
]
const marketplaceOffers = [
  {
    id: 1,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    proposer_account_id: 1,
    amount: 170000,
    status: 'countered',
    read_at: '2026-08-06 11:43:00',
    response_read_at: null,
    created_at: '2026-08-06 11:40:00',
    updated_at: '2026-08-06 11:44:00',
  },
  {
    id: 2,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e31',
    proposer_account_id: 2,
    amount: 178000,
    status: 'pending',
    read_at: null,
    response_read_at: null,
    created_at: '2026-08-06 11:44:00',
    updated_at: '2026-08-06 11:44:00',
  },
  {
    id: 3,
    inquiry_id: '4903b923-409a-437e-971f-b7a2b10e9e32',
    proposer_account_id: 3,
    amount: 7000,
    status: 'pending',
    read_at: null,
    response_read_at: null,
    created_at: '2026-08-06 11:56:00',
    updated_at: '2026-08-06 11:56:00',
  },
]
const pagesPosts = [
  {
    id: 'pages-citymarkt-1',
    account_id: 2,
    author_name: 'morgan',
    source_type: 'citymarkt',
    citymarkt_listing_id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf01',
    title: 'Sultan RS in excellent condition',
    body: 'Clean Sultan RS with fresh service, tidy interior and no known damage. Viewing and test drive available in Vinewood.',
    category: 'citymarkt',
    district: 'vinewood',
    created_at: Date.parse('2026-08-06T12:50:00Z'),
    like_count: 24,
    images: [
      {
        media_id: 'capture-car',
        gradient: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
        sort_order: 1,
      },
    ],
  },
  {
    id: 'pages-1',
    account_id: 2,
    author_name: 'morgan',
    source_type: 'personal',
    citymarkt_listing_id: null,
    title: 'Best sunset view above Vinewood',
    body: 'Take the small trail behind the observatory shortly before sunset. The view across Los Santos is incredible and there is enough space to park two cars.',
    category: 'recommendation',
    district: 'vinewood',
    created_at: Date.parse('2026-08-06T12:20:00Z'),
    like_count: 18,
    images: [
      {
        media_id: 'sunset-drive',
        gradient: 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
        sort_order: 1,
      },
    ],
  },
  {
    id: 'pages-2',
    account_id: 1,
    author_name: 'demo',
    source_type: 'personal',
    citymarkt_listing_id: null,
    title: 'Looking for people for a beach cruise',
    body: 'Meeting at Vespucci Pier tonight. Bring a clean car and a good playlist. Everyone is welcome.',
    category: 'community',
    district: 'vespucci',
    created_at: Date.parse('2026-08-06T11:10:00Z'),
    like_count: 7,
    images: [
      {
        media_id: 'ocean-air',
        gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
        sort_order: 1,
      },
    ],
  },
  {
    id: 'pages-3',
    account_id: 3,
    author_name: 'jamie',
    source_type: 'personal',
    citymarkt_listing_id: null,
    title: 'Mobile repair help around Sandy Shores',
    body: 'I can help with small repairs and jump starts around Sandy Shores this afternoon. Send me a message when you see me nearby.',
    category: 'service',
    district: 'sandy_shores',
    created_at: Date.parse('2026-08-05T19:40:00Z'),
    like_count: 12,
    images: [],
  },
]
const cityMarktSharedScenarioPost = {
  id: 'pages-citymarkt-owner-demo',
  account_id: 1,
  author_name: 'demo',
  source_type: 'citymarkt',
  citymarkt_listing_id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf04',
  title: 'Complete mechanic tool set',
  body: 'Complete mechanic tool set with trolley, sockets and diagnostic equipment. Everything is clean and ready for work.',
  category: 'citymarkt',
  district: 'south_los_santos',
  created_at: Date.parse('2026-08-06T13:10:00Z'),
  like_count: 4,
  images: [
    {
      media_id: 'capture-tools',
      gradient: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
      sort_order: 1,
    },
  ],
}

function pagesPostsForScenario(testScenario) {
  return testScenario === 'citymarkt-shared'
    ? [cityMarktSharedScenarioPost, ...pagesPosts]
    : pagesPosts
}
const pagesReactions = [
  { post_id: 'pages-1', account_id: 1, kind: 'like' },
  { post_id: 'pages-3', account_id: 1, kind: 'save' },
]
let pagesProfile = {
  avatar_media_id: null,
  avatar_url: null,
  bio: 'Vinewood tips and city stories.',
  email: 'demo@ifruit.com',
  exists: true,
  handle: 'demo',
}
let pagesOnboardingCompleted = false

function pageView(post) {
  const listing = marketplaceListings.find(
    (item) => item.id === post.citymarkt_listing_id,
  )
  return {
    ...post,
    author_avatar: post.account_id === 1 ? pagesProfile.avatar_url : null,
    citymarkt_price: listing?.price ?? null,
    image: post.images[0]?.gradient ?? null,
    is_liked: pagesReactions.some(
      (item) =>
        item.post_id === post.id &&
        item.account_id === 1 &&
        item.kind === 'like',
    ),
    is_owner: authenticated && post.account_id === 1,
    is_saved: pagesReactions.some(
      (item) =>
        item.post_id === post.id &&
        item.account_id === 1 &&
        item.kind === 'save',
    ),
  }
}

function counts() {
  return {
    drafts: draft ? 1 : 0,
    inbox: messages.filter(
      (item) => item.folder === 'inbox' && !item.mailbox_id && !item.trashed_at,
    ).length,
    sent: messages.filter(
      (item) => item.folder === 'sent' && !item.mailbox_id && !item.trashed_at,
    ).length,
    trash: messages.filter((item) => item.trashed_at).length,
    unread: messages.filter(
      (item) =>
        item.folder === 'inbox' &&
        !item.mailbox_id &&
        !item.trashed_at &&
        !item.is_read,
    ).length,
  }
}

function mailboxViews() {
  return mockMailboxes.map((mailbox) => ({
    ...mailbox,
    count: messages.filter(
      (message) => message.mailbox_id === mailbox.id && !message.trashed_at,
    ).length,
  }))
}

let flareProfile = {
  id: 1,
  name: 'Alex',
  age: 27,
  bio: 'Late-night drives, good coffee, and plans that turn into stories.',
  gender: 'nonbinary',
  interestedIn: 'everyone',
  minAge: 21,
  maxAge: 39,
  avatar: 5,
  interests: ['Night drives', 'Music', 'Coffee'],
  lookingFor: 'dates',
  discoverable: true,
  photoMediaIds: [1, 3],
  photoUrls: mockPhotoUrls([1, 3]),
}
let flareSuggestions = [
  {
    id: 11,
    name: 'Maya',
    age: 26,
    bio: 'Ocean air, rooftop sunsets and always up for finding the best tacos in the city.',
    gender: 'woman',
    avatar: 0,
    interests: ['Beach days', 'Food spots', 'Art'],
    lookingFor: 'longTerm',
    photoUrls: mockPhotoUrls([3, 7]),
  },
  {
    id: 12,
    name: 'Noah',
    age: 29,
    bio: 'Architect by day, terrible karaoke singer by night.',
    gender: 'man',
    avatar: 1,
    interests: ['Architecture', 'Karaoke', 'Travel'],
    lookingFor: 'dates',
    photoUrls: mockPhotoUrls([4, 11]),
  },
  {
    id: 13,
    name: 'Sofia',
    age: 25,
    bio: 'Tell me your favorite hidden corner of Los Santos.',
    gender: 'woman',
    avatar: 2,
    interests: ['Coffee', 'Photography', 'Dogs'],
    lookingFor: 'friends',
    photoUrls: mockPhotoUrls([5, 9]),
  },
  {
    id: 14,
    name: 'Leo',
    age: 28,
    bio: 'Desert roads, classic cars and a playlist for every mood.',
    gender: 'man',
    avatar: 3,
    interests: ['Cars', 'Road trips', 'Vinyl'],
    lookingFor: 'longTerm',
    photoUrls: mockPhotoUrls([8, 13]),
  },
  {
    id: 15,
    name: 'Jade',
    age: 24,
    bio: 'Usually somewhere near the water with an iced coffee.',
    gender: 'woman',
    avatar: 4,
    interests: ['Sailing', 'Fitness', 'Brunch'],
    lookingFor: 'dates',
    photoUrls: mockPhotoUrls([12, 14]),
  },
]
const flareSuggestionFixtures = flareSuggestions.map((profile) => ({
  ...profile,
  interests: [...profile.interests],
  photoUrls: [...profile.photoUrls],
}))
const flareMatches = [
  {
    id: 'flare-match-demo-0000-0000-0000000001',
    profile: {
      id: 16,
      name: 'Marcus',
      age: 30,
      bio: 'Live music and late dinners.',
      gender: 'man',
      avatar: 5,
      interests: ['Live music', 'Cooking'],
      lookingFor: 'dates',
      photoUrls: mockPhotoUrls([15, 16]),
    },
    lastMessage: 'Friday night jazz',
    lastMessageAt: isoTime(-18 * 60 * 1000),
    lastMessageType: 'share',
    unread: 1,
  },
]
let flareLikes = [{ ...flareSuggestions[0], superLiked: true }]
let flareLastSwipe = null
const flareMessages = {
  'flare-match-demo-0000-0000-0000000001': [
    {
      id: 'flare-message-1',
      direction: 'sent',
      body: 'Have you tried the little jazz bar in Vinewood?',
      createdAt: isoTime(-55 * 60 * 1000),
      mediaDurationMs: null,
      mediaUrl: null,
      messageType: 'text',
    },
    {
      id: 'flare-message-2',
      direction: 'received',
      body: 'That place sounds perfect. Friday?',
      createdAt: isoTime(-38 * 60 * 1000),
      mediaDurationMs: null,
      mediaUrl: null,
      messageType: 'text',
    },
    {
      id: 'flare-message-3',
      direction: 'received',
      body: 'Friday night jazz',
      createdAt: isoTime(-18 * 60 * 1000),
      mediaDurationMs: null,
      mediaUrl: null,
      messageType: 'share',
      sharePayload: {
        appId: 'music',
        copyText: 'A late-night playlist for the drive to Vinewood.',
        id: 'music-playlist-friday-jazz',
        imageUrl: 'https://picsum.photos/seed/easyshare-jazz/720/720',
        kind: 'playlist',
        link: 'skyphone://music/playlist/music-playlist-friday-jazz',
        subtitle: '12 tracks · 48 min',
        title: 'Friday night jazz',
      },
    },
  ],
}

function flareBootstrap() {
  const hasProfile = Boolean(flareProfile)
  return {
    profile: flareProfile,
    suggestions:
      hasProfile && flareProfile.discoverable ? flareSuggestions : [],
    likes: hasProfile ? flareLikes : [],
    matches: hasProfile ? flareMatches : [],
  }
}

function freshFlareSuggestions() {
  return flareSuggestionFixtures.map((profile) => ({
    ...profile,
    interests: [...profile.interests],
    photoUrls: [...profile.photoUrls],
  }))
}

function flarePhotoRemovalWouldEmptyProfile(mediaIds) {
  if (!flareProfile || !Array.isArray(flareProfile.photoMediaIds)) {
    return false
  }
  const currentIds = flareProfile.photoMediaIds
  const removedIds = new Set(mediaIds)
  return (
    currentIds.length > 0 &&
    currentIds.some((id) => removedIds.has(id)) &&
    currentIds.every((id) => removedIds.has(id))
  )
}

function removeFlareProfilePhotos(mediaIds) {
  if (!flareProfile || !Array.isArray(flareProfile.photoMediaIds)) return
  const removedIds = new Set(mediaIds)
  const photoMediaIds = []
  const photoUrls = []
  flareProfile.photoMediaIds.forEach((id, index) => {
    if (removedIds.has(id)) return
    photoMediaIds.push(id)
    photoUrls.push(flareProfile.photoUrls[index])
  })
  flareProfile = {
    ...flareProfile,
    photoMediaIds,
    photoUrls,
  }
}

const companyCategories = [
  { id: 'public_services', name: 'Public Services' },
  { id: 'medical', name: 'Medical' },
  { id: 'mechanics', name: 'Mechanics' },
  { id: 'transport', name: 'Transport' },
  { id: 'gastronomy', name: 'Food & Drink' },
]
let companyCallAvailable = false
const companyProfiles = [
  {
    acceptsRequests: false,
    announcement: {
      body: 'Community traffic unit active around Legion Square.',
      expiresAt: isoTime(6 * 60 * 60 * 1000),
      publishedAt: isoTime(-35 * 60 * 1000),
    },
    availability: 'available',
    availabilityUpdatedAt: isoTime(-12 * 60 * 1000),
    canCall: true,
    canMessage: false,
    categoryId: 'public_services',
    categoryName: 'Public Services',
    coverUrl: 'https://picsum.photos/seed/companies-police-cover/900/360',
    description:
      'Public safety, non-emergency assistance, and community response for Los Santos.',
    hours: [],
    id: 'police',
    location: {
      address: 'Sinner Street',
      coords: { x: 441.2, y: -981.9, z: 30.7 },
      district: 'Mission Row',
      label: 'Mission Row Police Station',
    },
    logoUrl: 'https://picsum.photos/seed/companies-police-logo/180/180',
    name: 'Los Santos Police',
    phoneNumber: '911',
    revision: 3,
    services: [
      {
        acceptsRequests: false,
        active: true,
        description: 'Immediate police response through the service line.',
        id: 'emergency-response',
        priceText: null,
        title: 'Emergency Response',
      },
      {
        acceptsRequests: false,
        active: true,
        description: 'General information and non-emergency assistance.',
        id: 'public-assistance',
        priceText: null,
        title: 'Public Assistance',
      },
    ],
    serviceSummary: 'Emergency response and public assistance',
    verified: true,
  },
  {
    acceptsRequests: false,
    announcement: null,
    availability: 'busy',
    availabilityUpdatedAt: isoTime(-22 * 60 * 1000),
    canCall: true,
    canMessage: false,
    categoryId: 'medical',
    categoryName: 'Medical',
    coverUrl: 'https://picsum.photos/seed/companies-ems-cover/900/360',
    description:
      'Emergency medical response and patient care across Los Santos County.',
    hours: [],
    id: 'ambulance',
    location: {
      address: 'Elgin Avenue',
      coords: { x: 298.4, y: -584.6, z: 43.3 },
      district: 'Pillbox Hill',
      label: 'Pillbox Medical Center',
    },
    logoUrl: 'https://picsum.photos/seed/companies-ems-logo/180/180',
    name: 'Los Santos Medical',
    phoneNumber: '912',
    revision: 1,
    services: [
      {
        acceptsRequests: false,
        active: true,
        description: 'Urgent medical assistance through the service line.',
        id: 'medical-response',
        priceText: null,
        title: 'Medical Response',
      },
    ],
    serviceSummary: 'Emergency medical care',
    verified: true,
  },
  {
    acceptsRequests: true,
    announcement: {
      body: 'Same-day repairs available until 10 PM.',
      expiresAt: isoTime(10 * 60 * 60 * 1000),
      publishedAt: isoTime(-48 * 60 * 1000),
    },
    availability: 'available',
    availabilityUpdatedAt: isoTime(-6 * 60 * 1000),
    canCall: true,
    canMessage: true,
    categoryId: 'mechanics',
    categoryName: 'Mechanics',
    coverUrl: 'https://picsum.photos/seed/companies-bennys-cover/900/360',
    description:
      'Repairs, roadside assistance, performance upgrades, and custom bodywork.',
    hours: [
      { closesAt: '22:00', day: 0, isClosed: false, opensAt: '10:00' },
      { closesAt: '22:00', day: 1, isClosed: false, opensAt: '10:00' },
      { closesAt: '22:00', day: 2, isClosed: false, opensAt: '10:00' },
      { closesAt: '22:00', day: 3, isClosed: false, opensAt: '10:00' },
      { closesAt: '23:30', day: 4, isClosed: false, opensAt: '10:00' },
      { closesAt: '23:30', day: 5, isClosed: false, opensAt: '12:00' },
      { closesAt: null, day: 6, isClosed: true, opensAt: null },
    ],
    id: 'bennys',
    location: {
      address: 'Alta Street',
      coords: { x: -211.6, y: -1324.2, z: 30.9 },
      district: 'Strawberry',
      label: "Benny's Original Motor Works",
    },
    logoUrl: 'https://picsum.photos/seed/companies-bennys-logo/180/180',
    name: "Benny's Motor Works",
    phoneNumber: '5550102',
    revision: 7,
    services: [
      {
        acceptsRequests: true,
        active: true,
        description: 'Diagnostics and general mechanical repairs.',
        id: 'repair',
        priceText: 'from $250',
        title: 'Vehicle Repair',
      },
      {
        acceptsRequests: true,
        active: true,
        description: 'Mobile help for disabled vehicles.',
        id: 'roadside',
        priceText: 'from $175',
        title: 'Roadside Assistance',
      },
      {
        acceptsRequests: true,
        active: true,
        description: 'Paint, wheels, and body modifications.',
        id: 'customization',
        priceText: 'Quote',
        title: 'Customization',
      },
    ],
    serviceSummary: 'Repairs, roadside help, and customization',
    verified: true,
  },
  {
    acceptsRequests: true,
    announcement: null,
    availability: 'available',
    availabilityUpdatedAt: isoTime(-19 * 60 * 1000),
    canCall: true,
    canMessage: true,
    categoryId: 'transport',
    categoryName: 'Transport',
    coverUrl: 'https://picsum.photos/seed/companies-taxi-cover/900/360',
    description: 'Citywide passenger transport and pre-arranged group rides.',
    hours: [],
    id: 'downtown-cab',
    location: {
      address: 'Tangerine Street',
      coords: { x: 900.3, y: -170.2, z: 74.1 },
      district: 'East Vinewood',
      label: 'Downtown Cab Co.',
    },
    logoUrl: 'https://picsum.photos/seed/companies-taxi-logo/180/180',
    name: 'Downtown Cab Co.',
    phoneNumber: '5550103',
    revision: 2,
    services: [
      {
        acceptsRequests: true,
        active: true,
        description: 'A driver will collect you at your location.',
        id: 'pickup',
        priceText: 'Metered',
        title: 'Passenger Pickup',
      },
    ],
    serviceSummary: 'Passenger pickups throughout the city',
    verified: true,
  },
  {
    acceptsRequests: true,
    announcement: null,
    availability: 'closed',
    availabilityUpdatedAt: isoTime(-3 * 60 * 60 * 1000),
    canCall: true,
    canMessage: true,
    categoryId: 'gastronomy',
    categoryName: 'Food & Drink',
    coverUrl: 'https://picsum.photos/seed/companies-burgershot-cover/900/360',
    description: 'Burgers, fries, shakes, and late-night catering.',
    hours: [],
    id: 'burgershot',
    location: {
      address: 'San Andreas Avenue',
      coords: { x: -1193.8, y: -892.5, z: 14 },
      district: 'Vespucci',
      label: 'Burger Shot',
    },
    logoUrl: 'https://picsum.photos/seed/companies-burgershot-logo/180/180',
    name: 'Burger Shot',
    phoneNumber: '5550104',
    revision: 1,
    services: [
      {
        acceptsRequests: true,
        active: true,
        description: 'Food order for collection at the restaurant.',
        id: 'catering',
        priceText: 'Quote',
        title: 'Event Catering',
      },
    ],
    serviceSummary: 'Food, drinks, and event catering',
    verified: true,
  },
]

let companyRequestSequence = 4
let companyRequests = [
  {
    actions: {
      allowedStatuses: ['in_progress', 'waiting_customer', 'completed'],
      canAssign: true,
      canCall: true,
      canCancel: true,
      canClaim: false,
      canReply: true,
    },
    assignedLabel: 'you',
    companyId: 'bennys',
    companyLogoUrl: companyProfiles[2].logoUrl,
    companyName: companyProfiles[2].name,
    createdAt: isoTime(-2 * 60 * 60 * 1000),
    description:
      'My Sultan stopped near Legion Square and the engine will not start.',
    events: [
      {
        createdAt: isoTime(-2 * 60 * 60 * 1000),
        id: 'company-event-1',
        status: 'new',
        type: 'created',
      },
      {
        createdAt: isoTime(-95 * 60 * 1000),
        id: 'company-event-2',
        status: 'assigned',
        type: 'assigned',
      },
      {
        createdAt: isoTime(-80 * 60 * 1000),
        id: 'company-event-3',
        status: 'in_progress',
        type: 'status_changed',
      },
    ],
    id: 'company-request-1',
    media: [
      {
        id: 3,
        url: 'https://picsum.photos/seed/sky-phone-3/800/600',
      },
      {
        id: 4,
        url: 'https://picsum.photos/seed/sky-phone-4/800/600',
      },
    ],
    messages: [
      {
        author: 'customer',
        authorLabel: 'you',
        body: 'I am parked on the north side of the square.',
        createdAt: isoTime(-110 * 60 * 1000),
        id: 'company-message-1',
        isMine: true,
      },
      {
        author: 'company',
        authorLabel: 'company',
        body: 'A mechanic is heading your way. Please stay near the vehicle.',
        createdAt: isoTime(-78 * 60 * 1000),
        id: 'company-message-2',
        isMine: false,
      },
    ],
    phoneNumber: companyProfiles[2].phoneNumber,
    revision: 3,
    serviceId: 'roadside',
    serviceName: 'Roadside Assistance',
    status: 'in_progress',
    subject: 'Vehicle will not start',
    unreadCount: 1,
    updatedAt: isoTime(-78 * 60 * 1000),
  },
  {
    actions: {
      allowedStatuses: ['assigned', 'cancelled'],
      canAssign: true,
      canCall: true,
      canCancel: true,
      canClaim: true,
      canReply: true,
    },
    assignedLabel: null,
    companyId: 'bennys',
    companyLogoUrl: companyProfiles[2].logoUrl,
    companyName: companyProfiles[2].name,
    createdAt: isoTime(-18 * 60 * 1000),
    description:
      'I would like a quote for a metallic blue repaint and new wheels.',
    events: [
      {
        createdAt: isoTime(-18 * 60 * 1000),
        id: 'company-event-4',
        status: 'new',
        type: 'created',
      },
    ],
    id: 'company-request-2',
    media: [],
    messages: [],
    phoneNumber: companyProfiles[2].phoneNumber,
    revision: 1,
    serviceId: 'customization',
    serviceName: 'Customization',
    status: 'new',
    subject: 'Repaint and wheels',
    unreadCount: 0,
    updatedAt: isoTime(-18 * 60 * 1000),
  },
  {
    actions: {
      allowedStatuses: [],
      canAssign: false,
      canCall: true,
      canCancel: false,
      canClaim: false,
      canReply: false,
    },
    assignedLabel: 'assigned',
    companyId: 'bennys',
    companyLogoUrl: companyProfiles[2].logoUrl,
    companyName: companyProfiles[2].name,
    createdAt: isoTime(-2 * 24 * 60 * 60 * 1000),
    description: 'Routine engine service and fluids.',
    events: [
      {
        createdAt: isoTime(-2 * 24 * 60 * 60 * 1000),
        id: 'company-event-5',
        status: 'new',
        type: 'created',
      },
      {
        createdAt: isoTime(-26 * 60 * 60 * 1000),
        id: 'company-event-6',
        status: 'completed',
        type: 'completed',
      },
    ],
    id: 'company-request-3',
    media: [],
    messages: [],
    phoneNumber: companyProfiles[2].phoneNumber,
    revision: 4,
    serviceId: 'repair',
    serviceName: 'Vehicle Repair',
    status: 'completed',
    subject: 'Routine service',
    unreadCount: 0,
    updatedAt: isoTime(-26 * 60 * 60 * 1000),
  },
]

const companyMembers = [
  { id: 'member-mia', name: 'Mia Torres', online: true, role: 'Mechanic' },
  { id: 'member-jay', name: 'Jay Coleman', online: true, role: 'Tow Operator' },
  { id: 'member-robin', name: '', online: false, role: 'Mechanic' },
]

function companySummary(company) {
  const { coverUrl, hours, revision, services, ...summary } = company
  return {
    ...summary,
    serviceSummary:
      company.serviceSummary ??
      services.map((service) => service.title).join(', '),
  }
}

function companyRequestSummary(request) {
  const {
    actions,
    description,
    events,
    media,
    messages,
    phoneNumber,
    revision,
    ...summary
  } = request
  return summary
}

function companyWorkContext(testScenario = '') {
  if (testScenario === 'companies-unauthorized') {
    return {
      authorized: false,
      callAvailable: false,
      company: null,
      metrics: { assigned: 0, completedToday: 0, new: 0, waiting: 0 },
      ownRequests: [],
      permissions: {
        canAssign: false,
        canManageAnnouncement: false,
        canManageHours: false,
        canManageProfile: false,
        canManageServices: false,
        canSetAvailability: false,
        canTakeCalls: false,
      },
      recentRequests: [],
      role: null,
      unreadCount: 0,
    }
  }
  const manager = testScenario === 'companies-manager'
  const open = companyRequests.filter(
    (request) =>
      request.companyId === 'bennys' &&
      !['completed', 'cancelled'].includes(request.status),
  )
  return {
    authorized: true,
    callAvailable: companyCallAvailable,
    company: companyProfiles.find((company) => company.id === 'bennys'),
    metrics: {
      assigned: open.filter((request) => request.assignedLabel).length,
      completedToday: companyRequests.filter(
        (request) =>
          request.companyId === 'bennys' && request.status === 'completed',
      ).length,
      new: open.filter((request) => request.status === 'new').length,
      waiting: open.filter((request) => request.status === 'waiting_customer')
        .length,
    },
    ownRequests: open
      .filter((request) => request.assignedLabel)
      .map(companyRequestSummary),
    permissions: {
      canAssign: manager,
      canManageAnnouncement: manager,
      canManageHours: manager,
      canManageProfile: manager,
      canManageServices: manager,
      canSetAvailability: true,
      canTakeCalls: true,
    },
    recentRequests: open.slice(0, 4).map(companyRequestSummary),
    role: manager ? 'manager' : 'employee',
    unreadCount: open.reduce(
      (total, request) => total + request.unreadCount,
      0,
    ),
  }
}

app.post('/api/:endpoint', async (request, response, next) => {
  const endpoint = request.params.endpoint
  const loggedBody = { ...request.body }
  if (typeof loggedBody.password === 'string')
    loggedBody.password = '<redacted>'
  if (endpoint === 'memos:devCapture') {
    loggedBody.audioDataUrl = `<${String(request.body.audioDataUrl ?? '').length} characters>`
  }
  console.log(`[NUI] ${endpoint}`, loggedBody)
  if (endpoint === 'music:bootstrap') {
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:add-youtube') {
    const value = String(request.body.url ?? '')
    const customTitle = String(request.body.title ?? '').trim()
    const customArtist = String(request.body.artist ?? '').trim()
    const videoId =
      value.match(/[?&]v=([\w-]{11})/)?.[1] ??
      value.match(/youtu\.be\/([\w-]{11})/)?.[1]
    if (!videoId) {
      response.json({ success: false, error: 'invalid_youtube_url' })
      return
    }
    if (customTitle.length > 160 || customArtist.length > 120) {
      response.json({ success: false, error: 'invalid_song_metadata' })
      return
    }
    if (musicYoutubeTracks.some((track) => track.videoId === videoId)) {
      response.json({ success: false, error: 'song_exists' })
      return
    }
    const metadata =
      !customTitle || !customArtist ? await fetchYoutubeMetadata(videoId) : null
    musicYoutubeTracks.unshift({
      id: `music-youtube-${musicSequence++}`,
      source: 'youtube',
      videoId,
      title: customTitle || metadata?.title || `YouTube ${videoId}`,
      artist: customArtist || metadata?.artist || 'YouTube',
      artwork: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
      createdAt: Date.now(),
    })
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:remove-youtube') {
    musicYoutubeTracks = musicYoutubeTracks.filter(
      (track) => track.id !== request.body.id,
    )
    musicPlaylists.forEach((playlist) => {
      playlist.entries = playlist.entries.filter(
        (entry) =>
          !(entry.source === 'youtube' && entry.songId === request.body.id),
      )
    })
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:create-playlist') {
    const name = String(request.body.name ?? '').trim()
    if (!name) {
      response.json({ success: false, error: 'invalid_playlist' })
      return
    }
    musicPlaylists.unshift({
      id: `music-playlist-${musicSequence++}`,
      name,
      createdAt: Date.now(),
      entries: [],
    })
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:rename-playlist') {
    const playlist = musicPlaylists.find((item) => item.id === request.body.id)
    if (!playlist) {
      response.json({ success: false, error: 'playlist_not_found' })
      return
    }
    playlist.name = String(request.body.name ?? '').trim()
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:delete-playlist') {
    musicPlaylists = musicPlaylists.filter(
      (playlist) => playlist.id !== request.body.id,
    )
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:add-to-playlist') {
    const playlist = musicPlaylists.find(
      (item) => item.id === request.body.playlistId,
    )
    if (!playlist) {
      response.json({ success: false, error: 'playlist_not_found' })
      return
    }
    if (
      playlist.entries.some(
        (entry) =>
          entry.source === request.body.source &&
          entry.songId === request.body.songId,
      )
    ) {
      response.json({
        success: false,
        error: 'song_already_in_playlist',
      })
      return
    }
    playlist.entries.push({
      source: request.body.source,
      songId: request.body.songId,
    })
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  if (endpoint === 'music:remove-from-playlist') {
    const playlist = musicPlaylists.find(
      (item) => item.id === request.body.playlistId,
    )
    if (playlist) {
      playlist.entries = playlist.entries.filter(
        (entry) =>
          entry.source !== request.body.source ||
          entry.songId !== request.body.songId,
      )
    }
    response.json({ success: true, data: musicBootstrap() })
    return
  }
  next()
})

const featherProfiles = [
  {
    id: 1,
    handle: 'alexmorgan',
    display_name: 'Alex Morgan',
    bio: 'City stories, night drives and good coffee.',
    avatar_url: 'https://picsum.photos/seed/feather-alex/160/160',
    verified: false,
    is_owner: true,
    is_following: false,
    followers: 128,
    following: 84,
    post_count: 2,
  },
  {
    id: 2,
    handle: 'lsdaily',
    display_name: 'Los Santos Daily',
    bio: 'Independent updates from across the city.',
    avatar_url: 'https://picsum.photos/seed/feather-daily/160/160',
    verified: true,
    is_owner: false,
    is_following: true,
    followers: 12400,
    following: 92,
    post_count: 842,
  },
  {
    id: 3,
    handle: 'miasantos',
    display_name: 'Mia Santos',
    bio: 'Music, art and the west side.',
    avatar_url: 'https://picsum.photos/seed/feather-mia/160/160',
    verified: false,
    is_owner: false,
    is_following: false,
    followers: 834,
    following: 310,
    post_count: 67,
  },
  {
    id: 4,
    handle: 'bennysmotorworks',
    display_name: "Benny's Motor Works",
    bio: 'Custom builds, workshop stories and open appointments.',
    avatar_url: 'https://picsum.photos/seed/feather-bennys/160/160',
    verified: true,
    is_owner: false,
    is_following: true,
    followers: 4821,
    following: 146,
    post_count: 318,
  },
  {
    id: 5,
    handle: 'lspd',
    display_name: 'Los Santos Police Department',
    bio: 'Official public safety updates for Los Santos.',
    avatar_url: 'https://picsum.photos/seed/feather-lspd/160/160',
    verified: true,
    is_owner: false,
    is_following: false,
    followers: 31700,
    following: 41,
    post_count: 1294,
  },
  {
    id: 6,
    handle: 'nightshiftls',
    display_name: 'Night Shift LS',
    bio: 'Neon, street photography and stories after midnight.',
    avatar_url: 'https://picsum.photos/seed/feather-night/160/160',
    verified: false,
    is_owner: false,
    is_following: false,
    followers: 2140,
    following: 502,
    post_count: 154,
  },
  {
    id: 7,
    handle: 'downtowneats',
    display_name: 'Downtown Eats',
    bio: 'Finding the best food trucks, diners and late-night menus.',
    avatar_url: 'https://picsum.photos/seed/feather-food/160/160',
    verified: false,
    is_owner: false,
    is_following: true,
    followers: 7602,
    following: 288,
    post_count: 604,
  },
  {
    id: 8,
    handle: 'vinewoodsocial',
    display_name: 'Vinewood Social',
    bio: 'Events, premieres and everything happening in Vinewood.',
    avatar_url: 'https://picsum.photos/seed/feather-vinewood/160/160',
    verified: true,
    is_owner: false,
    is_following: false,
    followers: 18900,
    following: 73,
    post_count: 911,
  },
]
let featherFollowingIds = [2, 4, 7]
let featherFollowerIds = [3, 6, 8]
let featherBlockedProfileIds = []
const featherReports = []
let featherPosts = [
  {
    id: 'feather-post-1',
    profile_id: 2,
    handle: 'lsdaily',
    display_name: 'Los Santos Daily',
    verified: true,
    avatar_url: featherProfiles[1].avatar_url,
    body: 'Golden hour over Downtown. Traffic is building near Legion Square — take the eastern route if you can.',
    created_at: Date.now() - 12 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: true,
    is_liked: true,
    is_bookmarked: false,
    like_count: 241,
    reply_count: 18,
    media: [
      {
        id: 901,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-city/900/600',
      },
    ],
  },
  {
    id: 'feather-post-2',
    profile_id: 3,
    handle: 'miasantos',
    display_name: 'Mia Santos',
    verified: false,
    avatar_url: featherProfiles[2].avatar_url,
    body: 'Small reminder: the best corners of this city are the ones you find by accident. What is your favorite late-night spot?',
    created_at: Date.now() - 48 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: false,
    is_liked: false,
    is_bookmarked: true,
    like_count: 73,
    reply_count: 9,
    media: [],
  },
  {
    id: 'feather-post-3',
    profile_id: 1,
    handle: 'alexmorgan',
    display_name: 'Alex Morgan',
    verified: false,
    avatar_url: featherProfiles[0].avatar_url,
    body: 'First feather. The city feels unusually calm tonight.',
    created_at: Date.now() - 3 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: true,
    is_following: false,
    is_liked: false,
    is_bookmarked: false,
    like_count: 12,
    reply_count: 2,
    media: [],
  },
  {
    id: 'feather-post-4',
    profile_id: 4,
    handle: 'bennysmotorworks',
    display_name: "Benny's Motor Works",
    verified: true,
    avatar_url: featherProfiles[3].avatar_url,
    body: 'The Elegy is finally ready. New paint, cleaner fitment and a setup made for city nights. #Cars #Bennys',
    created_at: Date.now() - 5 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: true,
    is_liked: false,
    is_bookmarked: false,
    like_count: 812,
    reply_count: 46,
    media: [
      {
        id: 904,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-car/900/600',
      },
      {
        id: 905,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-garage/900/600',
      },
    ],
  },
  {
    id: 'feather-post-5',
    profile_id: 5,
    handle: 'lspd',
    display_name: 'Los Santos Police Department',
    verified: true,
    avatar_url: featherProfiles[4].avatar_url,
    body: 'Road closure: Power Street between Vespucci Boulevard and San Andreas Avenue. Please use an alternate route. #LosSantos #Traffic',
    created_at: Date.now() - 7 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: false,
    is_liked: false,
    is_bookmarked: true,
    like_count: 391,
    reply_count: 61,
    media: [],
  },
  {
    id: 'feather-post-6',
    profile_id: 6,
    handle: 'nightshiftls',
    display_name: 'Night Shift LS',
    verified: false,
    avatar_url: featherProfiles[5].avatar_url,
    body: 'Three quiet frames from tonight. Downtown really changes after the rain. #Photography #NightLife',
    created_at: Date.now() - 11 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: false,
    is_liked: true,
    is_bookmarked: true,
    like_count: 1540,
    reply_count: 83,
    media: [
      {
        id: 906,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-neon/900/600',
      },
      {
        id: 907,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-rain/900/600',
      },
      {
        id: 908,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-downtown/900/600',
      },
    ],
  },
  {
    id: 'feather-post-7',
    profile_id: 7,
    handle: 'downtowneats',
    display_name: 'Downtown Eats',
    verified: false,
    avatar_url: featherProfiles[6].avatar_url,
    body: 'New taco truck at Legion Square until 2 AM. The hot sauce is not joking around. #Food #LosSantos',
    created_at: Date.now() - 16 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: 'feather-post-2',
    is_owner: false,
    is_following: true,
    is_liked: false,
    is_bookmarked: false,
    like_count: 628,
    reply_count: 37,
    media: [
      {
        id: 909,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-tacos/900/600',
      },
    ],
  },
  {
    id: 'feather-post-8',
    profile_id: 8,
    handle: 'vinewoodsocial',
    display_name: 'Vinewood Social',
    verified: true,
    avatar_url: featherProfiles[7].avatar_url,
    body: 'Outdoor cinema returns to the Vinewood Bowl this weekend. Gates open at 8 PM. #Events #Vinewood',
    created_at: Date.now() - 22 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: null,
    is_owner: false,
    is_following: false,
    is_liked: false,
    is_bookmarked: false,
    like_count: 2203,
    reply_count: 104,
    media: [
      {
        id: 910,
        media_type: 'photo',
        url: 'https://picsum.photos/seed/feather-cinema/900/600',
      },
    ],
  },
  {
    id: 'feather-post-9',
    profile_id: 1,
    handle: 'alexmorgan',
    display_name: 'Alex Morgan',
    verified: false,
    avatar_url: featherProfiles[0].avatar_url,
    body: 'Traffic update for everyone heading downtown later. Drive safe.',
    created_at: Date.now() - 26 * 60 * 60 * 1000,
    reply_to_id: null,
    quote_id: 'feather-post-5',
    is_owner: true,
    is_following: false,
    is_liked: true,
    is_bookmarked: false,
    like_count: 34,
    reply_count: 4,
    media: [],
  },
  {
    id: 'feather-reply-1',
    profile_id: 1,
    handle: 'alexmorgan',
    display_name: 'Alex Morgan',
    verified: false,
    avatar_url: featherProfiles[0].avatar_url,
    body: 'Thanks for the warning. The eastern route was much faster.',
    created_at: Date.now() - 8 * 60 * 1000,
    reply_to_id: 'feather-post-1',
    quote_id: null,
    is_owner: true,
    is_following: false,
    is_liked: false,
    is_bookmarked: false,
    like_count: 5,
    reply_count: 0,
    media: [],
  },
  {
    id: 'feather-reply-2',
    profile_id: 3,
    handle: 'miasantos',
    display_name: 'Mia Santos',
    verified: false,
    avatar_url: featherProfiles[2].avatar_url,
    body: 'That skyline photo is perfect.',
    created_at: Date.now() - 5 * 60 * 1000,
    reply_to_id: 'feather-post-1',
    quote_id: null,
    is_owner: false,
    is_following: false,
    is_liked: true,
    is_bookmarked: false,
    like_count: 12,
    reply_count: 1,
    media: [],
  },
]
const featherActivities = [
  {
    id: 'feather-activity-1',
    kind: 'like',
    post_id: 'feather-post-3',
    profile_id: 3,
    handle: 'miasantos',
    display_name: 'Mia Santos',
    verified: false,
    avatar_url: featherProfiles[2].avatar_url,
    read: false,
    created_at: Date.now() - 15 * 60 * 1000,
  },
  {
    id: 'feather-activity-2',
    kind: 'follow',
    post_id: null,
    profile_id: 2,
    handle: 'lsdaily',
    display_name: 'Los Santos Daily',
    verified: true,
    avatar_url: featherProfiles[1].avatar_url,
    read: true,
    created_at: Date.now() - 90 * 60 * 1000,
  },
  {
    id: 'feather-activity-3',
    kind: 'reply',
    post_id: 'feather-post-3',
    profile_id: 4,
    handle: 'bennysmotorworks',
    display_name: "Benny's Motor Works",
    verified: true,
    avatar_url: featherProfiles[3].avatar_url,
    read: false,
    created_at: Date.now() - 2 * 60 * 60 * 1000,
  },
  {
    id: 'feather-activity-5',
    kind: 'quote',
    post_id: 'feather-post-3',
    profile_id: 6,
    handle: 'nightshiftls',
    display_name: 'Night Shift LS',
    verified: false,
    avatar_url: featherProfiles[5].avatar_url,
    read: false,
    created_at: Date.now() - 9 * 60 * 60 * 1000,
  },
]
const featherTopics = [
  { tag: '#LosSantos', count: 8421 },
  { tag: '#Cars', count: 5398 },
  { tag: '#News', count: 4127 },
  { tag: '#NightLife', count: 2944 },
  { tag: '#Food', count: 2186 },
  { tag: '#Vinewood', count: 1773 },
  { tag: '#Photography', count: 1328 },
  { tag: '#Events', count: 986 },
]
let featherOnboarded = true

const easyShareTargets = [
  { distance: 2.4, id: 41, name: 'Mia Santos' },
  { distance: 7.8, id: 72, name: 'Noah Walker' },
  { distance: 14.6, id: 105, name: 'Jamie Rivera' },
]
const easyShareHistory = [
  {
    createdAt: Date.now() - 2 * 60 * 1000,
    direction: 'incoming',
    id: 'easyshare-incoming-pending',
    otherName: 'Mia Santos',
    payload: {
      appId: 'notes',
      copyText: 'Meet at Mission Row at 20:30.',
      id: 'note-easyshare-meeting',
      kind: 'note',
      title: 'Mission Row meeting',
    },
    progress: 0,
    status: 'pending',
  },
  {
    createdAt: Date.now() - 8 * 60 * 1000,
    direction: 'outgoing',
    id: 'easyshare-outgoing-transferring',
    otherName: 'Noah Walker',
    payload: {
      appId: 'photos',
      copyText: 'Sunset over Los Santos.',
      id: 3,
      imageUrl:
        'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=900',
      kind: 'photo',
      title: 'Los Santos sunset',
    },
    progress: 58,
    status: 'transferring',
  },
  {
    createdAt: Date.now() - 22 * 60 * 1000,
    direction: 'incoming',
    id: 'easyshare-completed',
    otherName: 'Jamie Rivera',
    payload: {
      appId: 'map',
      copyText: 'Legion Square',
      kind: 'location',
      link: 'https://maps.sky/legion-square',
      title: 'Legion Square',
    },
    progress: 100,
    status: 'completed',
  },
  {
    createdAt: Date.now() - 48 * 60 * 1000,
    direction: 'outgoing',
    id: 'easyshare-accepted',
    otherName: 'Mia Santos',
    payload: {
      appId: 'music',
      copyText: 'Night Drive by Neon Coast',
      kind: 'track',
      title: 'Night Drive',
    },
    progress: 15,
    status: 'accepted',
  },
  {
    createdAt: Date.now() - 2 * 60 * 60 * 1000,
    direction: 'outgoing',
    id: 'easyshare-declined',
    otherName: 'Noah Walker',
    payload: {
      appId: 'feather',
      copyText: 'Road closure near Alta Street.',
      id: 'feather-post-3',
      kind: 'post',
      title: 'Road closure',
    },
    progress: 0,
    status: 'declined',
  },
  {
    createdAt: Date.now() - 4 * 60 * 60 * 1000,
    direction: 'outgoing',
    id: 'easyshare-cancelled',
    otherName: 'Jamie Rivera',
    payload: {
      appId: 'phone',
      copyText: 'Mia Santos\n5550142',
      kind: 'contact',
      title: 'Mia Santos',
    },
    progress: 31,
    status: 'cancelled',
  },
  {
    createdAt: Date.now() - 7 * 60 * 60 * 1000,
    direction: 'incoming',
    id: 'easyshare-expired',
    otherName: 'Mia Santos',
    payload: {
      appId: 'picstagram',
      copyText: 'New post from @mia.santos',
      id: 'picstagram-post-1',
      kind: 'post',
      title: 'Vespucci evening',
    },
    progress: 0,
    status: 'expired',
  },
  {
    createdAt: Date.now() - 24 * 60 * 60 * 1000,
    direction: 'outgoing',
    id: 'easyshare-failed',
    otherName: 'Noah Walker',
    payload: {
      appId: 'photos',
      copyText: 'Vehicle walkaround video.',
      id: 7,
      kind: 'video',
      title: 'Vehicle walkaround',
    },
    progress: 73,
    status: 'failed',
  },
]
const easyShareCatalog = [
  {
    appId: 'phone',
    copyText: 'Mia Santos\n5550142',
    id: 'contact-mia-santos',
    kind: 'contact',
    link: 'skyphone://phone/5550142',
    subtitle: '5550142',
    title: 'Mia Santos',
  },
  {
    appId: 'calendar',
    copyText: 'Downtown meetup\nBring the project notes.',
    id: 'calendar-event-easyshare',
    kind: 'document',
    link: 'skyphone://calendar/event/calendar-event-easyshare',
    subtitle: 'Tonight, 20:30',
    title: 'Downtown meetup',
  },
  {
    appId: 'citymarkt',
    copyText: 'Comet Retro Custom in excellent condition.',
    id: 'listing-easyshare-comet',
    imageUrl:
      'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?w=900',
    kind: 'link',
    link: 'skyphone://citymarkt/listing/listing-easyshare-comet',
    subtitle: '$84,000',
    title: 'Comet Retro Custom',
  },
  {
    appId: 'map',
    copyText: 'Legion Square meeting point',
    kind: 'location',
    link: 'skyphone://location/current',
    title: 'Legion Square',
  },
  {
    appId: 'notes',
    copyText: 'Check fuel, tires and radio before departure.',
    id: 'note-easyshare-checklist',
    kind: 'note',
    title: 'Departure checklist',
  },
  {
    appId: 'photos',
    copyText: 'Sunset over Los Santos.',
    id: 3,
    imageUrl:
      'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=900',
    kind: 'photo',
    link: 'skyphone://media/3',
    title: 'Los Santos sunset',
  },
  {
    appId: 'music',
    copyText: 'Night Drive collection · 8 tracks',
    id: 'playlist-easyshare-night-drive',
    kind: 'playlist',
    link: 'skyphone://music/playlist/playlist-easyshare-night-drive',
    subtitle: '8 tracks',
    title: 'Night Drive collection',
  },
  {
    appId: 'local-pages',
    copyText: 'Road closure\nAlta Street is closed until midnight.',
    id: 'pages-post-easyshare-road-closure',
    kind: 'post',
    link: 'skyphone://local-pages/post/pages-post-easyshare-road-closure',
    subtitle: '@nightshiftls',
    title: 'Road closure',
  },
  {
    appId: 'picstagram',
    copyText: '@mia.santos',
    id: 'picstagram-profile-easyshare-mia',
    imageUrl: 'https://i.pravatar.cc/320?img=47',
    kind: 'profile',
    link: 'skyphone://picstagram/profile/picstagram-profile-easyshare-mia',
    subtitle: '@mia.santos',
    title: 'Mia Santos',
  },
  {
    appId: 'darkchat',
    copyText: 'Use the north entrance. The south gate is locked.',
    id: 'darkchat-message-easyshare-entrance',
    kind: 'text',
    subtitle: 'NightOwl',
    title: 'Use the north entrance',
  },
  {
    appId: 'music',
    copyText: 'Night Drive — Neon Coast',
    id: 'night-drive',
    imageUrl: 'https://picsum.photos/seed/easyshare-night-drive/720/720',
    kind: 'track',
    link: 'skyphone://music/server/night-drive',
    subtitle: 'Neon Coast',
    title: 'Night Drive',
  },
  {
    appId: 'photos',
    copyText: 'Vehicle walkaround video.',
    id: 7,
    imageUrl:
      'https://videos.pexels.com/video-files/3130284/3130284-hd_1920_1080_30fps.mp4',
    kind: 'video',
    link: 'skyphone://media/7',
    title: 'Vehicle walkaround',
  },
  {
    appId: 'companies',
    copyText: 'Los Santos Customs\nRepairs, tuning and roadside support.',
    id: 'mechanic',
    kind: 'profile',
    link: 'skyphone://companies/profile/mechanic',
    subtitle: '555-MECH',
    title: 'Los Santos Customs',
  },
  {
    appId: 'mail',
    copyText: 'Project handoff\nThe final checklist is attached below.',
    id: 17,
    kind: 'document',
    link: 'skyphone://mail/message/17',
    subtitle: 'mia@ifruit.com',
    title: 'Project handoff',
  },
  {
    appId: 'house',
    copyText: 'Vespucci Canals Apartment',
    id: 'vespucci-apartment-4',
    kind: 'document',
    link: 'skyphone://house/property/vespucci-apartment-4',
    subtitle: 'Owner',
    title: 'Vespucci Canals Apartment',
  },
].map((payload, index) => ({
  createdAt: Date.now() - (index + 1) * 5 * 60 * 1000,
  direction: index % 2 === 0 ? 'incoming' : 'outgoing',
  id: `easyshare-catalog-${payload.kind}`,
  otherName: index % 2 === 0 ? 'Mia Santos' : 'Noah Walker',
  payload,
  progress: 100,
  status: 'completed',
}))
let easyShareVisibility = 'everyone'

let cityWarnSequence = 4
let cityWarnAlerts = [
  {
    area: {
      centerX: 425.1,
      centerY: -979.5,
      label: 'Mission Row & Textile City',
      radius: 900,
      type: 'radius',
    },
    authorName: 'Jordan Hayes',
    body: 'Police have closed the area around Mission Row. Avoid access roads and follow instructions from emergency personnel.',
    category: 'police',
    createdAt: Date.now() - 11 * 60 * 1000,
    expiresAt: Date.now() + 49 * 60 * 1000,
    id: 'f074ea9d-45ab-4d90-9057-000000000001',
    instructions:
      'Stay outside the marked area. Use Elgin Avenue or Strawberry Avenue as alternate routes.',
    revision: 2,
    severity: 'danger',
    sourceLabel: 'Los Santos Police Department',
    startsAt: Date.now() - 11 * 60 * 1000,
    status: 'active',
    title: 'Police operation in Mission Row',
    updatedAt: Date.now() - 4 * 60 * 1000,
    updates: [
      {
        actorName: 'Jordan Hayes',
        createdAt: Date.now() - 4 * 60 * 1000,
        id: 'f074ea9d-45ab-4d90-9057-000000000012',
        kind: 'update',
        message: 'The closure has been extended to Textile City.',
      },
      {
        actorName: 'Jordan Hayes',
        createdAt: Date.now() - 11 * 60 * 1000,
        id: 'f074ea9d-45ab-4d90-9057-000000000011',
        kind: 'published',
        message: 'Police operation in Mission Row',
      },
    ],
  },
  {
    area: {
      centerX: 1177.2,
      centerY: -1453.6,
      label: 'El Burro Heights',
      radius: null,
      type: 'district',
    },
    authorName: 'Maya Torres',
    body: 'Following a damaged water main, pressure fluctuations and temporary outages may occur in the eastern part of the city.',
    category: 'infrastructure',
    createdAt: Date.now() - 38 * 60 * 1000,
    expiresAt: Date.now() + 142 * 60 * 1000,
    id: 'f074ea9d-45ab-4d90-9057-000000000002',
    instructions:
      'Keep drinking water available as a precaution. Emergency services are not affected.',
    revision: 1,
    severity: 'warning',
    sourceLabel: 'Los Santos Fire Department',
    startsAt: Date.now() - 38 * 60 * 1000,
    status: 'active',
    title: 'Water supply disruption',
    updatedAt: Date.now() - 38 * 60 * 1000,
    updates: [
      {
        actorName: 'Maya Torres',
        createdAt: Date.now() - 38 * 60 * 1000,
        id: 'f074ea9d-45ab-4d90-9057-000000000021',
        kind: 'published',
        message: 'Water supply disruption',
      },
    ],
  },
  {
    area: {
      centerX: null,
      centerY: null,
      label: 'Los Santos',
      radius: null,
      type: 'city',
    },
    authorName: 'Maya Torres',
    body: 'The technical fault in the city radio network has been resolved.',
    category: 'public_safety',
    createdAt: Date.now() - 27 * 60 * 60 * 1000,
    expiresAt: Date.now() - 26 * 60 * 60 * 1000,
    id: 'f074ea9d-45ab-4d90-9057-000000000003',
    instructions: 'No further action is required.',
    revision: 2,
    severity: 'information',
    sourceLabel: 'City Administration',
    startsAt: Date.now() - 27 * 60 * 60 * 1000,
    status: 'resolved',
    title: 'City radio network restored',
    updatedAt: Date.now() - 26 * 60 * 60 * 1000,
    updates: [
      {
        actorName: 'Maya Torres',
        createdAt: Date.now() - 26 * 60 * 60 * 1000,
        id: 'f074ea9d-45ab-4d90-9057-000000000032',
        kind: 'resolved',
        message: 'All systems are operating normally again.',
      },
    ],
  },
]

function cityWarnBootstrap(testScenario) {
  const readonly = testScenario === 'citywarn-readonly'
  return {
    active: cityWarnAlerts.filter(
      (alert) => alert.status === 'active' && alert.expiresAt > Date.now(),
    ),
    archive: cityWarnAlerts.filter(
      (alert) => alert.status !== 'active' || alert.expiresAt <= Date.now(),
    ),
    context: {
      allowedCategories: readonly
        ? []
        : ['public_safety', 'police', 'infrastructure', 'evacuation'],
      canCityWide: !readonly,
      canPublish: !readonly,
      gradeLabel: readonly ? null : 'Sergeant',
      jobLabel: readonly ? null : 'Los Santos Police Department',
      maximumSeverity: readonly ? null : 'extreme',
      onDuty: !readonly,
      requiresDuty: true,
    },
    onlinePlayers: 127,
  }
}

function easyShareHistoryForScenario(testScenario) {
  if (testScenario === 'easyshare-empty') return []
  if (testScenario === 'easyshare-incoming') {
    return easyShareHistory.filter(
      (transfer) => transfer.id === 'easyshare-incoming-pending',
    )
  }
  if (testScenario === 'easyshare-history') {
    return easyShareHistory.filter(
      (transfer) => !['pending', 'transferring'].includes(transfer.status),
    )
  }
  if (testScenario === 'easyshare-catalog') return easyShareCatalog
  if (testScenario === 'easyshare-full') {
    return [...easyShareHistory, ...easyShareCatalog]
  }
  return easyShareHistory
}

app.post('/api/:endpoint', (request, response) => {
  const endpoint = request.params.endpoint
  const testScenario = String(request.body._testScenario ?? '')
  if (lifecycleEndpoints.has(endpoint)) {
    response.json({ success: true })
    return
  }
  const cityWarnReadonly = testScenario === 'citywarn-readonly'
  if (endpoint === 'citywarn:bootstrap') {
    response.json({ success: true, data: cityWarnBootstrap(testScenario) })
    return
  }
  if (
    ['citywarn:publish', 'citywarn:update', 'citywarn:resolve'].includes(
      endpoint,
    ) &&
    cityWarnReadonly
  ) {
    response.json({ success: false, error: 'not_authorized' })
    return
  }
  if (endpoint === 'citywarn:publish') {
    const title = String(request.body.title ?? '').trim()
    const body = String(request.body.body ?? '').trim()
    const area = request.body.area
    if (!title || !body || !area?.label || !area?.type) {
      response.json({ success: false, error: 'invalid_warning' })
      return
    }
    const now = Date.now()
    const alert = {
      area: {
        centerX: area.centerX == null ? null : Number(area.centerX),
        centerY: area.centerY == null ? null : Number(area.centerY),
        label: String(area.label),
        radius: area.radius == null ? null : Number(area.radius),
        type: String(area.type),
      },
      authorName: 'Jordan Hayes',
      body,
      category: String(request.body.category),
      createdAt: now,
      expiresAt: now + Number(request.body.durationMinutes ?? 60) * 60000,
      id: `f074ea9d-45ab-4d90-9057-${String(cityWarnSequence++).padStart(12, '0')}`,
      instructions: String(request.body.instructions ?? ''),
      revision: 1,
      severity: String(request.body.severity),
      sourceLabel: 'Los Santos Police Department',
      startsAt: now,
      status: 'active',
      title,
      updatedAt: now,
      updates: [
        {
          actorName: 'Jordan Hayes',
          createdAt: now,
          id: randomUUID(),
          kind: 'published',
          message: title,
        },
      ],
    }
    cityWarnAlerts.unshift(alert)
    response.json({ success: true, data: { alert, recipients: 127 } })
    return
  }
  if (endpoint === 'citywarn:update') {
    const alert = cityWarnAlerts.find((item) => item.id === request.body.id)
    const message = String(request.body.message ?? '').trim()
    if (!alert || alert.status !== 'active') {
      response.json({ success: false, error: 'not_found' })
      return
    }
    if (!message || alert.revision !== Number(request.body.revision)) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    alert.revision += 1
    alert.updatedAt = Date.now()
    alert.updates.unshift({
      actorName: 'Jordan Hayes',
      createdAt: alert.updatedAt,
      id: randomUUID(),
      kind: 'update',
      message,
    })
    response.json({ success: true, data: { alert } })
    return
  }
  if (endpoint === 'citywarn:resolve') {
    const alert = cityWarnAlerts.find((item) => item.id === request.body.id)
    const message = String(request.body.message ?? '').trim()
    if (!alert || alert.status !== 'active') {
      response.json({ success: false, error: 'not_found' })
      return
    }
    if (!message || alert.revision !== Number(request.body.revision)) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    alert.revision += 1
    alert.status = 'resolved'
    alert.updatedAt = Date.now()
    alert.updates.unshift({
      actorName: 'Jordan Hayes',
      createdAt: alert.updatedAt,
      id: randomUUID(),
      kind: 'resolved',
      message,
    })
    response.json({ success: true, data: { alert } })
    return
  }
  const canManageWeazelNews = testScenario !== 'weazel-readonly'
  if (endpoint === 'weazel-news:context') {
    response.json({
      success: true,
      data: {
        canManage: canManageWeazelNews,
        categories: weazelNewsCategoryIds.map((id) => ({
          count: weazelNewsArticles.filter(
            (article) =>
              article.status === 'published' && article.category === id,
          ).length,
          id,
        })),
        ...(canManageWeazelNews
          ? { jobGradeLabel: 'Senior Reporter', jobLabel: 'Weazel News' }
          : {}),
        maximumImages: weazelNewsMaxImages,
      },
    })
    return
  }
  if (endpoint === 'weazel-news:list') {
    const category = request.body.category ?? null
    const search = String(request.body.search ?? '')
      .trim()
      .toLowerCase()
    if (
      category !== null &&
      !weazelNewsCategoryIds.includes(String(category))
    ) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    const items = weazelNewsArticles
      .filter((article) => article.status === 'published')
      .filter((article) => category === null || article.category === category)
      .filter(
        (article) =>
          !search ||
          `${article.title} ${article.body}`.toLowerCase().includes(search),
      )
      .sort((left, right) => (right.publishedAt ?? 0) - (left.publishedAt ?? 0))
    response.json({
      success: true,
      data: pageWeazelNewsArticles(items, request.body),
    })
    return
  }
  if (endpoint === 'weazel-news:get') {
    if (request.body.manage === true && !canManageWeazelNews) {
      response.json({ success: false, error: 'not_authorized' })
      return
    }
    const article = weazelNewsArticles.find(
      (item) =>
        item.id === request.body.id &&
        (request.body.manage === true || item.status === 'published'),
    )
    response.json(
      article
        ? { success: true, data: { article } }
        : { success: false, error: 'not_found' },
    )
    return
  }
  if (endpoint === 'weazel-news:manage-list') {
    if (!canManageWeazelNews) {
      response.json({ success: false, error: 'not_authorized' })
      return
    }
    const status = String(request.body.status ?? 'all')
    const search = String(request.body.search ?? '')
      .trim()
      .toLowerCase()
    if (!['all', 'published', 'draft'].includes(status)) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    const items = weazelNewsArticles
      .filter((article) => status === 'all' || article.status === status)
      .filter(
        (article) =>
          !search ||
          `${article.title} ${article.body}`.toLowerCase().includes(search),
      )
      .sort((left, right) => right.updatedAt - left.updatedAt)
    response.json({
      success: true,
      data: pageWeazelNewsArticles(items, request.body),
    })
    return
  }
  if (
    ['weazel-news:create', 'weazel-news:update', 'weazel-news:delete'].includes(
      endpoint,
    ) &&
    !canManageWeazelNews
  ) {
    response.json({ success: false, error: 'not_authorized' })
    return
  }
  if (endpoint === 'weazel-news:create') {
    const validation = validateWeazelNewsDraft(request.body)
    if (!validation.article) {
      response.json({ success: false, error: validation.error })
      return
    }
    const now = Date.now()
    const id = `34c0ec54-bfb1-4ad7-81da-${String(weazelNewsSequence).padStart(12, '0')}`
    weazelNewsSequence += 1
    const article = {
      ...validation.article,
      authorName: 'Jordan Hayes',
      createdAt: now,
      id,
      publishedAt: validation.article.status === 'published' ? now : null,
      revision: 1,
      updatedAt: now,
    }
    weazelNewsArticles.unshift(article)
    response.json({ success: true, data: { article } })
    return
  }
  if (endpoint === 'weazel-news:update') {
    const index = weazelNewsArticles.findIndex(
      (article) => article.id === request.body.id,
    )
    if (index < 0) {
      response.json({ success: false, error: 'not_found' })
      return
    }
    const current = weazelNewsArticles[index]
    if (current.revision !== Number(request.body.revision)) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    const validation = validateWeazelNewsDraft(request.body)
    if (!validation.article) {
      response.json({ success: false, error: validation.error })
      return
    }
    const now = Date.now()
    const article = {
      ...current,
      ...validation.article,
      publishedAt:
        validation.article.status === 'published'
          ? (current.publishedAt ?? now)
          : null,
      revision: current.revision + 1,
      updatedAt: now,
    }
    weazelNewsArticles[index] = article
    response.json({ success: true, data: { article } })
    return
  }
  if (endpoint === 'weazel-news:delete') {
    const index = weazelNewsArticles.findIndex(
      (article) => article.id === request.body.id,
    )
    if (index < 0) {
      response.json({ success: false, error: 'not_found' })
      return
    }
    if (weazelNewsArticles[index].revision !== Number(request.body.revision)) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    weazelNewsArticles.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('companies:') && testScenario === 'companies-error') {
    response.json({ success: false, error: 'service_unavailable' })
    return
  }
  if (endpoint === 'companies:list') {
    const reply = () => {
      const search = String(request.body.search ?? '')
        .trim()
        .toLowerCase()
      const categoryId = String(request.body.categoryId ?? '')
      const availability = String(request.body.availability ?? '')
      const offset = Math.max(0, Number(request.body.cursor ?? 0))
      const pageSize = 3
      let items = companyProfiles.filter((company) => {
        if (categoryId && company.categoryId !== categoryId) return false
        if (availability && company.availability !== availability) return false
        if (request.body.hasLocation && !company.location) return false
        if (request.body.acceptsRequests && !company.acceptsRequests)
          return false
        if (!search) return true
        return [
          company.name,
          company.categoryName,
          company.description,
          company.location?.district,
          ...company.services.flatMap((service) => [
            service.title,
            service.description,
          ]),
        ]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(search))
      })
      if (request.body.sort === 'name') {
        items = [...items].sort((left, right) =>
          left.name.localeCompare(right.name),
        )
      } else if (request.body.sort === 'updated') {
        items = [...items].sort(
          (left, right) =>
            new Date(right.availabilityUpdatedAt).getTime() -
            new Date(left.availabilityUpdatedAt).getTime(),
        )
      }
      if (
        testScenario === 'companies-empty-search' ||
        search === 'no results'
      ) {
        items = []
      }
      const page = items.slice(offset, offset + pageSize)
      response.json({
        success: true,
        data: {
          categories: companyCategories,
          companies: page.map(companySummary),
          nextCursor:
            offset + page.length < items.length
              ? String(offset + page.length)
              : null,
        },
      })
    }
    if (testScenario === 'companies-loading') setTimeout(reply, 1200)
    else reply()
    return
  }
  if (endpoint === 'companies:get') {
    const company = companyProfiles.find(
      (item) => item.id === String(request.body.companyId),
    )
    response.json(
      company
        ? { success: true, data: { company } }
        : { success: false, error: 'company_not_found' },
    )
    return
  }
  if (endpoint === 'companies:my-requests') {
    const list = request.body.list === 'closed' ? 'closed' : 'open'
    const offset = Math.max(0, Number(request.body.cursor ?? 0))
    const matches = companyRequests.filter((item) =>
      list === 'closed'
        ? ['completed', 'cancelled'].includes(item.status)
        : !['completed', 'cancelled'].includes(item.status),
    )
    const page = matches.slice(offset, offset + 2)
    response.json({
      success: true,
      data: {
        nextCursor:
          offset + page.length < matches.length
            ? String(offset + page.length)
            : null,
        requests: page.map(companyRequestSummary),
        unreadCount: companyRequests.reduce(
          (total, item) => total + item.unreadCount,
          0,
        ),
      },
    })
    return
  }
  if (endpoint === 'companies:get-request') {
    const item = companyRequests.find(
      (candidate) => candidate.id === String(request.body.requestId),
    )
    if (item) item.unreadCount = 0
    response.json(
      item
        ? { success: true, data: { request: item } }
        : { success: false, error: 'request_not_found' },
    )
    return
  }
  if (endpoint === 'companies:work-context') {
    response.json({
      success: true,
      data: { context: companyWorkContext(testScenario) },
    })
    return
  }
  if (endpoint === 'companies:work-queue') {
    const filter = String(request.body.filter ?? 'new')
    const offset = Math.max(0, Number(request.body.cursor ?? 0))
    const matches = companyRequests.filter((item) => {
      if (item.companyId !== 'bennys') return false
      if (filter === 'assigned') return item.assignedLabel === 'you'
      return item.status === filter
    })
    const page = matches.slice(offset, offset + 2)
    response.json({
      success: true,
      data: {
        nextCursor:
          offset + page.length < matches.length
            ? String(offset + page.length)
            : null,
        requests: page.map(companyRequestSummary),
      },
    })
    return
  }
  if (endpoint === 'companies:list-members') {
    response.json({ success: true, data: { members: companyMembers } })
    return
  }
  if (endpoint === 'companies:create-request') {
    const company = companyProfiles.find(
      (item) => item.id === String(request.body.companyId),
    )
    const service = company?.services.find(
      (item) => item.id === String(request.body.serviceId),
    )
    if (!company?.acceptsRequests || !service?.acceptsRequests) {
      response.json({ success: false, error: 'invalid_service' })
      return
    }
    const now = new Date().toISOString()
    const item = {
      actions: {
        allowedStatuses: ['assigned', 'cancelled'],
        canAssign: true,
        canCall: true,
        canCancel: true,
        canClaim: true,
        canReply: true,
      },
      assignedLabel: null,
      companyId: company.id,
      companyLogoUrl: company.logoUrl,
      companyName: company.name,
      createdAt: now,
      description: String(request.body.description ?? ''),
      events: [
        {
          createdAt: now,
          id: `company-event-${Date.now()}`,
          status: 'new',
          type: 'created',
        },
      ],
      id: `company-request-${companyRequestSequence++}`,
      media: (Array.isArray(request.body.mediaIds)
        ? request.body.mediaIds
        : []
      ).flatMap((mediaId) => {
        const media = mockMedia.find(
          (candidate) =>
            candidate.id === Number(mediaId) && candidate.mediaType === 'photo',
        )
        return media ? [{ id: media.id, url: media.url }] : []
      }),
      messages: [],
      phoneNumber: company.phoneNumber,
      revision: 1,
      serviceId: service.id,
      serviceName: service.title,
      status: 'new',
      subject: String(request.body.subject ?? ''),
      unreadCount: 0,
      updatedAt: now,
    }
    companyRequests.unshift(item)
    response.json({ success: true, data: { request: item } })
    return
  }
  if (
    [
      'companies:cancel-request',
      'companies:send-message',
      'companies:claim-request',
      'companies:assign-request',
      'companies:update-request-status',
    ].includes(endpoint)
  ) {
    const item = companyRequests.find(
      (candidate) => candidate.id === String(request.body.requestId),
    )
    if (!item) {
      response.json({ success: false, error: 'request_not_found' })
      return
    }
    if (Number(request.body.revision) !== item.revision) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    const now = new Date().toISOString()
    if (endpoint === 'companies:cancel-request') {
      item.status = 'cancelled'
      item.actions = {
        allowedStatuses: [],
        canAssign: false,
        canCall: true,
        canCancel: false,
        canClaim: false,
        canReply: false,
      }
      item.events.push({
        createdAt: now,
        id: `company-event-${Date.now()}`,
        status: 'cancelled',
        type: 'cancelled',
      })
    }
    if (endpoint === 'companies:send-message') {
      item.messages.push({
        author: 'customer',
        authorLabel: 'you',
        body: String(request.body.body ?? ''),
        createdAt: now,
        id: `company-message-${Date.now()}`,
        isMine: true,
      })
    }
    if (endpoint === 'companies:claim-request') {
      item.assignedLabel = 'you'
      item.status = 'assigned'
      item.actions.canClaim = false
      item.events.push({
        createdAt: now,
        id: `company-event-${Date.now()}`,
        status: 'assigned',
        type: 'assigned',
      })
    }
    if (endpoint === 'companies:assign-request') {
      const member = companyMembers.find(
        (candidate) => candidate.id === String(request.body.memberId),
      )
      if (!member?.online) {
        response.json({ success: false, error: 'not_authorized' })
        return
      }
      item.assignedLabel = 'assigned'
      item.status = 'assigned'
      item.actions.canClaim = false
      item.events.push({
        createdAt: now,
        id: `company-event-${Date.now()}`,
        status: 'assigned',
        type: 'assigned',
      })
    }
    if (endpoint === 'companies:update-request-status') {
      item.status = String(request.body.status)
      item.events.push({
        createdAt: now,
        id: `company-event-${Date.now()}`,
        status: item.status,
        type:
          item.status === 'completed'
            ? 'completed'
            : item.status === 'cancelled'
              ? 'cancelled'
              : 'status_changed',
      })
    }
    item.revision += 1
    item.updatedAt = now
    response.json({
      success: true,
      data: {
        context: companyWorkContext(testScenario),
        request: item,
      },
    })
    return
  }
  if (
    [
      'companies:update-availability',
      'companies:update-profile',
      'companies:update-hours',
      'companies:update-services',
      'companies:publish-announcement',
    ].includes(endpoint)
  ) {
    const company = companyProfiles.find((item) => item.id === 'bennys')
    if (
      testScenario === 'companies-conflict' ||
      Number(request.body.revision) !== company.revision
    ) {
      response.json({ success: false, error: 'revision_conflict' })
      return
    }
    if (endpoint === 'companies:update-availability') {
      company.availability = String(request.body.availability)
      company.availabilityUpdatedAt = new Date().toISOString()
    }
    if (endpoint === 'companies:update-profile') {
      company.acceptsRequests = request.body.acceptsRequests === true
      company.description = String(request.body.description ?? '')
      company.location = {
        ...company.location,
        address: String(request.body.address ?? ''),
        coords:
          request.body.coords && typeof request.body.coords === 'object'
            ? { ...request.body.coords }
            : company.location.coords,
        district: String(request.body.district ?? ''),
        label: String(request.body.locationLabel ?? ''),
      }
      const logo = mockMedia.find(
        (item) => item.id === Number(request.body.logoMediaId),
      )
      const cover = mockMedia.find(
        (item) => item.id === Number(request.body.coverMediaId),
      )
      if (logo) company.logoUrl = logo.url
      if (cover) company.coverUrl = cover.url
    }
    if (endpoint === 'companies:update-hours') {
      company.hours = Array.isArray(request.body.hours)
        ? request.body.hours
        : []
    }
    if (endpoint === 'companies:update-services') {
      company.services = Array.isArray(request.body.services)
        ? request.body.services.map((service, index) => ({
            ...service,
            id: service.id || `service-${Date.now()}-${index}`,
          }))
        : []
      company.serviceSummary = company.services
        .filter((service) => service.active)
        .map((service) => service.title)
        .join(', ')
    }
    if (endpoint === 'companies:publish-announcement') {
      const body = String(request.body.body ?? '').trim()
      company.announcement = body
        ? {
            body,
            expiresAt: request.body.expiresAt || null,
            publishedAt: new Date().toISOString(),
          }
        : null
    }
    company.revision += 1
    response.json({
      success: true,
      data: {
        company,
        context: companyWorkContext(testScenario),
      },
    })
    return
  }
  if (endpoint === 'companies:set-call-availability') {
    companyCallAvailable = request.body.available === true
    response.json({
      success: true,
      data: { context: companyWorkContext(testScenario) },
    })
    return
  }
  if (endpoint === 'companies:call-customer') {
    const item = companyRequests.find(
      (candidate) => candidate.id === String(request.body.requestId),
    )
    response.json(
      item ? { success: true } : { success: false, error: 'request_not_found' },
    )
    return
  }
  if (endpoint === 'companies:dial-service-line') {
    const context = companyWorkContext(testScenario)
    if (!context.authorized || !context.permissions.canTakeCalls) {
      response.json({ success: false, error: 'not_authorized' })
      return
    }
    const phoneNumber = String(request.body.phoneNumber ?? '').replace(
      /\D/g,
      '',
    )
    if (
      phoneNumber.length !== 10 ||
      companyProfiles.some((company) => company.phoneNumber === phoneNumber)
    ) {
      response.json({ success: false, error: 'invalid_number' })
      return
    }
    const id = `company-call-${Date.now()}`
    const startedAt = Date.now()
    recentCalls.unshift({
      call_id: id,
      created_at: new Date(startedAt).toISOString(),
      direction: 'outgoing',
      duration_seconds: 0,
      id: recentCalls.length + 1,
      other_number: phoneNumber,
      status: 'ringing',
    })
    response.json({
      success: true,
      data: {
        direction: 'outgoing',
        id,
        otherNumber: phoneNumber,
        speakerEnabled: false,
        speakerSupported: true,
        startedAt,
        state: 'ringing',
      },
    })
    return
  }
  if (endpoint === 'crewlink:bootstrap') {
    response.json({ success: true, data: crewLinkBootstrap(testScenario) })
    return
  }
  if (endpoint === 'crewlink:login') {
    if (!crewLinkProfile || request.body.password !== crewLinkTestPassword) {
      response.json({ success: false, error: 'invalid_credentials' })
      return
    }
    crewLinkAuthenticated = true
    response.json({ success: true, data: crewLinkBootstrap(testScenario) })
    return
  }
  if (endpoint === 'crewlink:register') {
    const username = String(request.body.username ?? '').trim()
    if (!/^[A-Za-z0-9][A-Za-z0-9._]{1,18}[A-Za-z0-9]$/.test(username)) {
      response.json({ success: false, error: 'invalid_username' })
      return
    }
    const password = String(request.body.password ?? '')
    if (password.length < 8 || password.length > 72) {
      response.json({ success: false, error: 'invalid_password' })
      return
    }
    if (crewLinkProfile) {
      response.json({ success: false, error: 'profile_exists' })
      return
    }
    crewLinkProfile = {
      activeGroupId: null,
      avatarMediaId: Number(request.body.avatarMediaId) || null,
      avatarUrl:
        mockMedia.find((item) => item.id === Number(request.body.avatarMediaId))
          ?.url ?? null,
      id: `crewlink-profile-${Date.now()}`,
      mapVisible: true,
      overheadVisible: false,
      username,
    }
    crewLinkAuthenticated = true
    response.json({ success: true, data: crewLinkBootstrap(testScenario) })
    return
  }
  if (endpoint === 'crewlink:logout') {
    crewLinkAuthenticated = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:update-profile') {
    const hasAvatarUpdate = request.body.avatarMediaId !== undefined
    const avatarMediaId = Number(request.body.avatarMediaId) || null
    const avatar = hasAvatarUpdate
      ? mockMedia.find(
          (item) => item.id === avatarMediaId && item.mediaType === 'photo',
        )
      : null
    if (avatarMediaId && !avatar) {
      response.json({ success: false, error: 'invalid_profile_image' })
      return
    }
    crewLinkProfile = {
      ...crewLinkProfile,
      avatarMediaId: hasAvatarUpdate
        ? avatarMediaId
        : crewLinkProfile.avatarMediaId,
      avatarUrl: hasAvatarUpdate
        ? (avatar?.url ?? null)
        : crewLinkProfile.avatarUrl,
      mapVisible: request.body.mapVisible === true,
      overheadVisible: request.body.overheadVisible === true,
      username: String(request.body.username ?? crewLinkProfile.username),
    }
    for (const members of Object.values(crewLinkMembers)) {
      const own = members.find((member) => member.id === crewLinkProfile.id)
      if (own) {
        own.avatarUrl = crewLinkProfile.avatarUrl
        own.mapVisible = crewLinkProfile.mapVisible
        own.overheadVisible = crewLinkProfile.overheadVisible
        own.username = crewLinkProfile.username
      }
    }
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:create-group') {
    const name = String(request.body.name ?? '').trim()
    if (name.length < 3) {
      response.json({ success: false, error: 'invalid_group' })
      return
    }
    const id = `crewlink-group-${Date.now()}`
    crewLinkGroups.unshift({
      allowMemberPings: true,
      colour: request.body.colour ?? 'cyan',
      id,
      inviteCode: Math.random().toString(36).slice(2, 10).toUpperCase(),
      isOwner: true,
      memberCount: 1,
      name,
      overheadAllowed: true,
      role: 'owner',
    })
    crewLinkMembers[id] = [
      {
        coords: { x: -155.2, y: -1005.8, z: 28.4 },
        id: crewLinkProfile.id,
        joinedAt: Date.now(),
        mapVisible: crewLinkProfile.mapVisible,
        online: true,
        overheadVisible: crewLinkProfile.overheadVisible,
        role: 'owner',
        source: 1,
        username: crewLinkProfile.username,
      },
    ]
    crewLinkPings[id] = []
    crewLinkProfile.activeGroupId = id
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:update-group') {
    const group = crewLinkGroups.find(
      (item) => item.id === request.body.groupId,
    )
    if (!group) {
      response.json({ success: false, error: 'group_not_found' })
      return
    }
    Object.assign(group, {
      allowMemberPings: request.body.allowMemberPings,
      colour: request.body.colour,
      name: request.body.name,
      overheadAllowed: request.body.overheadAllowed,
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:delete-group') {
    crewLinkGroups = crewLinkGroups.filter(
      (item) => item.id !== request.body.groupId,
    )
    delete crewLinkMembers[request.body.groupId]
    delete crewLinkPings[request.body.groupId]
    crewLinkProfile.activeGroupId = crewLinkGroups[0]?.id ?? null
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:set-active') {
    const group = crewLinkGroups.find(
      (item) => item.id === request.body.groupId,
    )
    if (!group) {
      response.json({ success: false, error: 'group_not_found' })
      return
    }
    crewLinkProfile.activeGroupId = group.id
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:join-code') {
    if (String(request.body.code).toUpperCase() !== 'SANDY247') {
      response.json({ success: false, error: 'invalid_code' })
      return
    }
    const id = 'crewlink-group-sandy'
    if (!crewLinkGroups.some((group) => group.id === id)) {
      crewLinkGroups.push({
        allowMemberPings: true,
        colour: 'orange',
        id,
        isOwner: false,
        memberCount: 3,
        name: 'Sandy Trails',
        overheadAllowed: false,
        role: 'member',
      })
      crewLinkMembers[id] = [
        {
          coords: { x: 1702.1, y: 3591.4, z: 35.4 },
          id: crewLinkProfile.id,
          joinedAt: Date.now(),
          mapVisible: true,
          online: true,
          overheadVisible: false,
          role: 'member',
          username: crewLinkProfile.username,
        },
      ]
      crewLinkPings[id] = []
    }
    crewLinkProfile.activeGroupId = id
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:rotate-code') {
    const group = crewLinkGroups.find(
      (item) => item.id === request.body.groupId,
    )
    if (group) group.inviteCode = 'FRESH247'
    response.json({ success: true, data: { inviteCode: 'FRESH247' } })
    return
  }
  if (endpoint === 'crewlink:nearby') {
    response.json({ success: true, data: crewLinkNearby })
    return
  }
  if (endpoint === 'crewlink:invite-nearby') {
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:respond-invite') {
    const invitation = crewLinkInvitations.find(
      (item) => item.id === request.body.invitationId,
    )
    crewLinkInvitations = crewLinkInvitations.filter(
      (item) => item.id !== request.body.invitationId,
    )
    if (request.body.accepted && invitation) {
      crewLinkGroups.push({
        allowMemberPings: true,
        colour: invitation.colour,
        id: invitation.groupId,
        isOwner: false,
        memberCount: 4,
        name: invitation.groupName,
        overheadAllowed: true,
        role: 'member',
      })
      crewLinkMembers[invitation.groupId] = []
      crewLinkPings[invitation.groupId] = []
      crewLinkProfile.activeGroupId = invitation.groupId
    }
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:update-member') {
    const members = crewLinkMembers[request.body.groupId] ?? []
    const member = members.find((item) => item.id === request.body.profileId)
    if (member) member.role = request.body.role
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:transfer-owner') {
    const group = crewLinkGroups.find(
      (item) => item.id === request.body.groupId,
    )
    const members = crewLinkMembers[request.body.groupId] ?? []
    const current = members.find((item) => item.id === crewLinkProfile.id)
    const next = members.find((item) => item.id === request.body.profileId)
    if (group) {
      group.isOwner = false
      group.role = 'coordinator'
      delete group.inviteCode
    }
    if (current) current.role = 'coordinator'
    if (next) next.role = 'owner'
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:remove-member') {
    const members = crewLinkMembers[request.body.groupId] ?? []
    crewLinkMembers[request.body.groupId] = members.filter(
      (item) => item.id !== request.body.profileId,
    )
    const group = crewLinkGroups.find(
      (item) => item.id === request.body.groupId,
    )
    if (group) group.memberCount = crewLinkMembers[request.body.groupId].length
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:leave') {
    crewLinkGroups = crewLinkGroups.filter(
      (item) => item.id !== request.body.groupId,
    )
    crewLinkProfile.activeGroupId = crewLinkGroups[0]?.id ?? null
    response.json({ success: true, data: crewLinkBootstrap() })
    return
  }
  if (endpoint === 'crewlink:create-ping') {
    const groupId = crewLinkProfile.activeGroupId
    const ping = {
      coords: request.body.coords ?? { x: -155.2, y: -1005.8, z: 28.4 },
      createdAt: Date.now(),
      creatorProfileId: crewLinkProfile.id,
      creatorUsername: crewLinkProfile.username,
      expiresAt: Date.now() + 300000,
      id: `crewlink-ping-${Date.now()}`,
      label: request.body.label,
      type: request.body.type,
    }
    crewLinkPings[groupId] = [ping, ...(crewLinkPings[groupId] ?? [])]
    response.json({ success: true, data: ping })
    return
  }
  if (endpoint === 'crewlink:remove-ping') {
    const groupId = crewLinkProfile.activeGroupId
    crewLinkPings[groupId] = (crewLinkPings[groupId] ?? []).filter(
      (item) => item.id !== request.body.pingId,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'crewlink:live') {
    const groupId = crewLinkProfile.activeGroupId
    response.json({
      success: true,
      data: {
        members: crewLinkMembers[groupId] ?? [],
        pings: crewLinkPings[groupId] ?? [],
      },
    })
    return
  }
  if (endpoint === 'feather:bootstrap') {
    const empty = testScenario === 'feather-empty'
    const visibleProfiles = featherProfiles.filter(
      (profile) => !featherBlockedProfileIds.includes(profile.id),
    )
    response.json({
      success: true,
      data: {
        onboarded: featherOnboarded,
        profile: featherOnboarded ? featherProfiles[0] : null,
        feed: {
          items: empty
            ? []
            : featherPosts.filter(
                (post) =>
                  !post.reply_to_id &&
                  !featherBlockedProfileIds.includes(post.profile_id),
              ),
          offset: 0,
          hasMore: false,
        },
        suggestions: empty
          ? []
          : visibleProfiles.filter((profile) => !profile.is_owner),
        topics: empty ? [] : featherTopics,
      },
    })
    return
  }
  if (endpoint === 'feather:create-profile') {
    const displayName = String(request.body.displayName ?? '').trim()
    const handle = String(request.body.handle ?? '')
      .trim()
      .toLowerCase()
    const bio = String(request.body.bio ?? '').trim()
    if (
      !displayName ||
      displayName.length > 50 ||
      !/^[a-z0-9][a-z0-9_]{1,28}[a-z0-9]$/.test(handle) ||
      bio.length > 160
    ) {
      response.json({ success: false, error: 'invalid_handle' })
      return
    }
    if (
      featherProfiles.some(
        (profile) => profile.id !== 1 && profile.handle === handle,
      )
    ) {
      response.json({ success: false, error: 'handle_taken' })
      return
    }
    featherProfiles[0].display_name = displayName
    featherProfiles[0].handle = handle
    featherProfiles[0].bio = bio
    const avatar = mockMedia.find(
      (item) =>
        item.id === Number(request.body.avatarId) && item.mediaType === 'photo',
    )
    if (request.body.avatarId && !avatar) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    featherProfiles[0].avatar_url = avatar?.url ?? null
    featherPosts
      .filter((post) => post.profile_id === featherProfiles[0].id)
      .forEach((post) => {
        post.avatar_url = featherProfiles[0].avatar_url
        post.display_name = displayName
        post.handle = handle
      })
    featherOnboarded = true
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:update-profile') {
    const displayName = String(request.body.displayName ?? '').trim()
    const bio = String(request.body.bio ?? '').trim()
    if (!displayName || displayName.length > 50 || bio.length > 160) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    featherProfiles[0].display_name = displayName
    featherProfiles[0].bio = bio
    featherPosts
      .filter((post) => post.profile_id === featherProfiles[0].id)
      .forEach((post) => {
        post.display_name = displayName
      })
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:feed') {
    const visiblePosts = featherPosts.filter(
      (post) => !featherBlockedProfileIds.includes(post.profile_id),
    )
    const items =
      request.body.mode === 'following'
        ? visiblePosts.filter(
            (post) => !post.reply_to_id && (post.is_following || post.is_owner),
          )
        : visiblePosts.filter((post) => !post.reply_to_id)
    response.json({ success: true, data: { items, offset: 0, hasMore: false } })
    return
  }
  if (endpoint === 'feather:explore') {
    const search = String(request.body.search ?? '')
      .trim()
      .toLowerCase()
    const normalizedSearch = search.replace(/^#/, '')
    response.json({
      success: true,
      data: {
        posts: featherPosts.filter((post) => {
          if (post.reply_to_id) return false
          if (featherBlockedProfileIds.includes(post.profile_id)) return false
          if (!normalizedSearch) return true
          return `${post.body} ${post.display_name} ${post.handle}`
            .toLowerCase()
            .includes(normalizedSearch)
        }),
        profiles: featherProfiles
          .slice(1)
          .filter((profile) => !featherBlockedProfileIds.includes(profile.id))
          .filter((profile) =>
            normalizedSearch
              ? `${profile.display_name} ${profile.handle}`
                  .toLowerCase()
                  .includes(normalizedSearch)
              : true,
          ),
        topics: featherTopics.filter((topic) =>
          normalizedSearch
            ? topic.tag.toLowerCase().includes(normalizedSearch)
            : true,
        ),
      },
    })
    return
  }
  if (endpoint === 'feather:network') {
    const search = String(request.body.search ?? '')
      .trim()
      .replace(/^@/, '')
      .toLowerCase()
    const profiles = featherProfiles.filter(
      (profile) =>
        !profile.is_owner && !featherBlockedProfileIds.includes(profile.id),
    )
    response.json({
      success: true,
      data: {
        results: search
          ? profiles.filter((profile) =>
              `${profile.display_name} ${profile.handle}`
                .toLowerCase()
                .includes(search),
            )
          : [],
        suggestions: profiles.filter((profile) => !profile.is_following),
      },
    })
    return
  }
  if (endpoint === 'feather:create-post') {
    const body = String(request.body.body ?? '').trim()
    const mediaIds = Array.isArray(request.body.mediaIds)
      ? request.body.mediaIds.slice(0, 4)
      : []
    const id = `feather-post-${Date.now()}`
    const selectedMedia = mediaIds
      .map((mediaId) => mockMedia.find((item) => item.id === Number(mediaId)))
      .filter((item) => item?.mediaType === 'photo')
      .map((item) => ({
        id: item.id,
        media_type: 'photo',
        url: item.url,
      }))
    if ((!body && selectedMedia.length === 0) || body.length > 360) {
      response.json({ success: false, error: 'invalid_post' })
      return
    }
    const replyToId = request.body.replyToId
      ? String(request.body.replyToId)
      : null
    const parent = replyToId
      ? featherPosts.find((post) => post.id === replyToId)
      : null
    if (replyToId && !parent) {
      response.json({ success: false, error: 'post_not_found' })
      return
    }
    featherPosts.unshift({
      id,
      profile_id: 1,
      handle: featherProfiles[0].handle,
      display_name: featherProfiles[0].display_name,
      verified: false,
      avatar_url: featherProfiles[0].avatar_url,
      body,
      created_at: Date.now(),
      reply_to_id: replyToId,
      quote_id: request.body.quoteId ?? null,
      is_owner: true,
      is_following: false,
      is_liked: false,
      is_bookmarked: false,
      like_count: 0,
      reply_count: 0,
      media: selectedMedia,
    })
    if (!replyToId) featherProfiles[0].post_count += 1
    if (parent) parent.reply_count += 1
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'feather:react') {
    if (!['like', 'bookmark'].includes(request.body.kind)) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    const post = featherPosts.find((item) => item.id === request.body.id)
    if (!post) {
      response.json({ success: false, error: 'post_not_found' })
      return
    }
    const key = request.body.kind === 'like' ? 'is_liked' : 'is_bookmarked'
    const active = request.body.active === true
    if (request.body.kind === 'like' && post.is_liked !== active)
      post.like_count = Math.max(0, post.like_count + (active ? 1 : -1))
    post[key] = active
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:follow') {
    const profileId = Number(request.body.profileId)
    const profile = featherProfiles.find((item) => item.id === profileId)
    if (!profile || profile.is_owner) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    const wasFollowing = featherFollowingIds.includes(profileId)
    const active = request.body.active === true
    if (active) {
      if (!wasFollowing) featherFollowingIds.push(profileId)
    } else {
      featherFollowingIds = featherFollowingIds.filter((id) => id !== profileId)
    }
    if (wasFollowing !== active) {
      profile.followers = Math.max(0, profile.followers + (active ? 1 : -1))
      featherProfiles[0].following = Math.max(
        0,
        featherProfiles[0].following + (active ? 1 : -1),
      )
    }
    featherProfiles
      .filter((item) => item.id === profileId)
      .forEach((item) => {
        item.is_following = active
      })
    featherPosts
      .filter((item) => item.profile_id === profileId)
      .forEach((item) => {
        item.is_following = active
      })
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:connections') {
    const profileId = Number(request.body.profileId ?? 1)
    const mode = request.body.mode
    let ids = []
    if (profileId === 1) {
      ids = mode === 'followers' ? featherFollowerIds : featherFollowingIds
    } else {
      ids = featherProfiles
        .filter((profile) => profile.id !== profileId && !profile.is_owner)
        .slice(0, 4)
        .map((profile) => profile.id)
    }
    response.json({
      success: true,
      data: {
        items: ids
          .map((id) => featherProfiles.find((profile) => profile.id === id))
          .filter(Boolean),
      },
    })
    return
  }
  if (endpoint === 'feather:remove-connection') {
    const targetId = Number(request.body.profileId)
    if (request.body.mode === 'followers') {
      featherFollowerIds = featherFollowerIds.filter((id) => id !== targetId)
      featherProfiles[0].followers = Math.max(
        0,
        featherProfiles[0].followers - 1,
      )
    } else {
      featherFollowingIds = featherFollowingIds.filter((id) => id !== targetId)
      featherProfiles[0].following = Math.max(
        0,
        featherProfiles[0].following - 1,
      )
      const target = featherProfiles.find((profile) => profile.id === targetId)
      if (target) target.is_following = false
      featherPosts
        .filter((post) => post.profile_id === targetId)
        .forEach((post) => {
          post.is_following = false
        })
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:profile') {
    const profile =
      featherProfiles.find(
        (item) => item.id === Number(request.body.profileId),
      ) ?? featherProfiles[0]
    if (featherBlockedProfileIds.includes(profile.id)) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    response.json({
      success: true,
      data: {
        profile,
        posts: featherPosts.filter((post) => post.profile_id === profile.id),
      },
    })
    return
  }
  if (endpoint === 'feather:bookmarks') {
    response.json({
      success: true,
      data: {
        items: featherPosts.filter((post) => post.is_bookmarked),
        offset: 0,
        hasMore: false,
      },
    })
    return
  }
  if (endpoint === 'feather:thread') {
    const post = featherPosts.find((item) => item.id === request.body.id)
    response.json(
      post
        ? {
            success: true,
            data: {
              post,
              replies: featherPosts.filter(
                (item) =>
                  item.reply_to_id === post.id &&
                  !featherBlockedProfileIds.includes(item.profile_id),
              ),
            },
          }
        : { success: false, error: 'post_not_found' },
    )
    return
  }
  if (endpoint === 'feather:activities') {
    response.json({
      success: true,
      data: testScenario === 'feather-empty' ? [] : featherActivities,
    })
    return
  }
  if (endpoint === 'feather:mark-activities') {
    featherActivities.forEach((item) => {
      item.read = true
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:delete') {
    const post = featherPosts.find((item) => item.id === request.body.id)
    if (!post || !post.is_owner) {
      response.json({ success: false, error: 'post_not_found' })
      return
    }
    if (post.reply_to_id) {
      const parent = featherPosts.find((item) => item.id === post.reply_to_id)
      if (parent) parent.reply_count = Math.max(0, parent.reply_count - 1)
    }
    const deletedIds = new Set(
      featherPosts
        .filter((item) => item.id === post.id || item.reply_to_id === post.id)
        .map((item) => item.id),
    )
    featherPosts = featherPosts.filter((item) => !deletedIds.has(item.id))
    if (!post.reply_to_id)
      featherProfiles[0].post_count = Math.max(
        0,
        featherProfiles[0].post_count - 1,
      )
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:block') {
    const profileId = Number(request.body.profileId)
    const profile = featherProfiles.find((item) => item.id === profileId)
    if (!profile || profile.is_owner) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    if (!featherBlockedProfileIds.includes(profileId))
      featherBlockedProfileIds.push(profileId)
    if (featherFollowingIds.includes(profileId)) {
      featherFollowingIds = featherFollowingIds.filter((id) => id !== profileId)
      featherProfiles[0].following = Math.max(
        0,
        featherProfiles[0].following - 1,
      )
    }
    profile.is_following = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'feather:report') {
    const post = featherPosts.find((item) => item.id === request.body.id)
    const reason = String(request.body.reason ?? '')
    if (
      !post ||
      !['spam', 'harassment', 'dangerous', 'illegal', 'other'].includes(reason)
    ) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    featherReports.push({
      id: `feather-report-${Date.now()}`,
      post_id: post.id,
      reason,
      details: String(request.body.details ?? '').slice(0, 500),
      created_at: Date.now(),
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'radio:get') {
    response.json({ success: true, data: radioData })
    return
  }
  if (endpoint === 'radio:connect') {
    radioData.connected = true
    radioData.frequency = Number(request.body.frequency)
    radioData.secondaryFrequency = Number(request.body.secondaryFrequency) || 0
    radioData.members = [
      {
        id: 12,
        joinTime: 248,
        name: 'Alex Morgan',
        rank: 'Sergeant',
        rankNumber: 3,
      },
      {
        id: 27,
        joinTime: 42,
        name: 'Jamie Rivera',
        rank: 'Officer',
        rankNumber: 1,
      },
    ]
    response.json({ success: true, data: radioData })
    return
  }
  if (endpoint === 'radio:disconnect') {
    radioData.connected = false
    radioData.frequency = 0
    radioData.secondaryFrequency = 0
    radioData.members = []
    radioData.speakerEnabled = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'radio:set-volume') {
    radioData.volume = Math.max(0, Math.min(100, Number(request.body.volume)))
    response.json({ success: true, data: { volume: radioData.volume } })
    return
  }
  if (endpoint === 'radio:set-speaker') {
    if (!radioData.connected || !radioData.speakerSupported) {
      response.json({ success: false, error: 'speaker_unavailable' })
      return
    }
    radioData.speakerEnabled = request.body.enabled === true
    response.json({
      success: true,
      data: { speakerEnabled: radioData.speakerEnabled },
    })
    return
  }
  if (endpoint === 'radio:save-settings') {
    radioData.settings[request.body.key] = request.body.value === true
    response.json({ success: true, data: radioData.settings })
    return
  }
  if (endpoint === 'radio:save-badge') {
    radioData.badge = String(request.body.badge ?? '')
    response.json({ success: true, data: { badge: radioData.badge } })
    return
  }
  if (endpoint === 'radio:save-display-name') {
    radioData.displayName = String(request.body.displayName ?? '')
    response.json({
      success: true,
      data: { displayName: radioData.displayName },
    })
    return
  }
  const bankingOverview = () => ({
    bank: mockBankBalance,
    cash: mockCashBalance,
    currency: '$',
    playerId: 42,
    playerName: 'Alex Morgan',
    transactions: mockBankTransactions,
  })
  const cryptoOverview = () => {
    const currentHoldings = cryptoHoldings.map((holding) => {
      const market = cryptoMarkets.find((item) => item.id === holding.assetId)
      return {
        ...holding,
        value: (Number(holding.quantity) * Number(market?.price ?? 0)).toFixed(
          2,
        ),
      }
    })
    return {
      activity: cryptoActivity,
      authenticated: cryptoAuthenticated,
      cashBalance: String(cryptoCashBalance),
      holdings: currentHoldings,
      markets: cryptoMarkets,
      portfolioValue: String(
        cryptoCashBalance +
          currentHoldings.reduce(
            (total, holding) => total + Number(holding.value),
            0,
          ),
      ),
      profile: cryptoAuthenticated ? cryptoProfile : null,
      registered: cryptoRegistered,
    }
  }
  const billingInvoice = (invoice) => ({
    ...invoice,
    canDispute: invoice.direction === 'inbox' && invoice.status === 'open',
    canPay: invoice.direction === 'inbox' && invoice.status === 'open',
    isOverdue:
      invoice.status === 'open' &&
      invoice.dueAt !== null &&
      invoice.dueAt < Date.now(),
  })
  const billingOverview = (direction) => {
    const visible = mockBillingInvoices.filter(
      (invoice) => invoice.direction === direction,
    )
    const open = visible.filter((invoice) => invoice.status === 'open')
    return {
      currency: '$',
      openCount: open.length,
      openTotal: open.reduce((total, invoice) => total + invoice.amount, 0),
      overdueCount: open.filter(
        (invoice) => invoice.dueAt && invoice.dueAt < Date.now(),
      ).length,
      supportsDisputes: true,
      supportsSent: true,
      unreadCount: mockBillingInvoices.filter(
        (invoice) => invoice.direction === 'inbox' && invoice.isUnread,
      ).length,
      urgentInvoices: open
        .sort((left, right) => left.dueAt - right.dueAt)
        .slice(0, 5)
        .map(billingInvoice),
    }
  }
  if (endpoint.startsWith('flare:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'flare:bootstrap') {
    response.json({ success: true, data: flareBootstrap() })
    return
  }
  if (endpoint === 'flare:delete-profile') {
    if (!flareProfile) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    flareProfile = null
    flareSuggestions = freshFlareSuggestions()
    flareLikes = []
    flareLastSwipe = null
    flareMatches.splice(0, flareMatches.length)
    for (const matchId of Object.keys(flareMessages)) {
      delete flareMessages[matchId]
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'flare:save-profile') {
    const requestedPhotoIds = request.body.photoMediaIds
    const validIds =
      Array.isArray(requestedPhotoIds) &&
      requestedPhotoIds.length >= 1 &&
      requestedPhotoIds.length <= 6 &&
      new Set(requestedPhotoIds).size === requestedPhotoIds.length &&
      requestedPhotoIds.every((id) => Number.isInteger(id) && id > 0)
    const photos = validIds
      ? requestedPhotoIds.map((id) =>
          mockMedia.find(
            (item) => item.id === id && item.mediaType === 'photo',
          ),
        )
      : []
    if (!validIds || photos.some((photo) => !photo)) {
      response.json({ success: false, error: 'invalid_profile_photos' })
      return
    }
    const photoUpdate = {
      photoMediaIds: [...requestedPhotoIds],
      photoUrls: photos.map((photo) => photo.url),
    }
    flareProfile = {
      ...flareProfile,
      ...request.body,
      discoverable: flareProfile?.discoverable ?? true,
      ...photoUpdate,
    }
    response.json({ success: true, data: flareBootstrap() })
    return
  }
  if (endpoint === 'flare:set-discovery') {
    if (!flareProfile) {
      response.json({ success: false, error: 'invalid_profile' })
      return
    }
    if (typeof request.body.enabled !== 'boolean') {
      response.json({ success: false, error: 'invalid_discovery' })
      return
    }
    flareProfile.discoverable = request.body.enabled
    response.json({ success: true, data: flareBootstrap() })
    return
  }
  if (endpoint === 'flare:swipe') {
    if (!flareProfile?.discoverable) {
      response.json({ success: false, error: 'discovery_disabled' })
      return
    }
    const target = flareSuggestions.find(
      (profile) => profile.id === Number(request.body.targetId),
    )
    flareLastSwipe = target
      ? { choice: request.body.choice, profile: target }
      : null
    flareSuggestions = flareSuggestions.filter(
      (profile) => profile.id !== Number(request.body.targetId),
    )
    flareLikes = flareLikes.filter(
      (profile) => profile.id !== Number(request.body.targetId),
    )
    let match = null
    if (
      target &&
      ['like', 'superlike'].includes(request.body.choice) &&
      target.id === 11
    ) {
      match = {
        id: 'flare-match-maya-0000-0000-0000000001',
        profile: target,
        lastMessage: '',
        lastMessageAt: null,
        lastMessageType: null,
        unread: 0,
      }
      flareMatches.unshift(match)
      flareMessages[match.id] = []
    }
    response.json({ success: true, data: { match } })
    return
  }
  if (endpoint === 'flare:rewind') {
    if (!flareLastSwipe) {
      response.json({ success: false, error: 'nothing_to_rewind' })
      return
    }
    const hasMatch = flareMatches.some(
      (match) => match.profile.id === flareLastSwipe.profile.id,
    )
    if (hasMatch) {
      response.json({ success: false, error: 'cannot_rewind_match' })
      return
    }
    flareSuggestions.unshift(flareLastSwipe.profile)
    flareLastSwipe = null
    response.json({ success: true, data: flareBootstrap() })
    return
  }
  if (endpoint === 'flare:unmatch') {
    const index = flareMatches.findIndex(
      (match) => match.id === request.body.matchId,
    )
    if (index < 0) {
      response.json({ success: false, error: 'match_not_found' })
      return
    }
    flareMatches.splice(index, 1)
    delete flareMessages[request.body.matchId]
    response.json({ success: true, data: { matches: flareMatches } })
    return
  }
  if (endpoint === 'flare:thread') {
    const match = flareMatches.find((item) => item.id === request.body.matchId)
    if (!match) {
      response.json({ success: false, error: 'match_not_found' })
      return
    }
    match.unread = 0
    response.json({
      success: true,
      data: { messages: flareMessages[match.id] ?? [] },
    })
    return
  }
  if (endpoint === 'flare:send') {
    const match = flareMatches.find((item) => item.id === request.body.matchId)
    const messageType = request.body.messageType ?? 'text'
    const body = String(request.body.body ?? '').trim()
    const mediaUrl = String(request.body.mediaAssetId ?? '')
    if (
      !match ||
      (messageType === 'text'
        ? !body
        : messageType === 'share'
          ? !request.body.sharePayload
          : !['image', 'gif', 'video'].includes(messageType) || !mediaUrl)
    ) {
      response.json({ success: false, error: 'invalid_message' })
      return
    }
    const message = {
      id: `flare-message-${Date.now()}`,
      direction: 'sent',
      body:
        messageType === 'share'
          ? body || request.body.sharePayload.title
          : messageType === 'text'
            ? body
            : '',
      createdAt: Date.now(),
      mediaDurationMs: request.body.mediaDurationMs ?? null,
      mediaUrl: messageType === 'text' ? null : mediaUrl,
      messageType,
      sharePayload: messageType === 'share' ? request.body.sharePayload : null,
    }
    flareMessages[match.id] ??= []
    flareMessages[match.id].push(message)
    match.lastMessage = message.body
    match.lastMessageAt = message.createdAt
    match.lastMessageType = messageType
    response.json({ success: true, data: message })
    return
  }
  if (endpoint === 'skypic:bootstrap') {
    response.json({ success: true, data: skyPicBootstrap(testScenario) })
    return
  }
  if (endpoint === 'skypic:create-profile') {
    const displayName = String(request.body.displayName ?? '').trim()
    const handle = String(request.body.handle ?? '')
      .trim()
      .toLowerCase()
    if (!displayName) {
      response.json({ success: false, error: 'invalid_display_name' })
      return
    }
    if (!/^[a-z0-9._]{3,24}$/.test(handle)) {
      response.json({ success: false, error: 'invalid_handle' })
      return
    }
    const avatarSeed = skyPicAvatarSeed(
      request.body.avatarSeed,
      Math.floor(Math.random() * 2_147_483_647) + 1,
    )
    if (avatarSeed === null) {
      response.json({ success: false, error: 'invalid_avatar_seed' })
      return
    }
    const avatarMediaId = Number(request.body.avatarMediaId)
    const avatar = Number.isFinite(avatarMediaId)
      ? mockMedia.find(
          (item) => item.id === avatarMediaId && item.mediaType === 'photo',
        )
      : null
    const onboardingScenario = testScenario === 'skypic-onboarding'
    if (
      (onboardingScenario && skyPicOnboardingProfile) ||
      (!onboardingScenario && skyPicProfile)
    ) {
      response.json({ success: false, error: 'profile_exists' })
      return
    }
    if (onboardingScenario) {
      skyPicOnboardingProfile = {
        allowStoryReplies: true,
        avatarMediaId: avatar?.id ?? null,
        avatarSeed,
        avatarUrl: avatar?.url ?? null,
        bio: '',
        displayName,
        friendCount: 0,
        friendshipStatus: 'none',
        handle,
        id: skyPicProfiles[0].id,
        showInQuickAdd: true,
        snapScore: 0,
        storyPrivacy: 'friends',
      }
      response.json({
        success: true,
        data: { ...skyPicOnboardingProfile },
      })
      return
    }
    Object.assign(skyPicProfiles[0], {
      avatarSeed,
      avatarUrl: avatar?.url ?? null,
      displayName,
      handle,
      snapScore: 0,
    })
    skyPicProfile = {
      ...skyPicProfiles[0],
      allowStoryReplies: true,
      avatarMediaId: avatar?.id ?? null,
      bio: '',
      friendCount: skyPicFriends.length,
      friendshipStatus: 'none',
      showInQuickAdd: true,
      storyPrivacy: 'friends',
    }
    response.json({ success: true, data: { ...skyPicProfile } })
    return
  }
  if (endpoint === 'skypic:delete-account') {
    if (request.body.confirmed !== true) {
      response.json({ success: false, error: 'confirmation_required' })
      return
    }
    if (testScenario === 'skypic-onboarding') {
      if (!skyPicOnboardingProfile) {
        response.json({ success: false, error: 'profile_required' })
        return
      }
      skyPicOnboardingProfile = null
      response.json({ success: true })
      return
    }
    if (!skyPicProfile) {
      response.json({ success: false, error: 'profile_required' })
      return
    }
    skyPicProfile = null
    skyPicFriends = []
    skyPicRequests = []
    skyPicConversations = []
    skyPicSnaps = []
    skyPicMessages.clear()
    skyPicBlockedProfileIds.clear()
    for (const story of skyPicStories) {
      if (!story.isOwner) continue
      skyPicStoryContents.delete(story.id)
      skyPicStoryViewers.delete(story.id)
    }
    skyPicStories = skyPicStories.filter((story) => !story.isOwner)
    response.json({ success: true })
    return
  }
  if (endpoint === 'skypic:update-profile') {
    const onboardingScenario = testScenario === 'skypic-onboarding'
    const currentProfile = onboardingScenario
      ? skyPicOnboardingProfile
      : skyPicProfile
    if (!currentProfile) {
      response.json({ success: false, error: 'profile_required' })
      return
    }
    const displayName = String(request.body.displayName ?? '').trim()
    const handle = String(request.body.handle ?? '')
      .trim()
      .toLowerCase()
    const storyPrivacy = String(request.body.storyPrivacy ?? '')
    if (!displayName) {
      response.json({ success: false, error: 'invalid_display_name' })
      return
    }
    if (!/^[a-z0-9._]{3,24}$/.test(handle)) {
      response.json({ success: false, error: 'invalid_handle' })
      return
    }
    if (!['everyone', 'friends'].includes(storyPrivacy)) {
      response.json({ success: false, error: 'invalid_privacy' })
      return
    }
    const avatarSeed = skyPicAvatarSeed(
      request.body.avatarSeed,
      currentProfile.avatarSeed,
    )
    if (avatarSeed === null) {
      response.json({ success: false, error: 'invalid_avatar_seed' })
      return
    }
    const avatarMediaId =
      request.body.avatarMediaId === null
        ? null
        : Number(request.body.avatarMediaId)
    const avatar =
      avatarMediaId === null
        ? null
        : mockMedia.find(
            (item) => item.id === avatarMediaId && item.mediaType === 'photo',
          )
    const summary = {
      avatarSeed,
      avatarUrl:
        request.body.avatarMediaId === undefined
          ? currentProfile.avatarUrl
          : (avatar?.url ?? null),
      displayName,
      handle,
    }
    const updatedProfile = {
      ...currentProfile,
      ...summary,
      allowStoryReplies: request.body.allowStoryReplies === true,
      avatarMediaId:
        request.body.avatarMediaId === undefined
          ? currentProfile.avatarMediaId
          : (avatar?.id ?? null),
      bio: String(request.body.bio ?? '')
        .trim()
        .slice(0, 160),
      showInQuickAdd: request.body.showInQuickAdd === true,
      storyPrivacy,
    }
    if (onboardingScenario) {
      skyPicOnboardingProfile = updatedProfile
    } else {
      Object.assign(skyPicProfiles[0], summary)
      skyPicProfile = { ...updatedProfile, ...skyPicProfiles[0] }
    }
    response.json({
      success: true,
      data: {
        ...(onboardingScenario ? skyPicOnboardingProfile : skyPicProfile),
      },
    })
    return
  }
  if (endpoint === 'skypic:search') {
    const query = String(request.body.query ?? '')
      .trim()
      .toLowerCase()
    const results = query
      ? skyPicProfiles
          .filter(
            (profile) =>
              profile.id !== skyPicProfile?.id &&
              !skyPicBlockedProfileIds.has(profile.id) &&
              (profile.displayName.toLowerCase().includes(query) ||
                profile.handle.toLowerCase().includes(query)),
          )
          .map(skyPicDiscoveryProfile)
      : []
    response.json({ success: true, data: results })
    return
  }
  if (endpoint === 'skypic:add-friend') {
    const profileId = String(request.body.profileId ?? '')
    const profile = skyPicProfiles.find((item) => item.id === profileId)
    if (
      !profile ||
      profile.id === skyPicProfile?.id ||
      skyPicBlockedProfileIds.has(profile.id)
    ) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    if (skyPicFriendshipStatus(profileId) !== 'none') {
      response.json({ success: false, error: 'friend_request_exists' })
      return
    }
    const friendRequest = {
      createdAt: new Date().toISOString(),
      direction: 'outgoing',
      friendshipId: randomUUID(),
      profile,
    }
    skyPicRequests.push(friendRequest)
    response.json({ success: true, data: skyPicRequestView(friendRequest) })
    return
  }
  if (endpoint === 'skypic:respond-friend') {
    const friendshipId = String(request.body.friendshipId ?? '')
    const friendRequest = skyPicRequests.find(
      (item) =>
        item.friendshipId === friendshipId && item.direction === 'incoming',
    )
    if (!friendRequest) {
      response.json({ success: false, error: 'friendship_not_found' })
      return
    }
    skyPicRequests = skyPicRequests.filter(
      (item) => item.friendshipId !== friendshipId,
    )
    if (request.body.accept !== true) {
      response.json({ success: true })
      return
    }
    const friend = {
      bestStreak: 0,
      createdAt: new Date().toISOString(),
      friendshipId,
      profile: friendRequest.profile,
      streakCount: 0,
    }
    skyPicFriends.push(friend)
    if (skyPicProfile) skyPicProfile.friendCount = skyPicFriends.length
    response.json({ success: true, data: skyPicFriendView(friend) })
    return
  }
  if (endpoint === 'skypic:remove-friend') {
    const friendshipId = String(request.body.friendshipId ?? '')
    const existed =
      skyPicFriends.some((item) => item.friendshipId === friendshipId) ||
      skyPicRequests.some((item) => item.friendshipId === friendshipId)
    if (!existed) {
      response.json({ success: false, error: 'friendship_not_found' })
      return
    }
    skyPicFriends = skyPicFriends.filter(
      (item) => item.friendshipId !== friendshipId,
    )
    skyPicRequests = skyPicRequests.filter(
      (item) => item.friendshipId !== friendshipId,
    )
    skyPicConversations = skyPicConversations.filter(
      (item) => item.friendshipId !== friendshipId,
    )
    skyPicSnaps = skyPicSnaps.filter(
      (item) => item.friendshipId !== friendshipId,
    )
    skyPicMessages.delete(friendshipId)
    if (skyPicProfile) skyPicProfile.friendCount = skyPicFriends.length
    response.json({ success: true })
    return
  }
  if (endpoint === 'skypic:block') {
    const profileId = String(request.body.profileId ?? '')
    const profile = skyPicProfiles.find((item) => item.id === profileId)
    if (!profile || profile.id === skyPicProfile?.id) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    if (request.body.blocked === false) {
      skyPicBlockedProfileIds.delete(profileId)
      response.json({ success: true })
      return
    }
    skyPicBlockedProfileIds.add(profileId)
    const friendshipIds = new Set([
      ...skyPicFriends
        .filter((item) => item.profile.id === profileId)
        .map((item) => item.friendshipId),
      ...skyPicRequests
        .filter((item) => item.profile.id === profileId)
        .map((item) => item.friendshipId),
    ])
    skyPicFriends = skyPicFriends.filter(
      (item) => item.profile.id !== profileId,
    )
    skyPicRequests = skyPicRequests.filter(
      (item) => item.profile.id !== profileId,
    )
    skyPicConversations = skyPicConversations.filter(
      (item) => item.profile.id !== profileId,
    )
    skyPicSnaps = skyPicSnaps.filter(
      (item) =>
        item.sender.id !== profileId && !friendshipIds.has(item.friendshipId),
    )
    for (const friendshipId of friendshipIds) {
      skyPicMessages.delete(friendshipId)
    }
    if (skyPicProfile) skyPicProfile.friendCount = skyPicFriends.length
    response.json({ success: true })
    return
  }
  if (endpoint === 'skypic:send-snap') {
    if (!skyPicProfile) {
      response.json({ success: false, error: 'profile_required' })
      return
    }
    const recipientIds = skyPicRecipientIds(request.body.recipientIds)
    if (!recipientIds) {
      response.json({ success: false, error: 'invalid_recipients' })
      return
    }
    if (
      request.body.mediaIds !== undefined &&
      (!Array.isArray(request.body.mediaIds) ||
        request.body.mediaIds.length < 1 ||
        request.body.mediaIds.length > 10)
    ) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const requestedMediaCount = Array.isArray(request.body.mediaIds)
      ? request.body.mediaIds.length
      : 1
    if (requestedMediaCount * recipientIds.length > 40) {
      response.json({ success: false, error: 'too_many_snaps' })
      return
    }
    const mediaItems = skyPicMediaItems(request.body)
    if (!mediaItems) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const caption = skyPicCaption(request.body.caption)
    if (caption === null) {
      response.json({ success: false, error: 'invalid_caption' })
      return
    }
    const textOverlay = skyPicTextOverlay(request.body.textOverlay)
    if (textOverlay === null) {
      response.json({ success: false, error: 'invalid_overlay' })
      return
    }
    const recipients = recipientIds
      .map((profileId) =>
        skyPicFriends.find((friend) => friend.profile.id === profileId),
      )
      .filter(Boolean)
    if (!recipients.length || recipients.length !== recipientIds.length) {
      response.json({ success: false, error: 'invalid_recipients' })
      return
    }
    if (mediaItems.length * recipients.length > 40) {
      response.json({ success: false, error: 'too_many_snaps' })
      return
    }
    const createdAt = new Date().toISOString()
    const expiresAt = new Date(
      Date.parse(createdAt) + 30 * 24 * 60 * 60_000,
    ).toISOString()
    const durationSeconds = Math.max(
      1,
      Math.min(10, Math.round(Number(request.body.durationSeconds) || 1)),
    )
    const overlayColor = /^#[0-9a-f]{6}$/i.test(request.body.overlayColor)
      ? request.body.overlayColor
      : '#ffffff'
    skyPicIncrementOwnScore(recipients.length * mediaItems.length)
    const sent = []
    for (const friend of recipients) {
      for (const media of mediaItems) {
        const mediaType = media.mediaType === 'video' ? 'video' : 'photo'
        const snap = {
          allowReplay: request.body.allowReplay === true,
          createdAt,
          direction: 'sent',
          durationSeconds,
          expiresAt,
          friendshipId: friend.friendshipId,
          id: randomUUID(),
          openedAt: null,
          replayedAt: null,
          sender: skyPicProfiles[0],
          type: mediaType === 'video' ? 'snap_video' : 'snap_photo',
        }
        skyPicSnaps.push(snap)
        skyPicSnapContents.set(snap.id, {
          caption,
          mediaType,
          mimeType: mediaType === 'video' ? 'video/mp4' : 'image/jpeg',
          overlayColor,
          textOverlay,
          url: media.url,
        })
        skyPicUpdateConversation(friend.friendshipId, {
          createdAt,
          direction: 'sent',
          id: snap.id,
          openedAt: null,
          type: snap.type,
        })
        sent.push(skyPicSnapView(snap))
      }
    }
    response.json({ success: true, data: sent })
    return
  }
  if (endpoint === 'skypic:open-snap') {
    const snapId = String(request.body.snapId ?? '')
    const snap = skyPicSnaps.find(
      (item) => item.id === snapId && item.direction === 'received',
    )
    if (!snap || !skyPicSnapContents.has(snapId)) {
      response.json({ success: false, error: 'snap_unavailable' })
      return
    }
    if (snap.openedAt) {
      response.json({ success: false, error: 'snap_unavailable' })
      return
    }
    snap.openedAt = new Date().toISOString()
    skyPicIncrementOwnScore()
    const conversation = skyPicConversation(snap.friendshipId)
    if (conversation) {
      conversation.unreadCount = Math.max(0, conversation.unreadCount - 1)
      if (conversation.lastItem?.id === snap.id) {
        conversation.lastItem.openedAt = snap.openedAt
      }
    }
    response.json({ success: true, data: skyPicOpenedSnap(snap) })
    return
  }
  if (endpoint === 'skypic:replay-snap') {
    const snapId = String(request.body.snapId ?? '')
    const snap = skyPicSnaps.find(
      (item) => item.id === snapId && item.direction === 'received',
    )
    if (!snap || !skyPicSnapContents.has(snapId)) {
      response.json({ success: false, error: 'snap_unavailable' })
      return
    }
    if (!snap.openedAt) {
      response.json({ success: false, error: 'snap_unavailable' })
      return
    }
    if (!snap.allowReplay || snap.replayedAt) {
      response.json({ success: false, error: 'replay_unavailable' })
      return
    }
    snap.replayedAt = new Date().toISOString()
    response.json({ success: true, data: skyPicOpenedSnap(snap) })
    return
  }
  if (endpoint === 'skypic:stories') {
    const offset = skyPicOffset(request.body.offset)
    if (offset === null) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    const visibleStories = skyPicStories.filter(skyPicStoryVisible)
    response.json({
      success: true,
      data: visibleStories.slice(offset, offset + 30).map(skyPicStoryView),
    })
    return
  }
  if (endpoint === 'skypic:publish-story') {
    if (!skyPicProfile) {
      response.json({ success: false, error: 'profile_required' })
      return
    }
    const mediaId = Number(request.body.mediaId)
    const media = mockMedia.find((item) => item.id === mediaId)
    const mediaType = request.body.mediaType === 'video' ? 'video' : 'photo'
    if (!media || media.mediaType !== mediaType) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const caption = skyPicCaption(request.body.caption)
    if (caption === null) {
      response.json({ success: false, error: 'invalid_caption' })
      return
    }
    const textOverlay = skyPicTextOverlay(request.body.textOverlay)
    if (textOverlay === null) {
      response.json({ success: false, error: 'invalid_overlay' })
      return
    }
    const durationSeconds = Math.max(
      1,
      Math.min(10, Math.round(Number(request.body.durationSeconds) || 1)),
    )
    skyPicIncrementOwnScore()
    const story = {
      author: skyPicProfiles[0],
      createdAt: new Date().toISOString(),
      durationSeconds,
      expiresAt: isoTime(24 * 60 * 60_000),
      id: randomUUID(),
      isOwner: true,
      seen: true,
      viewCount: 0,
    }
    skyPicStories.unshift(story)
    skyPicStoryContents.set(story.id, {
      caption,
      mediaType,
      mimeType: mediaType === 'video' ? 'video/mp4' : 'image/jpeg',
      overlayColor: /^#[0-9a-f]{6}$/i.test(request.body.overlayColor)
        ? request.body.overlayColor
        : '#ffffff',
      textOverlay,
      url: media.url,
    })
    skyPicStoryViewers.set(story.id, [])
    response.json({ success: true, data: skyPicStoryView(story) })
    return
  }
  if (endpoint === 'skypic:view-story') {
    const storyId = String(request.body.storyId ?? '')
    const story = skyPicStories.find((item) => item.id === storyId)
    if (
      !story ||
      !skyPicStoryVisible(story) ||
      !skyPicStoryContents.has(storyId)
    ) {
      response.json({ success: false, error: 'story_unavailable' })
      return
    }
    const viewedAt = new Date().toISOString()
    if (!story.isOwner && !story.seen) {
      story.seen = true
      story.viewCount += 1
    }
    response.json({
      success: true,
      data: skyPicViewedStory(story, viewedAt),
    })
    return
  }
  if (endpoint === 'skypic:story-viewers') {
    const storyId = String(request.body.storyId ?? '')
    const offset = skyPicOffset(request.body.offset)
    if (offset === null) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    const story = skyPicStories.find((item) => item.id === storyId)
    if (!story) {
      response.json({ success: false, error: 'story_unavailable' })
      return
    }
    if (!story.isOwner) {
      response.json({ success: false, error: 'not_authorized' })
      return
    }
    response.json({
      success: true,
      data: (skyPicStoryViewers.get(storyId) ?? [])
        .slice(offset, offset + 30)
        .map(skyPicSummary),
    })
    return
  }
  if (endpoint === 'skypic:remove-story') {
    const storyId = String(request.body.storyId ?? '')
    const story = skyPicStories.find((item) => item.id === storyId)
    if (!story) {
      response.json({ success: false, error: 'story_unavailable' })
      return
    }
    if (!story.isOwner) {
      response.json({ success: false, error: 'not_authorized' })
      return
    }
    skyPicStories = skyPicStories.filter((item) => item.id !== storyId)
    skyPicStoryContents.delete(storyId)
    skyPicStoryViewers.delete(storyId)
    response.json({ success: true })
    return
  }
  if (endpoint === 'skypic:thread') {
    const friendshipId = String(request.body.friendshipId ?? '')
    if (!skyPicFriends.some((friend) => friend.friendshipId === friendshipId)) {
      response.json({ success: false, error: 'friendship_not_found' })
      return
    }
    response.json({
      success: true,
      data: {
        messages: [...(skyPicMessages.get(friendshipId) ?? [])],
        snaps: skyPicSnaps
          .filter((snap) => snap.friendshipId === friendshipId)
          .map(skyPicSnapView),
      },
    })
    return
  }
  if (endpoint === 'skypic:send-message') {
    const friendshipId = String(request.body.friendshipId ?? '')
    const messageInput = skyPicMessageBody(request.body.body)
    const friend = skyPicFriends.find(
      (item) => item.friendshipId === friendshipId,
    )
    if (!friend) {
      response.json({ success: false, error: 'friendship_not_found' })
      return
    }
    if (messageInput.error) {
      response.json({ success: false, error: messageInput.error })
      return
    }
    const body = messageInput.body
    const storyId = request.body.storyId ? String(request.body.storyId) : null
    if (storyId) {
      const story = skyPicStories.find((item) => item.id === storyId)
      if (
        !story ||
        story.isOwner ||
        story.author.id !== friend.profile.id ||
        !skyPicStoryReplyEnabledProfileIds.has(story.author.id) ||
        Date.parse(story.expiresAt) <= Date.now()
      ) {
        response.json({ success: false, error: 'story_unavailable' })
        return
      }
    }
    const message = {
      body,
      createdAt: new Date().toISOString(),
      direction: 'sent',
      friendshipId,
      id: randomUUID(),
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    const messages = skyPicMessages.get(friendshipId) ?? []
    messages.push(message)
    skyPicMessages.set(friendshipId, messages)
    skyPicUpdateConversation(friendshipId, {
      body: message.body,
      createdAt: message.createdAt,
      direction: message.direction,
      id: message.id,
      openedAt: null,
      type: 'text',
    })
    response.json({ success: true, data: message })
    return
  }
  if (endpoint === 'skypic:mark-thread') {
    const friendshipId = String(request.body.friendshipId ?? '')
    if (!skyPicFriends.some((friend) => friend.friendshipId === friendshipId)) {
      response.json({ success: false, error: 'friendship_not_found' })
      return
    }
    const readAt = new Date().toISOString()
    const messages = skyPicMessages.get(friendshipId) ?? []
    for (const message of messages) {
      if (message.direction === 'received' && !message.readAt) {
        message.readAt = readAt
      }
    }
    const conversation = skyPicConversation(friendshipId)
    if (conversation) {
      conversation.unreadCount = skyPicSnaps.filter(
        (snap) =>
          snap.friendshipId === friendshipId &&
          snap.direction === 'received' &&
          !snap.openedAt,
      ).length
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'skypic:save-message') {
    const messageId = String(request.body.messageId ?? '')
    let message = null
    for (const messages of skyPicMessages.values()) {
      message = messages.find((item) => item.id === messageId) ?? null
      if (message) break
    }
    if (!message) {
      response.json({ success: false, error: 'message_not_found' })
      return
    }
    message.savedAt =
      request.body.saved === true ? new Date().toISOString() : null
    response.json({ success: true, data: { ...message } })
    return
  }
  if (endpoint === 'skypic:delete-message') {
    const messageId = String(request.body.messageId ?? '')
    let deleted = false
    for (const [friendshipId, messages] of skyPicMessages.entries()) {
      const filtered = messages.filter((item) => item.id !== messageId)
      if (filtered.length !== messages.length) {
        skyPicMessages.set(friendshipId, filtered)
        deleted = true
        break
      }
    }
    if (!deleted) {
      response.json({ success: false, error: 'message_not_found' })
      return
    }
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('skypic:')) {
    response.json({ success: false, error: 'mock_endpoint_missing' })
    return
  }
  if (endpoint === 'picstagram:bootstrap') {
    response.json({
      success: true,
      data: picstagramAuthenticated
        ? {
            authenticated: true,
            feed: {
              hasMore: false,
              items: picstagramPosts,
              nextCursor: null,
            },
            isAdmin: true,
            profile: picstagramProfiles[0],
          }
        : { authenticated: false, isAdmin: true },
    })
    return
  }
  if (endpoint === 'picstagram:login' || endpoint === 'picstagram:register') {
    picstagramAuthenticated = true
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:logout') {
    picstagramAuthenticated = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:feed') {
    response.json({
      success: true,
      data: { hasMore: false, items: picstagramPosts, nextCursor: null },
    })
    return
  }
  if (endpoint === 'picstagram:post') {
    const post = picstagramPosts.find((item) => item.id === request.body.id)
    response.json(
      post
        ? { success: true, data: post }
        : { success: false, error: 'post_not_found' },
    )
    return
  }
  if (endpoint === 'picstagram:explore') {
    response.json({
      success: true,
      data: {
        hasMore: false,
        items: picstagramPosts.filter((post) => !post.is_owner),
        nextCursor: null,
      },
    })
    return
  }
  if (endpoint === 'picstagram:saved') {
    response.json({
      success: true,
      data: {
        hasMore: false,
        items: picstagramPosts.filter((post) => post.is_saved),
        nextCursor: null,
      },
    })
    return
  }
  if (endpoint === 'picstagram:search') {
    const search = String(request.body.search ?? '').toLowerCase()
    response.json({
      success: true,
      data: {
        posts: picstagramPosts.filter((post) =>
          `${post.handle} ${post.display_name} ${post.caption} ${post.location}`
            .toLowerCase()
            .includes(search),
        ),
        profiles: picstagramProfiles.filter((profile) =>
          `${profile.handle} ${profile.display_name}`
            .toLowerCase()
            .includes(search),
        ),
      },
    })
    return
  }
  if (endpoint === 'picstagram:profile') {
    const profile = picstagramProfiles.find(
      (item) =>
        item.id === request.body.profileId ||
        item.handle === String(request.body.handle ?? '').toLowerCase(),
    )
    if (!profile) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    response.json({
      success: true,
      data: {
        posts: {
          hasMore: false,
          items: picstagramPosts.filter(
            (post) => post.profile_id === profile.id,
          ),
          nextCursor: null,
        },
        profile,
      },
    })
    return
  }
  if (endpoint === 'picstagram:connections') {
    const targetId = request.body.profileId
    const profiles = picstagramProfiles.filter(
      (profile) => profile.id !== targetId,
    )
    response.json({ success: true, data: profiles })
    return
  }
  if (endpoint === 'picstagram:update-profile') {
    Object.assign(picstagramProfiles[0], {
      bio: request.body.bio,
      display_name: request.body.displayName,
      handle: request.body.handle,
      private: request.body.private,
    })
    response.json({ success: true, data: picstagramProfiles[0] })
    return
  }
  if (endpoint === 'picstagram:publish-post') {
    const media = request.body.mediaIds
      .map((id) => mockMedia.find((item) => item.id === id))
      .filter((item) => item?.mediaType === request.body.mediaType)
    if (!media.length) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const post = {
      avatar_url: picstagramProfiles[0].avatar_url,
      caption: request.body.caption,
      comment_count: 0,
      comments_enabled: request.body.commentsEnabled,
      created_at: Date.now(),
      display_name: picstagramProfiles[0].display_name,
      handle: picstagramProfiles[0].handle,
      id: `pic-post-${Date.now()}`,
      is_liked: false,
      is_owner: true,
      is_saved: false,
      like_count: 0,
      location: request.body.location,
      media: media.map((item, position) => ({
        id: item.id,
        media_type: item.mediaType,
        position,
        url: item.url,
      })),
      private: picstagramProfiles[0].private,
      profile_id: picstagramProfiles[0].id,
      verified: picstagramProfiles[0].verified,
    }
    picstagramPosts.unshift(post)
    response.json({ success: true, data: { id: post.id } })
    return
  }
  if (endpoint === 'picstagram:update-post') {
    const post = picstagramPosts.find((item) => item.id === request.body.id)
    if (post)
      Object.assign(post, {
        caption: request.body.caption,
        comments_enabled: request.body.commentsEnabled,
        location: request.body.location,
      })
    response.json({
      success: Boolean(post),
      error: post ? undefined : 'post_not_found',
    })
    return
  }
  if (endpoint === 'picstagram:set-post-status') {
    if (request.body.status !== 'published')
      picstagramPosts = picstagramPosts.filter(
        (post) => post.id !== request.body.id,
      )
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:react') {
    const post = picstagramPosts.find((item) => item.id === request.body.id)
    if (post) {
      const key = request.body.kind === 'like' ? 'is_liked' : 'is_saved'
      const changed = post[key] !== request.body.active
      post[key] = request.body.active
      if (changed && request.body.kind === 'like')
        post.like_count += request.body.active ? 1 : -1
    }
    response.json({
      success: Boolean(post),
      error: post ? undefined : 'post_not_found',
    })
    return
  }
  if (endpoint === 'picstagram:follow') {
    const profile = picstagramProfiles.find(
      (item) => item.id === request.body.profileId,
    )
    if (!profile) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    profile.follow_status = request.body.active
      ? profile.private
        ? 'pending'
        : 'accepted'
      : null
    profile.is_following = profile.follow_status === 'accepted'
    profile.is_requested = profile.follow_status === 'pending'
    profile.locked = profile.private && !profile.is_following
    response.json({ success: true, data: { status: profile.follow_status } })
    return
  }
  if (endpoint === 'picstagram:respond-follow') {
    picstagramActivities = picstagramActivities.filter(
      (activity) =>
        activity.kind !== 'follow_request' ||
        activity.profile_id !== request.body.profileId,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:comments') {
    response.json({ success: true, data: picstagramComments })
    return
  }
  if (endpoint === 'picstagram:comment') {
    const replyTarget = request.body.replyToId
      ? picstagramComments.find((entry) => entry.id === request.body.replyToId)
      : null
    const comment = {
      avatar_url: picstagramProfiles[0].avatar_url,
      body: request.body.body,
      created_at: Date.now(),
      display_name: picstagramProfiles[0].display_name,
      handle: picstagramProfiles[0].handle,
      id: `pic-comment-${Date.now()}`,
      is_liked: false,
      is_owner: true,
      like_count: 0,
      parent_id:
        replyTarget?.parent_id ??
        replyTarget?.id ??
        request.body.parentId ??
        null,
      profile_id: picstagramProfiles[0].id,
      reply_to_handle: replyTarget
        ? replyTarget.handle
        : request.body.parentId
          ? (picstagramComments.find(
              (entry) => entry.id === request.body.parentId,
            )?.handle ?? null)
          : null,
      verified: picstagramProfiles[0].verified,
    }
    picstagramComments.push(comment)
    response.json({ success: true, data: { id: comment.id } })
    return
  }
  if (endpoint === 'picstagram:comment-react') {
    const comment = picstagramComments.find(
      (item) => item.id === request.body.id,
    )
    if (comment) {
      const changed = comment.is_liked !== request.body.active
      comment.is_liked = request.body.active
      if (changed) comment.like_count += request.body.active ? 1 : -1
    }
    response.json({
      success: Boolean(comment),
      error: comment ? undefined : 'invalid_comment',
    })
    return
  }
  if (endpoint === 'picstagram:remove-comment') {
    picstagramComments = picstagramComments.filter(
      (comment) => comment.id !== request.body.id,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:stories') {
    response.json({ success: true, data: picstagramStories })
    return
  }
  if (endpoint === 'picstagram:publish-story') {
    const media = mockMedia.find((item) => item.id === request.body.mediaId)
    if (!media || media.mediaType !== request.body.mediaType) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const story = {
      avatar_url: picstagramProfiles[0].avatar_url,
      body: request.body.body,
      created_at: Date.now(),
      display_name: picstagramProfiles[0].display_name,
      expires_at: Date.now() + 24 * 60 * 60 * 1000,
      handle: picstagramProfiles[0].handle,
      id: `pic-story-${Date.now()}`,
      is_owner: true,
      media_type: media.mediaType,
      profile_id: picstagramProfiles[0].id,
      seen: true,
      url: media.url,
      verified: picstagramProfiles[0].verified,
      view_count: 0,
    }
    picstagramStories.unshift(story)
    response.json({ success: true, data: { id: story.id } })
    return
  }
  if (endpoint === 'picstagram:view-story') {
    const story = picstagramStories.find((item) => item.id === request.body.id)
    if (story) story.seen = true
    response.json({ success: Boolean(story) })
    return
  }
  if (endpoint === 'picstagram:story-viewers') {
    response.json({
      success: true,
      data: [
        {
          avatar_url: picstagramProfiles[1].avatar_url,
          created_at: Date.now() - 60000,
          display_name: picstagramProfiles[1].display_name,
          handle: picstagramProfiles[1].handle,
          id: picstagramProfiles[1].id,
          verified: true,
        },
      ],
    })
    return
  }
  if (endpoint === 'picstagram:remove-story') {
    picstagramStories = picstagramStories.filter(
      (story) => story.id !== request.body.id,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:activities') {
    response.json({ success: true, data: picstagramActivities })
    return
  }
  if (endpoint === 'picstagram:mark-activities') {
    picstagramActivities.forEach((activity) => {
      activity.read_at = new Date().toISOString()
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:block') {
    const profileId = request.body.profileId
    picstagramPosts = picstagramPosts.filter(
      (post) => post.profile_id !== profileId,
    )
    picstagramComments = picstagramComments.filter(
      (comment) => comment.profile_id !== profileId,
    )
    picstagramStories = picstagramStories.filter(
      (story) => story.profile_id !== profileId,
    )
    picstagramActivities = picstagramActivities.filter(
      (activity) => activity.profile_id !== profileId,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:report') {
    picstagramReports.unshift({
      created_at: Date.now(),
      details: request.body.details ?? '',
      id: `pic-report-${Date.now()}`,
      reason: request.body.reason,
      reporter_display_name: picstagramProfiles[0].display_name,
      reporter_handle: picstagramProfiles[0].handle,
      target_id: request.body.targetId,
      target_type: request.body.targetType,
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'picstagram:admin-reports') {
    response.json({ success: true, data: picstagramReports })
    return
  }
  if (endpoint === 'picstagram:admin-resolve-report') {
    picstagramReports = picstagramReports.filter(
      (report) => report.id !== request.body.id,
    )
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('picstagram:')) {
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:bootstrap') {
    if (!flipTokAuthenticated) {
      response.json({
        success: true,
        data: {
          authenticated: false,
          musicTracks: flipTokMusicTracks,
        },
      })
      return
    }
    response.json({
      success: true,
      data: {
        authenticated: true,
        profile: flipTokProfile,
        feed: { items: flipTokVideos, offset: 0, hasMore: false },
        isAdmin: true,
        musicTracks: flipTokMusicTracks,
      },
    })
    return
  }
  if (endpoint === 'fliptok:login' || endpoint === 'fliptok:register') {
    flipTokAuthenticated = true
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:logout') {
    flipTokAuthenticated = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:feed') {
    const items =
      request.body.mode === 'following'
        ? flipTokVideos.filter((video) => video.is_following)
        : flipTokVideos
    response.json({ success: true, data: { items, offset: 0, hasMore: false } })
    return
  }
  if (endpoint === 'fliptok:discover') {
    const search = String(request.body.search ?? '').toLowerCase()
    response.json({
      success: true,
      data: flipTokVideos.filter((video) =>
        `${video.handle} ${video.display_name} ${video.caption}`
          .toLowerCase()
          .includes(search),
      ),
    })
    return
  }
  if (endpoint === 'fliptok:react') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    if (video) {
      const key = request.body.kind === 'like' ? 'is_liked' : 'is_saved'
      const changed = video[key] !== request.body.active
      video[key] = request.body.active
      if (changed && request.body.kind === 'like')
        video.like_count += request.body.active ? 1 : -1
    }
    response.json(
      video ? { success: true } : { success: false, error: 'video_not_found' },
    )
    return
  }
  if (endpoint === 'fliptok:video') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    response.json(
      video
        ? { success: true, data: video }
        : { success: false, error: 'video_not_found' },
    )
    return
  }
  if (endpoint === 'fliptok:follow') {
    flipTokVideos
      .filter((video) => video.profile_id === request.body.profileId)
      .forEach((video) => {
        video.is_following = request.body.active
      })
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:share') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    if (video) video.share_count += 1
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:comments') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    response.json(
      video
        ? {
            success: true,
            data: flipTokComments.filter(
              (comment) => comment.video_id === video.id,
            ),
          }
        : { success: false, error: 'video_not_found' },
    )
    return
  }
  if (endpoint === 'fliptok:comment') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    if (!video) {
      response.json({ success: false, error: 'video_not_found' })
      return
    }
    if (!video.comments_enabled) {
      response.json({ success: false, error: 'comments_disabled' })
      return
    }
    const comment = {
      avatar_url: flipTokProfile.avatar_url,
      id: `comment-${Date.now()}`,
      is_liked: false,
      like_count: 0,
      parent_id: request.body.parentId || null,
      video_id: video.id,
      profile_id: 1,
      reply_to_handle: request.body.parentId
        ? flipTokComments.find((item) => item.id === request.body.parentId)
            ?.handle || null
        : null,
      handle: flipTokProfile.handle,
      display_name: flipTokProfile.display_name,
      verified: flipTokProfile.verified,
      body: request.body.body,
      created_at: Date.now(),
    }
    flipTokComments.push(comment)
    video.comment_count += 1
    response.json({ success: true, data: { id: comment.id } })
    return
  }
  if (endpoint === 'fliptok:comment-react') {
    const comment = flipTokComments.find((item) => item.id === request.body.id)
    if (comment) {
      const changed = comment.is_liked !== (request.body.active === true)
      comment.is_liked = request.body.active === true
      if (changed) comment.like_count += comment.is_liked ? 1 : -1
    }
    response.json(
      comment
        ? { success: true }
        : { success: false, error: 'invalid_comment' },
    )
    return
  }
  if (endpoint === 'fliptok:activities') {
    response.json({ success: true, data: flipTokActivities })
    return
  }
  if (endpoint === 'fliptok:mark-activities') {
    const readAt = new Date().toISOString()
    flipTokActivities = flipTokActivities.map((activity) => ({
      ...activity,
      read_at: activity.read_at ?? readAt,
    }))
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:view') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    if (!video) {
      response.json({ success: false, error: 'video_not_found' })
      return
    }
    video.view_count += 1
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:report') {
    const video = flipTokVideos.find((item) => item.id === request.body.id)
    if (!video) {
      response.json({ success: false, error: 'video_not_found' })
      return
    }
    flipTokReports.push({
      caption: video.caption,
      created_at: Date.now(),
      creator_display_name: video.display_name,
      creator_handle: video.handle,
      details: String(request.body.details ?? ''),
      id: `report-${Date.now()}`,
      reason: request.body.reason,
      reporter_display_name: flipTokProfile.display_name,
      reporter_handle: flipTokProfile.handle,
      url: video.url,
      video_id: video.id,
    })
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:profile') {
    const profileId = Number(request.body.profileId || 0)
    const handle = String(request.body.handle || '').toLowerCase()
    const own =
      profileId === flipTokProfile.id || handle === flipTokProfile.handle
    const videos = own
      ? flipTokVideos.filter((video) => video.profile_id === flipTokProfile.id)
      : flipTokVideos.filter((video) =>
          profileId ? video.profile_id === profileId : video.handle === handle,
        )
    const first = videos[0]
    if (!first && !own) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    response.json({
      success: true,
      data: {
        profile: own
          ? { ...flipTokProfile }
          : {
              id: first.profile_id,
              handle: first.handle,
              display_name: first.display_name,
              bio: 'Creator in Los Santos.',
              account_type: 'person',
              avatar_media_id: null,
              avatar_url: first.avatar_url ?? null,
              verified: first.verified,
              is_following: first.is_following,
              is_owner: false,
              followers: 12840,
              following: 91,
              video_count: videos.length,
            },
        videos,
      },
    })
    return
  }
  if (endpoint === 'fliptok:connections') {
    const creatorVideo = flipTokVideos.find((video) => !video.is_owner)
    const creator = creatorVideo
      ? {
          account_type: 'person',
          avatar_media_id: null,
          avatar_url: creatorVideo.avatar_url ?? null,
          bio: 'Creator in Los Santos.',
          display_name: creatorVideo.display_name,
          followers: 12840,
          following: 91,
          handle: creatorVideo.handle,
          id: creatorVideo.profile_id,
          is_following: creatorVideo.is_following,
          is_owner: false,
          verified: creatorVideo.verified,
          video_count: 1,
        }
      : null
    response.json({
      success: true,
      data:
        request.body.mode === 'followers'
          ? creator
            ? [creator]
            : []
          : creator
            ? [creator, { ...flipTokProfile }]
            : [{ ...flipTokProfile }],
    })
    return
  }
  if (endpoint === 'fliptok:block') {
    const profileId = Number(request.body.profileId)
    flipTokVideos = flipTokVideos.filter(
      (video) => video.profile_id !== profileId,
    )
    flipTokComments = flipTokComments.filter(
      (comment) => comment.profile_id !== profileId,
    )
    flipTokActivities = flipTokActivities.filter(
      (activity) => activity.profile_id !== profileId,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:admin-reports') {
    response.json({ success: true, data: flipTokReports })
    return
  }
  if (endpoint === 'fliptok:admin-resolve-report') {
    const selected = flipTokReports.find(
      (report) => report.id === request.body.id,
    )
    if (selected && request.body.action === 'remove')
      flipTokVideos = flipTokVideos.filter(
        (video) => video.id !== selected.video_id,
      )
    flipTokReports = flipTokReports.filter((report) =>
      request.body.action === 'remove'
        ? report.video_id !== selected?.video_id
        : report.id !== request.body.id,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'fliptok:update-profile') {
    Object.assign(flipTokProfile, {
      handle: request.body.handle,
      display_name: request.body.displayName,
      bio: request.body.bio,
      account_type: request.body.accountType,
      avatar_media_id: request.body.avatarMediaId || null,
      avatar_url:
        mockMedia.find((item) => item.id === request.body.avatarMediaId)?.url ||
        null,
    })
    response.json({ success: true, data: flipTokProfile })
    return
  }
  if (endpoint === 'fliptok:music-metadata') {
    const videoId = parseFlipTokYoutubeId(String(request.body.url || '').trim())
    if (!videoId) {
      response.json({ success: false, error: 'invalid_music_url' })
      return
    }
    response.json({
      success: true,
      data: {
        ...mockYoutubeMetadata(videoId),
        url: `https://www.youtube.com/watch?v=${videoId}`,
        videoId,
      },
    })
    return
  }
  if (endpoint === 'fliptok:publish') {
    const mediaType = request.body.mediaType === 'photo' ? 'photo' : 'video'
    const submittedMediaIds = Array.isArray(request.body.mediaIds)
      ? request.body.mediaIds
      : [request.body.mediaId]
    const mediaIds = [...new Set(submittedMediaIds.map(Number))]
    const mediaItems = mediaIds.map((id) =>
      mockMedia.find((item) => item.id === id && item.mediaType === mediaType),
    )
    if (
      mediaItems.length < 1 ||
      mediaItems.length > 10 ||
      (mediaType === 'video' && mediaItems.length !== 1) ||
      mediaItems.some((item) => !item)
    ) {
      response.json({ success: false, error: 'invalid_media' })
      return
    }
    const media = mediaItems[0]
    const musicTrack = String(request.body.musicTrack || '')
    const configuredTrack = flipTokMusicTracks.find(
      (track) => track.id === musicTrack,
    )
    const customMusicUrl = String(request.body.customMusicUrl || '').trim()
    const youtubeVideoId = parseFlipTokYoutubeId(customMusicUrl)
    const youtubeMetadata = youtubeVideoId
      ? mockYoutubeMetadata(youtubeVideoId)
      : null
    if (
      (musicTrack && !configuredTrack) ||
      (customMusicUrl &&
        (configuredTrack ||
          (!youtubeVideoId && !validFlipTokMusicUrl(customMusicUrl))))
    ) {
      response.json({ success: false, error: 'invalid_music_url' })
      return
    }
    const createdVideo = {
      avatar_url: flipTokProfile.avatar_url,
      id: `fliptok-${Date.now()}`,
      profile_id: 1,
      handle: flipTokProfile.handle,
      display_name: flipTokProfile.display_name,
      verified: flipTokProfile.verified,
      caption: request.body.caption,
      location: String(request.body.location || ''),
      trim_start_ms: mediaType === 'photo' ? 0 : request.body.trimStartMs || 0,
      trim_end_ms:
        mediaType === 'photo' ? null : request.body.trimEndMs || null,
      cover_time_ms: mediaType === 'photo' ? 0 : request.body.coverTimeMs || 0,
      original_volume:
        mediaType === 'photo' ? 0 : (request.body.originalVolume ?? 100),
      music_volume: request.body.musicVolume || 0,
      music_track: configuredTrack?.id || '',
      music_title: configuredTrack?.title || youtubeMetadata?.title || '',
      music_artist: configuredTrack?.artist || youtubeMetadata?.artist || '',
      music_source: configuredTrack
        ? 'audio'
        : youtubeVideoId
          ? 'youtube'
          : customMusicUrl
            ? 'audio'
            : '',
      music_url: youtubeVideoId ? '' : configuredTrack?.url || customMusicUrl,
      music_video_id: youtubeVideoId,
      media_type: mediaType,
      media: mediaItems.map((item) => ({
        id: item.id,
        mediaType: item.mediaType,
        url: item.url,
      })),
      url: media.url,
      comments_enabled: request.body.commentsEnabled,
      is_liked: false,
      is_saved: false,
      is_following: false,
      is_owner: true,
      like_count: 0,
      comment_count: 0,
      view_count: 0,
      share_count: 0,
      created_at: Date.now(),
    }
    if (request.body.draft !== true) {
      flipTokVideos.unshift(createdVideo)
      flipTokProfile.video_count += 1
    }
    response.json({ success: true, data: { id: createdVideo.id } })
    return
  }
  if (endpoint === 'fliptok:delete') {
    const index = flipTokVideos.findIndex(
      (video) => video.id === request.body.id && video.is_owner,
    )
    if (index < 0) {
      response.json({ success: false, error: 'video_not_found' })
      return
    }
    flipTokVideos.splice(index, 1)
    flipTokComments = flipTokComments.filter(
      (comment) => comment.video_id !== request.body.id,
    )
    flipTokProfile.video_count = Math.max(0, flipTokProfile.video_count - 1)
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('fliptok:')) {
    response.json({ success: true })
    return
  }
  if (endpoint === 'skyride:get-player-coords') {
    response.json({
      success: true,
      data: { coords: { x: -265.1, y: -960.2, z: 31.2 } },
    })
    return
  }
  if (endpoint === 'skyride:bootstrap') {
    response.json({ success: true, data: skyRideBootstrap() })
    return
  }
  if (endpoint === 'skyride:history') {
    response.json({ success: true, data: { items: skyRideHistory } })
    return
  }
  if (endpoint === 'skyride:update-profile') {
    const name = String(request.body.name ?? '').trim()
    const avatarMediaId = Number(request.body.avatarMediaId)
    const avatar = avatarMediaId
      ? mockMedia.find(
          (item) => item.id === avatarMediaId && item.mediaType === 'photo',
        )
      : null
    if (
      name.length < 2 ||
      name.length > 50 ||
      !Number.isInteger(avatarMediaId) ||
      avatarMediaId < 0 ||
      (avatarMediaId > 0 && !avatar)
    ) {
      response.json({ success: false, error: 'invalid_profile' })
      return
    }
    skyRideProfile.name = name
    skyRideProfile.avatarMediaId = avatarMediaId || null
    skyRideProfile.avatarUrl = avatar?.url ?? null
    response.json({
      success: true,
      data: skyRideUpdate(['profile']),
    })
    return
  }
  if (endpoint === 'skyride:quote') {
    const pickup = request.body.pickup
    const destination = request.body.destination
    if (!pickup?.coords || !destination?.coords) {
      response.json({ success: false, error: 'invalid_location' })
      return
    }

    const distanceMeters = Math.max(
      750,
      Math.round(
        Math.hypot(
          Number(destination.coords.x) - Number(pickup.coords.x),
          Number(destination.coords.y) - Number(pickup.coords.y),
        ) * 1.25,
      ),
    )
    const durationSeconds = Math.max(60, Math.round(distanceMeters / 12))
    const distanceUnit = 'kilometer'
    const distance = distanceMeters / 1000
    const expiresAt = unixTime(2 * 60)
    const definitions = [
      {
        baseFare: 12,
        etaMinutes: 3,
        minimumFare: 15,
        pricePerKilometer: 18,
        pricePerMile: 29,
        pricePerMinute: 1,
        seats: 4,
        serviceClass: 'taxi',
      },
      {
        baseFare: 16,
        etaMinutes: 5,
        minimumFare: 22,
        pricePerKilometer: 24,
        pricePerMile: 39,
        pricePerMinute: 2,
        seats: 4,
        serviceClass: 'comfort',
      },
      {
        baseFare: 20,
        etaMinutes: 7,
        minimumFare: 28,
        pricePerKilometer: 30,
        pricePerMile: 48,
        pricePerMinute: 2,
        seats: 6,
        serviceClass: 'xl',
      },
      {
        baseFare: 28,
        etaMinutes: 8,
        minimumFare: 38,
        pricePerKilometer: 40,
        pricePerMile: 64,
        pricePerMinute: 3,
        seats: 4,
        serviceClass: 'premium',
      },
    ]
    const requestedCustomFare = request.body.customFare
    if (
      requestedCustomFare !== undefined &&
      (!definitions.some(
        (definition) =>
          definition.serviceClass === requestedCustomFare?.serviceClass,
      ) ||
        !Number.isInteger(requestedCustomFare?.price))
    ) {
      response.json({ success: false, error: 'invalid_custom_fare' })
      return
    }
    const options = definitions.map((definition) => {
      const pricePerDistanceUnit =
        distanceUnit === 'mile'
          ? definition.pricePerMile
          : definition.pricePerKilometer
      const calculatedPrice = Math.round(
        Math.max(
          definition.minimumFare,
          definition.baseFare +
            distance * pricePerDistanceUnit +
            (durationSeconds / 60) * definition.pricePerMinute,
        ),
      )
      const minimumCustomPrice = Math.round(
        Math.max(5, definition.minimumFare, calculatedPrice * 0.5),
      )
      const maximumCustomPrice = Math.round(
        Math.min(100000, calculatedPrice * 3),
      )
      const usesCustomFare =
        requestedCustomFare?.serviceClass === definition.serviceClass
      const requestedPrice = Number(requestedCustomFare?.price)
      if (
        usesCustomFare &&
        (!Number.isInteger(requestedPrice) ||
          requestedPrice < minimumCustomPrice ||
          requestedPrice > maximumCustomPrice)
      ) {
        return null
      }
      const option = {
        available: true,
        calculatedPrice,
        currency: '$',
        etaMinutes: definition.etaMinutes,
        fareMode: usesCustomFare ? 'custom' : 'calculated',
        maximumCustomPrice,
        minimumCustomPrice,
        price: usesCustomFare ? requestedPrice : calculatedPrice,
        pricePerDistanceUnit,
        quoteId: 'skyride-quote-' + Date.now() + '-' + definition.serviceClass,
        seats: definition.seats,
        serviceClass: definition.serviceClass,
      }
      skyRideQuotes.set(option.quoteId, {
        destination,
        expiresAt,
        option,
        pickup,
      })
      return option
    })
    if (options.some((option) => option === null)) {
      response.json({ success: false, error: 'invalid_custom_fare' })
      return
    }

    response.json({
      success: true,
      data: {
        destination,
        distance,
        distanceMeters,
        distanceUnit,
        durationSeconds,
        expiresAt,
        options,
        pickup,
      },
    })
    return
  }
  if (endpoint === 'skyride:request') {
    const quote = skyRideQuotes.get(String(request.body.quoteId ?? ''))
    if (!quote) {
      response.json({ success: false, error: 'quote_not_found' })
      return
    }
    if (quote.expiresAt <= unixTime()) {
      response.json({ success: false, error: 'quote_expired' })
      return
    }
    if (skyRideActiveRide) {
      response.json({ success: false, error: 'active_ride_exists' })
      return
    }

    const now = unixTime()
    const ride = {
      createdAt: now,
      currency: quote.option.currency,
      destination: quote.destination,
      distanceMeters: quote.distanceMeters,
      driver: null,
      durationSeconds: quote.durationSeconds,
      id: `skyride-ride-${skyRideSequence++}`,
      passenger: skyRidePassenger,
      pickup: quote.pickup,
      price: quote.option.price,
      serviceClass: quote.option.serviceClass,
      status: 'searching',
      updatedAt: now,
    }
    skyRideActiveRide = ride
    skyRideAvailableRequests = [
      skyRideWithoutLiveContact(ride),
      ...skyRideAvailableRequests,
    ]
    response.json({
      success: true,
      data: skyRideUpdate(['activeRide']),
    })
    return
  }
  if (endpoint === 'skyride:set-driver-status') {
    if (typeof request.body.online !== 'boolean') {
      response.json({ success: false, error: 'invalid_driver_status' })
      return
    }
    skyRideDriverOnline = request.body.online
    response.json({
      success: true,
      data: skyRideUpdate(['driverOnline', 'availableRequests']),
    })
    return
  }
  if (endpoint === 'skyride:accept') {
    if (!skyRideDriverOnline) {
      response.json({ success: false, error: 'driver_offline' })
      return
    }
    const ride = skyRideAvailableRequests.find(
      (item) => item.id === request.body.rideId,
    )
    if (!ride) {
      response.json({ success: false, error: 'ride_not_found' })
      return
    }
    if (skyRideActiveRide && skyRideActiveRide.id !== ride.id) {
      response.json({ success: false, error: 'active_ride_exists' })
      return
    }

    skyRideActiveRide = {
      ...ride,
      driver: skyRideDriver,
      status: 'accepted',
      updatedAt: unixTime(),
    }
    skyRideAvailableRequests = skyRideAvailableRequests.filter(
      (item) => item.id !== ride.id,
    )
    response.json({
      success: true,
      data: skyRideUpdate(['activeRide', 'availableRequests']),
    })
    return
  }
  if (
    endpoint === 'skyride:arrive' ||
    endpoint === 'skyride:start' ||
    endpoint === 'skyride:complete'
  ) {
    if (!skyRideActiveRide || skyRideActiveRide.id !== request.body.rideId) {
      response.json({ success: false, error: 'ride_not_found' })
      return
    }

    const transition = {
      'skyride:arrive': {
        from: ['accepted', 'driver_arriving'],
        to: 'arrived',
      },
      'skyride:start': { from: ['arrived'], to: 'in_progress' },
      'skyride:complete': { from: ['in_progress'], to: 'completed' },
    }[endpoint]
    if (!transition.from.includes(skyRideActiveRide.status)) {
      response.json({ success: false, error: 'invalid_ride_status' })
      return
    }

    const updatedRide = {
      ...skyRideActiveRide,
      ...(transition.to === 'completed'
        ? { finalPrice: skyRideActiveRide.price }
        : {}),
      status: transition.to,
      updatedAt: unixTime(),
    }
    if (transition.to === 'completed') {
      const passengerRide = updatedRide.passenger?.id === skyRideProfile.id
      skyRideProfile.completedRides += 1
      if (!passengerRide) {
        skyRideProfile.earningsToday += Math.round(
          updatedRide.finalPrice * 0.85,
        )
      }
      const historyRide = skyRideWithoutLiveContact(updatedRide)
      skyRideHistory = [historyRide, ...skyRideHistory]
      skyRidePendingRating = passengerRide ? historyRide : null
      skyRideActiveRide = null
      response.json({
        success: true,
        data: skyRideUpdate([
          'activeRide',
          'history',
          'pendingRating',
          'profile',
        ]),
      })
      return
    }

    skyRideActiveRide = updatedRide
    response.json({
      success: true,
      data: skyRideUpdate(['activeRide']),
    })
    return
  }
  if (endpoint === 'skyride:cancel') {
    const ride =
      skyRideActiveRide?.id === request.body.rideId
        ? skyRideActiveRide
        : skyRideAvailableRequests.find(
            (item) => item.id === request.body.rideId,
          )
    if (!ride) {
      response.json({ success: false, error: 'ride_not_found' })
      return
    }

    const cancelledRide = {
      ...ride,
      status: 'cancelled',
      updatedAt: unixTime(),
    }
    skyRideAvailableRequests = skyRideAvailableRequests.filter(
      (item) => item.id !== ride.id,
    )
    if (skyRideActiveRide?.id === ride.id) skyRideActiveRide = null
    skyRidePendingRating = null
    skyRideHistory = [
      skyRideWithoutLiveContact(cancelledRide),
      ...skyRideHistory,
    ]
    response.json({
      success: true,
      data: skyRideUpdate([
        'activeRide',
        'availableRequests',
        'history',
        'pendingRating',
      ]),
    })
    return
  }
  if (endpoint === 'skyride:rate') {
    const rating = Number(request.body.rating)
    const tip = Number(request.body.tip)
    if (
      !skyRidePendingRating ||
      skyRidePendingRating.id !== request.body.rideId
    ) {
      response.json({ success: false, error: 'ride_not_found' })
      return
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      response.json({ success: false, error: 'invalid_rating' })
      return
    }
    if (!Number.isFinite(tip) || tip < 0 || tip > 10000) {
      response.json({ success: false, error: 'invalid_tip' })
      return
    }

    skyRidePendingRating = null
    response.json({
      success: true,
      data: skyRideUpdate(['history', 'pendingRating']),
    })
    return
  }
  if (endpoint === 'banking:overview') {
    response.json({ success: true, data: bankingOverview() })
    return
  }
  if (endpoint === 'crypto:bootstrap') {
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:market-tick') {
    response.json({ success: true, data: advanceCryptoMarkets() })
    return
  }
  if (endpoint === 'crypto:login') {
    if (request.body.password !== cryptoPassword) {
      response.json({ success: false, error: 'invalid_credentials' })
      return
    }
    cryptoAuthenticated = true
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:register') {
    const handle = String(request.body.handle ?? '').trim()
    const password = String(request.body.password ?? '')
    if (!/^[A-Za-z0-9][A-Za-z0-9._]{1,18}[A-Za-z0-9]$/.test(handle)) {
      response.json({ success: false, error: 'invalid_handle' })
      return
    }
    if (password.length < 8 || password.length > 72) {
      response.json({ success: false, error: 'invalid_password' })
      return
    }
    cryptoAuthenticated = true
    cryptoRegistered = true
    cryptoPassword = password
    cryptoProfile = {
      createdAt: Date.now(),
      handle,
      hideBalances: false,
      id: 'crypto-profile-new',
      priceAlerts: true,
      status: 'active',
      totalTrades: 0,
      totalVolume: '0',
      tradeConfirmations: true,
      walletKey: 'VX-31AF-4D92-882E-C104',
    }
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:logout') {
    cryptoAuthenticated = false
    cryptoQuote = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'crypto:update-profile') {
    const handle = String(request.body.handle ?? '').trim()
    if (!/^[A-Za-z0-9][A-Za-z0-9._]{1,18}[A-Za-z0-9]$/.test(handle)) {
      response.json({ success: false, error: 'invalid_profile' })
      return
    }
    if (
      handle.toLowerCase() !== cryptoProfile.handle.toLowerCase() &&
      request.body.password !== cryptoPassword
    ) {
      response.json({ success: false, error: 'invalid_credentials' })
      return
    }
    if (
      typeof request.body.priceAlerts !== 'boolean' ||
      typeof request.body.tradeConfirmations !== 'boolean' ||
      typeof request.body.hideBalances !== 'boolean'
    ) {
      response.json({ success: false, error: 'invalid_profile' })
      return
    }
    cryptoProfile = {
      ...cryptoProfile,
      handle,
      hideBalances: request.body.hideBalances,
      priceAlerts: request.body.priceAlerts,
      tradeConfirmations: request.body.tradeConfirmations,
    }
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:recipient') {
    const walletKey = String(request.body.walletKey ?? '')
      .trim()
      .toUpperCase()
    if (!/^VX-(?:[A-F0-9]{4}-){3}[A-F0-9]{4}$/.test(walletKey)) {
      response.json({ success: false, error: 'invalid_wallet_key' })
      return
    }
    if (walletKey === cryptoProfile.walletKey) {
      response.json({ success: false, error: 'self_transfer' })
      return
    }
    if (walletKey !== cryptoRecipient.walletKey) {
      response.json({ success: false, error: 'recipient_not_found' })
      return
    }
    response.json({ success: true, data: cryptoRecipient })
    return
  }
  if (endpoint === 'crypto:transfer') {
    const walletKey = String(request.body.walletKey ?? '')
      .trim()
      .toUpperCase()
    const market = cryptoMarkets.find(
      (item) => item.id === request.body.marketId,
    )
    const holding = cryptoHoldings.find(
      (item) => item.assetId === request.body.marketId,
    )
    const quantity = Number(request.body.quantity)
    if (request.body.password !== cryptoPassword) {
      response.json({ success: false, error: 'invalid_credentials' })
      return
    }
    if (
      walletKey !== cryptoRecipient.walletKey ||
      !market ||
      !holding ||
      !Number.isFinite(quantity) ||
      quantity <= 0
    ) {
      response.json({ success: false, error: 'invalid_transfer' })
      return
    }
    if (Number(holding.quantity) < quantity) {
      response.json({ success: false, error: 'insufficient_funds' })
      return
    }
    holding.quantity = (Number(holding.quantity) - quantity).toFixed(6)
    holding.value = (Number(holding.quantity) * Number(market.price)).toFixed(2)
    cryptoActivity.unshift({
      amount: '0',
      counterpartyKey: walletKey,
      createdAt: Date.now(),
      id: `crypto-${nextCryptoActivityId++}`,
      marketId: market.id,
      quantity: quantity.toFixed(6),
      status: 'completed',
      type: 'transfer_out',
    })
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:deposit' || endpoint === 'crypto:withdraw') {
    const amount = Number(request.body.amount)
    if (!Number.isSafeInteger(amount) || amount < 10) {
      response.json({ success: false, error: 'invalid_amount' })
      return
    }
    if (request.body.password !== cryptoPassword) {
      response.json({ success: false, error: 'invalid_credentials' })
      return
    }
    if (endpoint === 'crypto:deposit') {
      if (mockBankBalance < amount) {
        response.json({ success: false, error: 'insufficient_funds' })
        return
      }
      mockBankBalance -= amount
      cryptoCashBalance += amount
    } else {
      if (cryptoCashBalance < amount) {
        response.json({ success: false, error: 'insufficient_funds' })
        return
      }
      cryptoCashBalance -= amount
      mockBankBalance += amount
    }
    cryptoActivity.unshift({
      amount: String(amount),
      createdAt: Date.now(),
      id: `crypto-${nextCryptoActivityId++}`,
      status: 'completed',
      type: endpoint === 'crypto:deposit' ? 'deposit' : 'withdrawal',
    })
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'crypto:quote') {
    const market = cryptoMarkets.find(
      (item) => item.id === request.body.marketId,
    )
    const quantity = Number(request.body.quantity)
    if (!market || !Number.isFinite(quantity) || quantity <= 0) {
      response.json({ success: false, error: 'invalid_quantity' })
      return
    }
    const side = request.body.side === 'sell' ? 'sell' : 'buy'
    const gross = quantity * Number(market.price)
    const fee = Math.max(0.01, Math.ceil(gross * 0.0075 * 100) / 100)
    const net = side === 'buy' ? gross + fee : gross - fee
    cryptoQuote = {
      expiresAt: Date.now() + 8000,
      fee: fee.toFixed(2),
      gross: gross.toFixed(2),
      id: `crypto-quote-${Date.now()}`,
      marketId: market.id,
      net: net.toFixed(2),
      price: market.price,
      quantity: quantity.toFixed(6),
      side,
    }
    response.json({ success: true, data: cryptoQuote })
    return
  }
  if (endpoint === 'crypto:execute') {
    if (
      !cryptoQuote ||
      cryptoQuote.id !== request.body.quoteId ||
      cryptoQuote.expiresAt < Date.now()
    ) {
      response.json({ success: false, error: 'quote_expired' })
      return
    }
    const market = cryptoMarkets.find(
      (item) => item.id === cryptoQuote.marketId,
    )
    const holding = cryptoHoldings.find(
      (item) => item.assetId === cryptoQuote.marketId,
    )
    const quantity = Number(cryptoQuote.quantity)
    const net = Number(cryptoQuote.net)
    if (cryptoQuote.side === 'buy') {
      if (cryptoCashBalance < net) {
        response.json({ success: false, error: 'insufficient_funds' })
        return
      }
      cryptoCashBalance -= net
      if (holding)
        holding.quantity = (Number(holding.quantity) + quantity).toFixed(6)
      else
        cryptoHoldings.push({
          assetId: market.id,
          averagePrice: market.price,
          quantity: quantity.toFixed(6),
          value: '0',
        })
    } else {
      if (!holding || Number(holding.quantity) < quantity) {
        response.json({ success: false, error: 'insufficient_funds' })
        return
      }
      holding.quantity = (Number(holding.quantity) - quantity).toFixed(6)
      cryptoCashBalance += net
      cryptoHoldings = cryptoHoldings.filter(
        (item) => Number(item.quantity) > 0,
      )
    }
    for (const item of cryptoHoldings) {
      const itemMarket = cryptoMarkets.find(
        (marketItem) => marketItem.id === item.assetId,
      )
      item.value = (Number(item.quantity) * Number(itemMarket.price)).toFixed(2)
    }
    cryptoActivity.unshift({
      amount: String(Math.round(net)),
      createdAt: Date.now(),
      id: `crypto-${nextCryptoActivityId++}`,
      marketId: cryptoQuote.marketId,
      status: 'completed',
      type: cryptoQuote.side,
    })
    cryptoQuote = null
    response.json({ success: true, data: cryptoOverview() })
    return
  }
  if (endpoint === 'health:overview') {
    response.json({ success: true, data: healthOverview() })
    return
  }
  if (endpoint === 'health:save-profile') {
    healthMedicalId = {
      ...healthMedicalId,
      allergies: String(request.body.allergies ?? ''),
      bloodType: String(request.body.bloodType ?? ''),
      conditions: String(request.body.conditions ?? ''),
      emergencyName: String(request.body.emergencyName ?? ''),
      emergencyPhone: String(request.body.emergencyPhone ?? ''),
      emergencyRelation: String(request.body.emergencyRelation ?? ''),
      medication: String(request.body.medication ?? ''),
    }
    response.json({ success: true, data: healthMedicalId })
    return
  }
  if (endpoint === 'billing:overview') {
    response.json({
      success: true,
      data: billingOverview(
        request.body.direction === 'sent' ? 'sent' : 'inbox',
      ),
    })
    return
  }
  if (endpoint === 'billing:list') {
    const direction = request.body.direction === 'sent' ? 'sent' : 'inbox'
    const filter = String(request.body.filter ?? 'all')
    const search = String(request.body.search ?? '').toLowerCase()
    const offset = Math.max(0, Number(request.body.offset) || 0)
    let invoices = mockBillingInvoices.filter(
      (invoice) => invoice.direction === direction,
    )
    if (filter === 'open')
      invoices = invoices.filter((invoice) => invoice.status === 'open')
    if (filter === 'overdue') {
      invoices = invoices.filter(
        (invoice) => invoice.status === 'open' && invoice.dueAt < Date.now(),
      )
    }
    if (filter === 'paid')
      invoices = invoices.filter((invoice) => invoice.status !== 'open')
    if (search) {
      invoices = invoices.filter((invoice) =>
        `${invoice.title} ${invoice.issuerLabel} ${invoice.description}`
          .toLowerCase()
          .includes(search),
      )
    }
    const page = invoices.slice(offset, offset + 30).map(billingInvoice)
    response.json({
      success: true,
      data: {
        hasMore: offset + page.length < invoices.length,
        invoices: page,
        nextOffset: offset + page.length,
      },
    })
    return
  }
  if (endpoint === 'billing:detail') {
    const invoice = mockBillingInvoices.find(
      (item) => item.id === request.body.id,
    )
    response.json(
      invoice
        ? { success: true, data: billingInvoice(invoice) }
        : { success: false, error: 'invoice_not_found' },
    )
    return
  }
  if (endpoint === 'billing:markRead') {
    const invoice = mockBillingInvoices.find(
      (item) => item.id === request.body.id,
    )
    if (invoice) invoice.isUnread = false
    response.json({
      success: true,
      data: { unreadCount: billingOverview('inbox').unreadCount },
    })
    return
  }
  if (endpoint === 'billing:pay') {
    const invoice = mockBillingInvoices.find(
      (item) => item.id === request.body.id,
    )
    if (
      !invoice ||
      invoice.direction !== 'inbox' ||
      invoice.status !== 'open'
    ) {
      response.json({ success: false, error: 'invoice_not_payable' })
      return
    }
    if (mockBankBalance < invoice.amount) {
      response.json({ success: false, error: 'insufficient_funds' })
      return
    }
    mockBankBalance -= invoice.amount
    invoice.status = 'paid'
    invoice.paidAt = Date.now()
    invoice.isUnread = false
    invoice.paymentReference = `mock-billing-${Date.now()}`
    response.json({ success: true, data: billingInvoice(invoice) })
    return
  }
  if (endpoint === 'billing:dispute') {
    const invoice = mockBillingInvoices.find(
      (item) => item.id === request.body.id,
    )
    if (
      !invoice ||
      invoice.direction !== 'inbox' ||
      invoice.status !== 'open'
    ) {
      response.json({ success: false, error: 'dispute_unavailable' })
      return
    }
    invoice.status = 'disputed'
    invoice.isUnread = false
    response.json({ success: true, data: billingInvoice(invoice) })
    return
  }
  if (endpoint === 'garage:vehicles') {
    response.json({
      success: true,
      data: {
        valet: {
          account: 'bank',
          enabled: true,
          price: 750,
          vehicleTypes: {
            bike: true,
            boat: false,
            car: true,
            helicopter: false,
            plane: false,
          },
        },
        vehicles: mockGarageVehicles,
      },
    })
    return
  }
  if (endpoint === 'housing:overview') {
    response.json({
      success: true,
      data:
        testScenario === 'house-empty'
          ? { ...mockHousingOverview, properties: [] }
          : mockHousingOverview,
    })
    return
  }
  if (endpoint === 'housing:key-candidates') {
    const property = mockHousingOverview.properties.find(
      (item) => item.id === request.body.propertyId,
    )
    const existingNames = new Set((property?.keys ?? []).map((key) => key.name))
    response.json({
      success: true,
      data: {
        candidates: mockHousingCandidates.filter(
          (candidate) => !existingNames.has(candidate.name),
        ),
      },
    })
    return
  }
  if (endpoint === 'housing:command') {
    const property = mockHousingOverview.properties.find(
      (item) => item.id === request.body.propertyId,
    )
    if (!property) {
      response.json({ success: false, error: 'property_not_found' })
      return
    }
    if (request.body.action === 'toggle_lock') {
      property.locked = !property.locked
    }
    if (request.body.action === 'grant_key') {
      const candidate = mockHousingCandidates.find(
        (item) => item.id === Number(request.body.target),
      )
      if (!candidate || !property.capabilities.keys) {
        response.json({ success: false, error: 'target_not_found' })
        return
      }
      property.keys ??= []
      if (!property.keys.some((key) => key.name === candidate.name)) {
        property.keys.push({
          identifier: `mock-player:${candidate.id}`,
          name: candidate.name,
          online: true,
        })
      }
    }
    if (request.body.action === 'revoke_key') {
      property.keys = (property.keys ?? []).filter(
        (key) =>
          key.identifier !== request.body.identifier || key.revocable === false,
      )
    }
    response.json({ success: true, data: { accepted: true } })
    return
  }
  if (endpoint === 'garage:valet-state') {
    response.json({ success: true, data: mockGarageValet })
    return
  }
  if (endpoint === 'garage:valet-request') {
    const vehicle = mockGarageVehicles.find(
      (item) => item.plate === request.body.plate,
    )
    if (!vehicle || vehicle.status !== 'garaged') {
      response.json({ success: false, error: 'vehicle_not_garaged' })
      return
    }
    if (!['car', 'bike'].includes(vehicle.kind)) {
      response.json({ success: false, error: 'valet_vehicle_type' })
      return
    }
    mockGarageValet = {
      canCancel: true,
      cost: 750,
      distance: 1240,
      etaSeconds: 62,
      orderId: 'mock-valet-1',
      plate: vehicle.plate,
      status: 'en_route',
      vehicleName: vehicle.nickname || vehicle.name,
    }
    response.json({ success: true, data: mockGarageValet })
    return
  }
  if (endpoint === 'garage:valet-cancel') {
    mockGarageValet = null
    response.json({ success: true, data: null })
    return
  }
  if (endpoint === 'banking:transfer') {
    const amount = Number(request.body.amount)
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    if (mockBankBalance < amount) {
      response.json({ success: false, error: 'insufficient_funds' })
      return
    }
    const kind = 'transfer_out'
    mockBankBalance -= amount
    mockBankTransactions.unshift({
      amount,
      createdAt: Date.now(),
      id: nextBankTransactionId++,
      kind,
      label: kind === 'transfer_out' ? `Player #${request.body.target}` : '',
      reference: `mock-${Date.now()}`,
    })
    response.json({ success: true, data: bankingOverview() })
    return
  }
  if (endpoint === 'weather:get') {
    const weatherScenario = {
      'weather-fog': 'fog',
      'weather-rain': 'rain',
      'weather-snow': 'snow',
      'weather-sunny': 'sunny',
      'weather-thunder': 'thunder',
    }[testScenario]
    response.json({
      success: true,
      data: {
        clock: { year: 2026, month: 8, day: 5, hour: 17, minute: 20 },
        condition: weatherScenario ?? 'partly_cloudy',
        nextCondition: weatherScenario ?? 'rain',
        rainLevel:
          weatherScenario === 'rain' || weatherScenario === 'thunder'
            ? 0.82
            : 0.08,
        region: 'los_santos',
        windSpeed: weatherScenario === 'rain' ? 0 : 3.2,
      },
    })
    return
  }
  if (endpoint === 'map:getPlayerCoords') {
    response.json({
      success: true,
      data: { coords: { x: -75.2, y: -818.9, z: 326.2 } },
    })
    return
  }

  if (endpoint === 'map:setWaypoint') {
    response.json({ success: true })
    return
  }
  if (endpoint === 'map:markers') {
    response.json({ success: true, data: mockMapMarkers })
    return
  }
  if (endpoint === 'map:create-marker') {
    const label = String(request.body.label ?? '').trim()
    const color = String(request.body.color ?? '')
    const coords = request.body.coords
    if (!label || label.length > 40 || !coords) {
      response.json({ success: false, error: 'invalid_marker' })
      return
    }
    const marker = {
      color,
      coords: {
        x: Number(coords.x),
        y: Number(coords.y),
        z: Number(coords.z) || 0,
      },
      id: `mock-map-marker-${Date.now()}`,
      label,
    }
    mockMapMarkers.push(marker)
    response.json({ success: true, data: marker })
    return
  }
  if (endpoint === 'map:delete-marker') {
    const previousLength = mockMapMarkers.length
    mockMapMarkers = mockMapMarkers.filter(
      (marker) => marker.id !== request.body.id,
    )
    response.json(
      mockMapMarkers.length === previousLength
        ? { success: false, error: 'marker_not_found' }
        : { success: true },
    )
    return
  }
  if (endpoint === 'darkchat:bootstrap') {
    response.json({ success: true, data: darkChatBootstrap() })
    return
  }
  if (endpoint === 'darkchat:create-profile') {
    darkChatProfileActive = true
    response.json({ success: true, data: darkChatBootstrap() })
    return
  }
  if (endpoint === 'darkchat:delete-profile') {
    darkChatProfileActive = false
    response.json({ success: true })
    return
  }
  if (endpoint === 'darkchat:update-profile') {
    darkChatProfile.alias = String(
      request.body.alias ?? darkChatProfile.alias,
    ).trim()
    darkChatProfile.notificationMode =
      request.body.notificationMode ?? 'private'
    darkChatProfile.activityVisible = Boolean(request.body.activityVisible)
    response.json({ success: true, data: darkChatProfile })
    return
  }
  if (endpoint === 'darkchat:start') {
    const identifier = String(request.body.identifier ?? '').toUpperCase()
    const peer =
      darkChatPeers.find((item) => item.darkId.toUpperCase() === identifier) ??
      (identifier === 'DC-ECH0-77LM' ? darkChatPeers[1] : null)
    if (!peer) {
      response.json({ success: false, error: 'profile_not_found' })
      return
    }
    let conversation = darkChatConversations.find(
      (item) => item.peer.id === peer.id,
    )
    if (!conversation) {
      conversation = {
        id: `dc-conversation-${Date.now()}`,
        peer,
        disappearingSeconds: 0,
        notificationsEnabled: true,
        readReceipts: true,
        blockedByPeer: false,
        createdAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
      }
      darkChatConversations.push(conversation)
    }
    response.json({ success: true, data: { conversationId: conversation.id } })
    return
  }
  if (endpoint === 'darkchat:thread') {
    const conversation = darkChatConversations.find(
      (item) => item.id === request.body.conversationId,
    )
    if (!conversation) {
      response.json({ success: false, error: 'conversation_not_found' })
      return
    }
    const thread = darkChatMessages.filter(
      (message) => message.conversationId === conversation.id,
    )
    for (const message of thread) {
      if (message.direction === 'received')
        message.readAt = message.readAt ?? new Date().toISOString()
    }
    response.json({
      success: true,
      data: {
        conversation,
        messages: thread.map(({ mediaSecret, ...message }) => message),
      },
    })
    return
  }
  if (endpoint === 'darkchat:send') {
    const conversation = darkChatConversations.find(
      (item) => item.id === request.body.conversationId,
    )
    if (!conversation || conversation.peer.blocked) {
      response.json({
        success: false,
        error: conversation ? 'blocked' : 'conversation_not_found',
      })
      return
    }
    const messageType = request.body.messageType ?? 'text'
    const body = String(request.body.body ?? '')
    if (
      ((messageType === 'text' || messageType === 'emoji') && !body.trim()) ||
      (messageType === 'share' && !request.body.sharePayload)
    ) {
      response.json({ success: false, error: 'invalid_message' })
      return
    }
    const reply = darkChatMessages.find(
      (message) => message.id === request.body.replyToId,
    )
    const message = {
      id: `dc-message-${Date.now()}`,
      conversationId: conversation.id,
      direction: 'sent',
      senderProfileId: darkChatProfile.id,
      messageType,
      body:
        messageType === 'share'
          ? body.trim() || request.body.sharePayload.title
          : body,
      mediaPayload:
        messageType === 'gif' ? request.body.mediaPayload : undefined,
      mediaSecret:
        messageType === 'voice' ? request.body.mediaPayload : undefined,
      mediaMime: request.body.mediaMime,
      mediaDurationMs: request.body.mediaDurationMs,
      mediaWaveform: request.body.mediaWaveform,
      replyToId: request.body.replyToId,
      replyBody: reply?.body,
      reactions: {},
      sharePayload: messageType === 'share' ? request.body.sharePayload : null,
      createdAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
      readAt: null,
    }
    darkChatMessages.push(message)
    const { mediaSecret, ...publicMessage } = message
    response.json({ success: true, data: publicMessage })
    return
  }
  if (endpoint === 'darkchat:media') {
    const message = darkChatMessages.find(
      (item) =>
        item.id === request.body.messageId && item.messageType === 'voice',
    )
    response.json(
      message?.mediaSecret
        ? {
            success: true,
            data: { mime: message.mediaMime, payload: message.mediaSecret },
          }
        : { success: false, error: 'message_not_found' },
    )
    return
  }
  if (endpoint === 'darkchat:react') {
    const message = darkChatMessages.find(
      (item) => item.id === request.body.messageId,
    )
    if (message) {
      const current = message.reactions[String(darkChatProfile.id)]
      if (current === request.body.reaction)
        delete message.reactions[String(darkChatProfile.id)]
      else message.reactions[String(darkChatProfile.id)] = request.body.reaction
    }
    response.json({
      success: Boolean(message),
      error: message ? undefined : 'message_not_found',
    })
    return
  }
  if (endpoint === 'darkchat:message-action') {
    const index = darkChatMessages.findIndex(
      (item) => item.id === request.body.messageId,
    )
    if (index >= 0 && request.body.action === 'delete_me')
      darkChatMessages.splice(index, 1)
    else if (index >= 0 && request.body.action === 'delete_all') {
      darkChatMessages[index].messageType = 'system'
      darkChatMessages[index].body = 'message_deleted'
      darkChatMessages[index].mediaPayload = undefined
    }
    response.json({ success: index >= 0 })
    return
  }
  if (endpoint === 'darkchat:update-conversation') {
    const conversation = darkChatConversations.find(
      (item) => item.id === request.body.conversationId,
    )
    if (conversation) {
      conversation.disappearingSeconds = Number(
        request.body.disappearingSeconds,
      )
      conversation.notificationsEnabled = Boolean(
        request.body.notificationsEnabled,
      )
      conversation.readReceipts = Boolean(request.body.readReceipts)
      darkChatMessages.push({
        id: `dc-system-${Date.now()}`,
        conversationId: conversation.id,
        direction: 'received',
        messageType: 'system',
        body: `timer_changed:${conversation.disappearingSeconds}`,
        reactions: {},
        createdAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
      })
    }
    response.json({ success: Boolean(conversation) })
    return
  }
  if (
    endpoint === 'darkchat:add-contact' ||
    endpoint === 'darkchat:remove-contact'
  ) {
    const conversation = darkChatConversations.find(
      (item) => item.id === request.body.conversationId,
    )
    if (conversation) {
      conversation.peer.isContact = endpoint === 'darkchat:add-contact'
      if (request.body.alias)
        conversation.peer.alias = String(request.body.alias)
    }
    response.json({ success: Boolean(conversation) })
    return
  }
  if (endpoint === 'darkchat:block') {
    const conversation = darkChatConversations.find(
      (item) => item.id === request.body.conversationId,
    )
    if (conversation) conversation.peer.blocked = Boolean(request.body.blocked)
    response.json({ success: Boolean(conversation) })
    return
  }
  if (endpoint === 'darkchat:clear') {
    for (let index = darkChatMessages.length - 1; index >= 0; index -= 1) {
      if (
        darkChatMessages[index].conversationId === request.body.conversationId
      )
        darkChatMessages.splice(index, 1)
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'darkchat:report') {
    response.json({ success: true })
    return
  }
  if (endpoint === 'messages:conversations') {
    const grouped = new Map()
    for (const message of [...smsMessages].reverse()) {
      const phoneNumber =
        message.direction === 'sent'
          ? message.recipient_number
          : message.sender_number
      const conversation = grouped.get(phoneNumber)
      if (conversation) {
        if (message.direction === 'received' && !message.read_at)
          conversation.unread += 1
        continue
      }
      grouped.set(phoneNumber, {
        lastMessage: message.body,
        lastMessageAt: message.created_at,
        lastMessageType: message.message_type,
        phoneNumber,
        unread: message.direction === 'received' && !message.read_at ? 1 : 0,
      })
    }
    response.json({ success: true, data: [...grouped.values()] })
    return
  }
  if (endpoint === 'easyshare:bootstrap') {
    const history = easyShareHistoryForScenario(testScenario)
    response.json({
      success: true,
      data: {
        history,
        pending: history.filter((item) =>
          ['pending', 'transferring'].includes(item.status),
        ),
        targets: testScenario === 'easyshare-empty' ? [] : easyShareTargets,
        visibility: easyShareVisibility,
      },
    })
    return
  }
  if (endpoint === 'easyshare:own-contact') {
    response.json({
      success: true,
      data: {
        appId: 'phone',
        copyText: 'Alex Morgan\n5551234567',
        id: 'self',
        kind: 'contact',
        meta: { name: 'Alex Morgan', phoneNumber: '5551234567' },
        subtitle: '5551234567',
        title: 'Alex Morgan',
      },
    })
    return
  }
  if (endpoint === 'easyshare:set-visibility') {
    easyShareVisibility = request.body.visibility
    response.json({ success: true, data: { visibility: easyShareVisibility } })
    return
  }
  if (endpoint === 'easyshare:request') {
    const target = easyShareTargets.find(
      (candidate) => candidate.id === Number(request.body.targetId),
    )
    const transfer = {
      createdAt: Date.now(),
      direction: 'outgoing',
      id: `easyshare-${Date.now()}`,
      otherName: target?.name ?? 'Unknown device',
      payload: request.body.payload,
      progress: target?.id === 72 ? 58 : 0,
      status: target?.id === 72 ? 'transferring' : 'pending',
    }
    easyShareHistory.unshift(transfer)
    response.json({ success: true, data: transfer })
    return
  }
  if (endpoint === 'easyshare:respond' || endpoint === 'easyshare:cancel') {
    const transfer = easyShareHistory.find(
      (item) => item.id === request.body.id,
    )
    if (!transfer) {
      response.json({ success: false, error: 'transfer_not_found' })
      return
    }
    transfer.status =
      endpoint === 'easyshare:cancel'
        ? 'cancelled'
        : request.body.accepted
          ? 'completed'
          : 'declined'
    transfer.progress =
      transfer.status === 'completed' ? 100 : transfer.progress
    response.json({ success: true, data: transfer })
    return
  }
  if (endpoint === 'messages:gifs') {
    const offset = Math.max(0, Number(request.body.offset ?? 0))
    const pageSize = 6
    const results = gifMocks
      .slice(offset, offset + pageSize)
      .map(([id, title]) => ({
        height: 200,
        id,
        previewUrl: `https://media.giphy.com/media/${id}/200w.gif`,
        title,
        url: `https://media.giphy.com/media/${id}/giphy.gif`,
        width: 200,
      }))
    response.json({
      success: true,
      data: {
        hasMore: offset + results.length < gifMocks.length,
        nextOffset: offset + results.length,
        results,
      },
    })
    return
  }
  if (endpoint === 'development:bootstrap') {
    if (testScenario === 'skypic-onboarding') {
      skyPicOnboardingProfile = null
    }
    cryptoRegistered = testScenario !== 'crypto-register'
    cryptoAuthenticated = !['crypto-login', 'crypto-register'].includes(
      testScenario,
    )
    crewLinkAuthenticated = !['crewlink-login', 'crewlink-register'].includes(
      testScenario,
    )
    authenticated = testScenario !== 'setup-account-unlinked'
    linkedAccount = authenticated
      ? {
          devices: accountDevices,
          email: 'demo@ifruit.com',
          id: 1,
        }
      : null
    if (
      testScenario === 'feather-onboarding' ||
      testScenario === 'feather-register'
    )
      featherOnboarded = false
    else featherOnboarded = true
    pagesOnboardingCompleted = ![
      'local-pages-onboarding',
      'local-pages-register',
      'citymarkt-local-pages-account-missing',
    ].includes(testScenario)
    if (testScenario === 'crewlink-register') {
      crewLinkProfile = null
    } else {
      crewLinkProfile = {
        activeGroupId: 'crewlink-group-night-shift',
        avatarMediaId: 1,
        avatarUrl: 'https://picsum.photos/seed/crewlink-skyline/240/240',
        id: 'crewlink-profile-skyline',
        mapVisible: true,
        overheadVisible: false,
        username: 'Skyline',
      }
    }
    if (testScenario === 'citymarkt-register') {
      marketplaceProfile = {
        avatar_media_id: null,
        avatar_url: null,
        bio: '',
        display_name: '',
        email: linkedAccount?.email ?? 'demo@ifruit.com',
        exists: false,
        listing_count: 0,
      }
    } else {
      marketplaceProfile = {
        avatar_media_id: 1,
        avatar_url: 'https://picsum.photos/seed/citymarkt-demo-avatar/240/240',
        bio: 'Fair prices, quick replies, and meetups anywhere in Los Santos.',
        display_name: 'Skyline Deals',
        email: linkedAccount?.email ?? 'demo@ifruit.com',
        exists: true,
        listing_count: marketplaceListings.filter(
          (listing) => listing.seller_account_id === 1,
        ).length,
      }
    }
    const bootstrapDeviceData =
      testScenario === 'easyshare-full' && !deviceData.apps?.payload?.homeLayout
        ? {
            ...deviceData,
            apps: {
              ...deviceData.apps,
              payload: {
                ...deviceData.apps.payload,
                homeLayout: {
                  dock: ['phone', 'messages', 'camera', 'clock'],
                  grid: [
                    {
                      apps: [
                        'mail',
                        'notes',
                        'photos',
                        'app-store',
                        'settings',
                        'map',
                        'citymarkt',
                        'local-pages',
                        'calendar',
                        'darkchat',
                      ],
                      id: 'folder-browser-demo-123456',
                      name: 'Los Santos',
                      type: 'folder',
                    },
                    'banking',
                    'weather',
                    'billing',
                  ],
                  hidden: [],
                  version: 5,
                },
              },
            },
          }
        : testScenario === ''
          ? {
              ...deviceData,
              apps: {
                ...deviceData.apps,
                payload: {
                  claimedApps: [...demoInstalledAppIds],
                },
              },
              settings: {
                ...deviceData.settings,
                payload: {
                  ...deviceData.settings.payload,
                  settings: {
                    ...deviceData.settings.payload.settings,
                    lockWallpaper: 'custom',
                    lockWallpaperImageUrl: demoWallpaperUrl,
                    wallpaper: 'custom',
                    wallpaperHistory: [
                      { imageUrl: demoWallpaperUrl, wallpaper: 'custom' },
                    ],
                    wallpaperImageUrl: demoWallpaperUrl,
                  },
                },
              },
            }
          : deviceData
    response.json({
      success: true,
      data: {
        account: linkedAccount,
        device: {
          data:
            testScenario.startsWith('citymarkt-') ||
            testScenario.startsWith('feather-') ||
            testScenario.startsWith('local-pages-') ||
            testScenario.startsWith('crewlink-') ||
            testScenario.startsWith('skypic-')
              ? {
                  ...deviceData,
                  apps: {
                    ...deviceData.apps,
                    payload: {
                      ...deviceData.apps.payload,
                      homeLayout: {
                        dock: [],
                        grid: testScenario.startsWith('crewlink-')
                          ? ['crewlink']
                          : testScenario.startsWith('skypic-')
                            ? ['skypic']
                            : testScenario === 'citymarkt-local-pages-missing'
                              ? ['citymarkt']
                              : ['citymarkt', 'local-pages'],
                        hidden:
                          testScenario === 'citymarkt-local-pages-missing'
                            ? ['local-pages']
                            : [],
                        version: 4,
                      },
                    },
                  },
                  appAuth: [
                    'citymarkt-login',
                    'citymarkt-register',
                    'feather-login',
                    'feather-register',
                    'local-pages-login',
                    'local-pages-register',
                    'crewlink-login',
                    'crewlink-register',
                    'skypic-onboarding',
                  ].includes(testScenario)
                    ? {
                        payload: {
                          accountEmail: linkedAccount?.email ?? '',
                          signedIn: testScenario.startsWith('feather-')
                            ? ['citymarkt', 'local-pages', 'crewlink', 'skypic']
                            : testScenario.startsWith('local-pages-')
                              ? ['citymarkt', 'feather', 'crewlink', 'skypic']
                              : testScenario.startsWith('crewlink-')
                                ? [
                                    'citymarkt',
                                    'local-pages',
                                    'feather',
                                    'skypic',
                                  ]
                                : testScenario.startsWith('skypic-')
                                  ? [
                                      'citymarkt',
                                      'local-pages',
                                      'feather',
                                      'crewlink',
                                    ]
                                  : [
                                      'local-pages',
                                      'feather',
                                      'crewlink',
                                      'skypic',
                                    ],
                          version: 1,
                        },
                        revision: deviceData.appAuth?.revision ?? 0,
                      }
                    : deviceData.appAuth,
                }
              : bootstrapDeviceData,
          imei: '356938035643809',
          name: 'Personal iFruit Phone',
          sim: mockSim,
        },
        memos: mockMemos,
        notes: mockNotes,
        player: {
          firstName: 'Alex',
          lastName: 'Morgan',
        },
        security: mockSecurity,
        token: 'development',
      },
    })
    return
  }
  if (endpoint === 'messages:thread') {
    const number = String(request.body.phoneNumber)
    const thread = smsMessages.filter(
      (message) =>
        message.sender_number === number || message.recipient_number === number,
    )
    for (const message of thread) {
      if (message.direction === 'received')
        message.read_at = message.read_at ?? '2026-08-06 13:06:00'
    }
    response.json({
      success: true,
      data: thread.map(({ media_payload, ...message }) => ({
        ...message,
        contact: message.message_type === 'contact' ? media_payload : null,
        share: message.message_type === 'share' ? media_payload : null,
        media_asset_id: ['image', 'gif', 'video'].includes(message.message_type)
          ? media_payload
          : null,
      })),
    })
    return
  }
  if (endpoint === 'messages:media') {
    const message = smsMessages.find(
      (item) => item.id === request.body.id && item.message_type === 'voice',
    )
    response.json(
      message
        ? {
            success: true,
            data: {
              mime: message.media_mime,
              payload: message.media_payload,
            },
          }
        : { success: false, error: 'message_not_found' },
    )
    return
  }
  if (endpoint === 'messages:send') {
    const body = String(request.body.body ?? '').trim()
    const phoneNumber = String(request.body.phoneNumber ?? '')
    const messageType = request.body.messageType ?? 'text'
    const isAttachment = ['image', 'gif', 'video'].includes(messageType)
    const selectedContact =
      messageType === 'contact'
        ? contacts.find((contact) => contact.id === request.body.contactId)
        : null
    const requestedAttachmentId = String(request.body.mediaAssetId ?? '')
    const selectedMedia = /^\d+$/.test(requestedAttachmentId)
      ? mockMedia.find((item) => String(item.id) === requestedAttachmentId)
      : null
    const attachmentId = selectedMedia?.url ?? requestedAttachmentId
    if (
      !phoneNumber ||
      (messageType === 'text' && !body) ||
      (messageType === 'voice' && !request.body.mediaPayload) ||
      (messageType === 'contact' && !selectedContact) ||
      (messageType === 'share' && !request.body.sharePayload) ||
      (isAttachment && body.length > 2000) ||
      (isAttachment &&
        !attachmentAssets[messageType].has(attachmentId) &&
        !attachmentId.startsWith('https://') &&
        !attachmentId.startsWith('data:image/'))
    ) {
      response.json({ success: false, error: 'invalid_message' })
      return
    }
    const message = {
      body:
        selectedContact?.name ??
        (messageType === 'share'
          ? body || request.body.sharePayload.title
          : body),
      contact: selectedContact
        ? {
            avatar_url: selectedContact.avatar_url ?? null,
            name: selectedContact.name,
            organization: selectedContact.organization ?? null,
            phone_number: selectedContact.phone_number,
          }
        : null,
      created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      direction: 'sent',
      id: `sms-${Date.now()}-${smsSequence++}`,
      media_duration_ms: ['voice', 'video'].includes(messageType)
        ? (request.body.mediaDurationMs ?? null)
        : null,
      media_mime:
        messageType === 'voice'
          ? request.body.mediaMime
          : messageType === 'image'
            ? 'image/jpeg'
            : messageType === 'gif'
              ? 'image/gif'
              : messageType === 'video'
                ? 'video/webm'
                : null,
      media_payload:
        messageType === 'voice'
          ? request.body.mediaPayload
          : selectedContact
            ? {
                avatar_url: selectedContact.avatar_url ?? null,
                name: selectedContact.name,
                organization: selectedContact.organization ?? null,
                phone_number: selectedContact.phone_number,
              }
            : messageType === 'share'
              ? request.body.sharePayload
              : isAttachment
                ? attachmentId
                : null,
      media_waveform:
        messageType === 'voice' ? request.body.mediaWaveform : null,
      message_type: messageType,
      media_asset_id: isAttachment ? attachmentId : null,
      read_at: null,
      recipient_number: phoneNumber,
      sender_number: '5551234567',
      share: messageType === 'share' ? request.body.sharePayload : null,
    }
    smsMessages.push(message)
    const { media_payload, ...publicMessage } = message
    response.json({ success: true, data: publicMessage })
    return
  }
  if (endpoint === 'messages:delete') {
    const phoneNumbers = new Set(
      Array.isArray(request.body.phoneNumbers)
        ? request.body.phoneNumbers.map(String)
        : [],
    )
    for (let index = smsMessages.length - 1; index >= 0; index -= 1) {
      const message = smsMessages[index]
      const otherNumber =
        message.direction === 'sent'
          ? message.recipient_number
          : message.sender_number
      if (phoneNumbers.has(otherNumber)) smsMessages.splice(index, 1)
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'contacts:list') {
    response.json({ success: true, data: contacts })
    return
  }
  if (endpoint === 'contacts:save') {
    const name = String(request.body.name ?? '').trim()
    let email = String(request.body.email ?? '')
      .trim()
      .toLowerCase()
    if (email && !email.includes('@')) email = `${email}@ifruit.com`
    const emailLocalPart = email.match(
      /^([a-z0-9][a-z0-9._-]*[a-z0-9])@ifruit\.com$/,
    )?.[1]
    const emailValid =
      !email ||
      (Boolean(emailLocalPart) &&
        emailLocalPart.length >= 3 &&
        emailLocalPart.length <= 32 &&
        !emailLocalPart.includes('..'))
    const notes = String(request.body.notes ?? '')
      .trim()
      .slice(0, 500)
    const organization = String(request.body.organization ?? '')
      .trim()
      .slice(0, 80)
    const phoneNumber = String(request.body.phoneNumber ?? '').trim()
    const avatarMediaId = Number(request.body.avatarMediaId) || 0
    const avatarMedia = avatarMediaId
      ? mockMedia.find(
          (item) => item.id === avatarMediaId && item.mediaType === 'photo',
        )
      : null
    if (
      !name ||
      !phoneNumber ||
      !emailValid ||
      (avatarMediaId && !avatarMedia)
    ) {
      response.json({ success: false, error: 'invalid_contact' })
      return
    }
    let contact = contacts.find((item) => item.id === request.body.id)
    if (contact?.readonly) {
      response.json({ success: false, error: 'readonly_contact' })
      return
    }
    if (contact) {
      contact.name = name
      contact.email = email || null
      contact.notes = notes || null
      contact.organization = organization || null
      contact.phone_number = phoneNumber
      contact.avatar_media_id = avatarMedia?.id ?? null
      contact.avatar_url = avatarMedia?.url ?? null
      contact.updated_at = new Date()
        .toISOString()
        .slice(0, 19)
        .replace('T', ' ')
    } else {
      const now = new Date().toISOString().slice(0, 19).replace('T', ' ')
      contact = {
        created_at: now,
        favorite: false,
        email: email || null,
        id: `contact-${contactSequence++}`,
        name,
        notes: notes || null,
        organization: organization || null,
        phone_number: phoneNumber,
        avatar_media_id: avatarMedia?.id ?? null,
        avatar_url: avatarMedia?.url ?? null,
        updated_at: now,
      }
      contacts.push(contact)
    }
    response.json({ success: true, data: contact })
    return
  }
  if (endpoint === 'contacts:favorite') {
    const contact = contacts.find((item) => item.id === request.body.id)
    if (!contact || typeof request.body.favorite !== 'boolean') {
      response.json({ success: false, error: 'contact_not_found' })
      return
    }
    contact.favorite = request.body.favorite
    contact.updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ')
    response.json({
      success: true,
      data: { favorite: contact.favorite, id: contact.id },
    })
    return
  }
  if (endpoint === 'contacts:delete') {
    const index = contacts.findIndex((item) => item.id === request.body.id)
    if (index >= 0 && contacts[index].readonly) {
      response.json({ success: false, error: 'readonly_contact' })
      return
    }
    if (index >= 0) contacts.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint === 'media:config') {
    response.json({ success: true, data: { videoBitrateKbps: 1500 } })
    return
  }
  if (endpoint === 'media:devCapture') {
    const mediaType = request.body.mediaType === 'video' ? 'video' : 'photo'
    const id = Math.max(0, ...mockMedia.map((item) => Number(item.id) || 0)) + 1
    const fallbackVideo = mockMedia.find((item) => item.mediaType === 'video')
    const media = {
      createdAt: Date.now(),
      favorite: false,
      id,
      mediaType,
      url:
        mediaType === 'photo'
          ? `https://picsum.photos/seed/sky-camera-${id}/900/1600`
          : fallbackVideo?.url,
    }
    if (!media.url) {
      response.json({ success: false, error: 'unsupported' })
      return
    }
    mockMedia.unshift(media)
    response.json({ success: true, data: media })
    return
  }
  if (endpoint === 'media:import:sources') {
    response.json({
      success: true,
      data: { maxSelection: 10, sources: mockImportSources },
    })
    return
  }
  if (endpoint === 'media:import:list') {
    const page = Math.max(1, Number(request.body.page) || 1)
    const limit = 30
    const filtered = mockImportMedia.filter(
      (item) =>
        item.sourceId === request.body.sourceId &&
        item.mediaType === request.body.mediaType,
    )
    const offset = (page - 1) * limit
    response.json({
      success: true,
      data: {
        hasMore: offset + limit < filtered.length,
        items: filtered.slice(offset, offset + limit),
        page,
        total: filtered.length,
      },
    })
    return
  }
  if (endpoint === 'media:import:commit') {
    const externalIds = Array.isArray(request.body.externalIds)
      ? request.body.externalIds
      : []
    const imported = []
    const failed = []
    for (const externalId of externalIds) {
      const item = mockImportMedia.find(
        (candidate) =>
          candidate.externalId === externalId &&
          candidate.sourceId === request.body.sourceId,
      )
      if (!item) {
        failed.push({ error: 'import_media_unavailable', externalId })
        continue
      }
      item.imported = true
      const media = {
        createdAt: Date.now(),
        id: Math.max(0, ...mockMedia.map((entry) => Number(entry.id) || 0)) + 1,
        mediaType: item.mediaType,
        url: item.url,
      }
      mockMedia.unshift(media)
      imported.push(media)
    }
    response.json({ success: true, data: { failed, imported } })
    return
  }
  if (endpoint === 'media:import:url') {
    const url = String(request.body.url || '').trim()
    if (!url.startsWith('https://')) {
      response.json({ success: false, error: 'invalid_import_url' })
      return
    }
    const mediaType = /\.(mp4|webm)(?:[?#]|$)/i.test(url) ? 'video' : 'photo'
    const media = {
      createdAt: Date.now(),
      id: Math.max(0, ...mockMedia.map((entry) => Number(entry.id) || 0)) + 1,
      mediaType,
      url,
    }
    mockMedia.unshift(media)
    response.json({ success: true, data: media })
    return
  }
  if (endpoint === 'gallery:counts') {
    response.json({
      success: true,
      data: {
        all: mockMedia.length,
        favoritePhotos: mockMedia.filter(
          (item) => item.mediaType === 'photo' && item.favorite,
        ).length,
        favorites: mockMedia.filter((item) => item.favorite).length,
        favoriteVideos: mockMedia.filter(
          (item) => item.mediaType === 'video' && item.favorite,
        ).length,
        photos: mockMedia.filter((item) => item.mediaType === 'photo').length,
        videos: mockMedia.filter((item) => item.mediaType === 'video').length,
      },
    })
    return
  }
  if (endpoint === 'gallery:list') {
    if (request.body.mockState === 'error') {
      response.json({ success: false, error: 'service_unavailable' })
      return
    }
    if (request.body.mockState === 'empty') {
      response.json({ success: true, data: [] })
      return
    }
    const typeFiltered = request.body.mediaType
      ? mockMedia.filter((item) => item.mediaType === request.body.mediaType)
      : mockMedia
    const filtered = request.body.favoriteOnly
      ? typeFiltered.filter((item) => item.favorite)
      : typeFiltered
    const offset = Number(request.body.offset) || 0
    const limit = Number(request.body.limit) || 30
    response.json({
      success: true,
      data: filtered.slice(offset, offset + limit),
    })
    return
  }
  if (
    endpoint === 'media:requestUpload' ||
    endpoint === 'media:completeUpload' ||
    endpoint === 'media:failUpload' ||
    endpoint === 'media:cancelUpload'
  ) {
    response.json({ success: true })
    return
  }
  if (endpoint === 'gallery:delete') {
    const mediaId = Number(request.body.id)
    if (flarePhotoRemovalWouldEmptyProfile([mediaId])) {
      response.json({ success: false, error: 'profile_photo_required' })
      return
    }
    mockMedia = mockMedia.filter((item) => item.id !== mediaId)
    removeFlareProfilePhotos([mediaId])
    response.json({ success: true })
    return
  }
  if (endpoint === 'gallery:favorite') {
    const item = mockMedia.find((entry) => entry.id === Number(request.body.id))
    if (!item || typeof request.body.favorite !== 'boolean') {
      response.json({ success: false, error: 'media_not_found' })
      return
    }
    item.favorite = request.body.favorite
    response.json({
      success: true,
      data: { favorite: item.favorite, id: item.id },
    })
    return
  }
  if (endpoint === 'gallery:delete-many') {
    const ids = Array.isArray(request.body.ids)
      ? request.body.ids.map(Number).filter(Number.isInteger)
      : []
    const deletedIds = mockMedia
      .filter((item) => ids.includes(item.id))
      .map((item) => item.id)
    if (flarePhotoRemovalWouldEmptyProfile(deletedIds)) {
      response.json({ success: false, error: 'profile_photo_required' })
      return
    }
    mockMedia = mockMedia.filter((item) => !deletedIds.includes(item.id))
    removeFlareProfilePhotos(deletedIds)
    response.json({
      success: true,
      data: {
        correlationId: request.body.correlationId,
        deletedIds,
        success: true,
      },
    })
    return
  }
  if (endpoint === 'account:login' || endpoint === 'account:register') {
    authenticated = true
    linkedAccount = {
      devices: accountDevices,
      email: request.body.email.includes('@')
        ? request.body.email
        : `${request.body.email}@ifruit.com`,
      id: 1,
    }
    response.json({ success: true, data: linkedAccount })
    return
  }
  if (endpoint === 'account:logout') {
    authenticated = false
    linkedAccount = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'account:devices') {
    response.json({ success: true, data: accountDevices })
    return
  }
  if (endpoint === 'account:remove-device') {
    response.json({ success: true, data: accountDevices })
    return
  }
  if (endpoint === 'device:save') {
    const current = deviceData[request.body.namespace]
    const revision = (current?.revision ?? 0) + 1
    deviceData[request.body.namespace] = {
      payload: request.body.payload,
      revision,
    }
    response.json({ success: true, data: { revision } })
    return
  }
  if (endpoint === 'notifications:save') {
    const revision = (deviceData.notifications?.revision ?? 0) + 1
    deviceData.notifications = {
      payload: request.body.payload,
      revision,
    }
    response.json({ success: true, data: { revision } })
    return
  }
  if (endpoint === 'security:unlock') {
    response.json(
      !mockSecurity.enabled || request.body.passcode === mockPasscode
        ? { success: true, data: { security: mockSecurity } }
        : { success: false, error: 'invalid_passcode' },
    )
    return
  }
  if (endpoint === 'security:set-passcode') {
    mockPasscode = String(request.body.passcode)
    mockSecurity = {
      enabled: true,
      length: mockPasscode.length,
      lockedUntil: 0,
    }
    response.json({ success: true, data: { security: mockSecurity } })
    return
  }
  if (endpoint === 'security:change-passcode') {
    if (request.body.currentPasscode !== mockPasscode) {
      response.json({ success: false, error: 'invalid_passcode' })
      return
    }
    mockPasscode = String(request.body.newPasscode)
    mockSecurity = {
      enabled: true,
      length: mockPasscode.length,
      lockedUntil: 0,
    }
    response.json({ success: true, data: { security: mockSecurity } })
    return
  }
  if (endpoint === 'security:disable-passcode') {
    if (request.body.passcode !== mockPasscode) {
      response.json({ success: false, error: 'invalid_passcode' })
      return
    }
    mockPasscode = ''
    mockSecurity = { enabled: false, length: null, lockedUntil: 0 }
    response.json({ success: true, data: { security: mockSecurity } })
    return
  }
  if (endpoint === 'device:factory-reset') {
    authenticated = false
    linkedAccount = null
    mockMemos = []
    mockNotes = []
    mockMedia = []
    calendarEvents = []
    mockPasscode = ''
    mockSecurity = { enabled: false, length: null, lockedUntil: 0 }
    for (const key of Object.keys(deviceData)) delete deviceData[key]
    response.json({ success: true })
    return
  }
  if (endpoint === 'calls:recents') {
    response.json({ success: true, data: recentCalls })
    return
  }
  if (endpoint === 'calls:dial') {
    const phoneNumber = String(request.body.phoneNumber ?? '').replace(
      /\D/g,
      '',
    )
    if (phoneNumber.length !== 10) {
      response.json({ success: false, error: 'invalid_number' })
      return
    }
    if (!contacts.some((contact) => contact.phone_number === phoneNumber)) {
      response.json({ success: false, error: 'recipient_not_found' })
      return
    }
    const id = `call-${Date.now()}`
    const startedAt = Date.now()
    recentCalls.unshift({
      call_id: id,
      created_at: Date.now(),
      direction: 'outgoing',
      duration_seconds: 0,
      id: recentCalls.length + 1,
      other_number: phoneNumber,
      status: 'completed',
    })
    response.json({
      success: true,
      data: {
        direction: 'outgoing',
        id,
        otherNumber: phoneNumber,
        speakerEnabled: false,
        speakerSupported: true,
        startedAt,
        state: 'ringing',
      },
    })
    return
  }
  if (endpoint === 'calls:block') {
    const phoneNumber = String(request.body.phoneNumber ?? '').replace(
      /\D/g,
      '',
    )
    if (!phoneNumber) {
      response.json({ success: false, error: 'invalid_number' })
      return
    }
    blockedCallNumbers.add(phoneNumber)
    response.json({ success: true, data: { blocked: true, phoneNumber } })
    return
  }
  if (endpoint === 'calls:set-speaker') {
    response.json({
      success: true,
      data: { speakerEnabled: request.body.enabled === true },
    })
    return
  }
  if (
    endpoint === 'calls:answer' ||
    endpoint === 'calls:decline' ||
    endpoint === 'calls:hangup'
  ) {
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('calendar:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'calendar:list') {
    const startsAt = Number(request.body.startsAt) * 1000
    const endsAt = Number(request.body.endsAt) * 1000
    response.json({
      success: true,
      data: calendarEvents.filter(
        (event) => event.endsAt >= startsAt && event.startsAt < endsAt,
      ),
    })
    return
  }
  if (endpoint === 'calendar:create') {
    const id = `calendar-${Date.now()}`
    calendarEvents.push({
      ...request.body,
      endsAt: Number(request.body.endsAt) * 1000,
      id,
      remindedAt: null,
      revision: 1,
      startsAt: Number(request.body.startsAt) * 1000,
    })
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'calendar:update') {
    const index = calendarEvents.findIndex(
      (event) => event.id === request.body.id,
    )
    if (index < 0 || calendarEvents[index].revision !== request.body.revision) {
      response.json({ success: false, error: 'conflict' })
      return
    }
    calendarEvents[index] = {
      ...calendarEvents[index],
      ...request.body,
      endsAt: Number(request.body.endsAt) * 1000,
      remindedAt: null,
      revision: calendarEvents[index].revision + 1,
      startsAt: Number(request.body.startsAt) * 1000,
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'calendar:delete') {
    calendarEvents = calendarEvents.filter(
      (event) => event.id !== request.body.id,
    )
    response.json({ success: true })
    return
  }
  if (endpoint === 'pages:list') {
    const query = String(request.body.search ?? '').toLowerCase()
    let items = pagesPostsForScenario(testScenario)
    if (request.body.category && request.body.category !== 'all')
      items = items.filter((item) => item.category === request.body.category)
    if (query)
      items = items.filter((item) =>
        `${item.title} ${item.body}`.toLowerCase().includes(query),
      )
    if (request.body.saved)
      items = items.filter((post) =>
        pagesReactions.some(
          (reaction) =>
            reaction.post_id === post.id &&
            reaction.account_id === 1 &&
            reaction.kind === 'save',
        ),
      )
    response.json({
      success: true,
      data: { hasMore: false, items: items.map(pageView), offset: 0 },
    })
    return
  }
  if (endpoint === 'pages:get') {
    const post = pagesPostsForScenario(testScenario).find(
      (item) => item.id === request.body.id,
    )
    response.json(
      post
        ? { success: true, data: pageView(post) }
        : { success: false, error: 'post_not_found' },
    )
    return
  }
  if (endpoint.startsWith('pages:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'pages:profile') {
    const email = linkedAccount?.email ?? pagesProfile.email
    const onboarding =
      [
        'local-pages-onboarding',
        'local-pages-register',
        'citymarkt-local-pages-account-missing',
      ].includes(testScenario) && !pagesOnboardingCompleted
    response.json({
      success: true,
      data: {
        avatar_media_id: onboarding ? null : pagesProfile.avatar_media_id,
        avatar_url: onboarding ? null : pagesProfile.avatar_url,
        bio: onboarding ? '' : pagesProfile.bio,
        email,
        exists: onboarding ? false : pagesProfile.exists,
        handle: onboarding ? email.split('@')[0] : pagesProfile.handle,
        post_count: pagesPostsForScenario(testScenario).filter(
          (item) => item.account_id === 1,
        ).length,
      },
    })
    return
  }
  if (endpoint === 'pages:profile-save') {
    pagesOnboardingCompleted = true
    const avatarMediaId = Number(request.body.avatarMediaId) || 0
    const avatarMedia =
      avatarMediaId > 0
        ? mockMedia.find(
            (item) => item.id === avatarMediaId && item.mediaType === 'photo',
          )
        : null
    if (avatarMediaId > 0 && !avatarMedia) {
      response.json({ success: false, error: 'invalid_profile_image' })
      return
    }
    pagesProfile = {
      avatar_media_id: avatarMedia?.id ?? null,
      avatar_url: avatarMedia?.url ?? null,
      bio: String(request.body.bio ?? '').trim(),
      email: linkedAccount?.email ?? pagesProfile.email,
      exists: true,
      handle: String(request.body.handle ?? '')
        .trim()
        .toLowerCase(),
    }
    pagesPosts.forEach((post) => {
      if (post.account_id === 1) post.author_name = pagesProfile.handle
    })
    response.json({
      success: true,
      data: {
        ...pagesProfile,
        post_count: pagesPosts.filter((item) => item.account_id === 1).length,
      },
    })
    return
  }
  if (endpoint === 'pages:list-own') {
    response.json({
      success: true,
      data: {
        hasMore: false,
        items: pagesPostsForScenario(testScenario)
          .filter((item) => item.account_id === 1)
          .map(pageView),
        offset: 0,
      },
    })
    return
  }
  if (endpoint === 'pages:create') {
    const gradients = {
      'sunset-drive': 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
      'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
      'city-lights': 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
      'desert-road': 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)',
    }
    const id = `pages-${Date.now()}`
    const images = request.body.images.map((image, index) => ({
      media_id: image.id,
      gradient:
        gradients[image.id] ??
        'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
      sort_order: index + 1,
    }))
    pagesPosts.unshift({
      ...request.body,
      id,
      account_id: 1,
      author_name: pagesProfile.handle,
      source_type: 'personal',
      citymarkt_listing_id: null,
      created_at: new Date().toISOString(),
      like_count: 0,
      images,
    })
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'pages:share-citymarkt') {
    const listing = marketplaceListings.find(
      (item) =>
        item.id === request.body.listingId &&
        item.seller_account_id === 1 &&
        ['active', 'reserved'].includes(item.status),
    )
    if (!listing) {
      response.json({ success: false, error: 'citymarkt_not_found' })
      return
    }
    if (
      pagesPostsForScenario(testScenario).some(
        (item) => item.citymarkt_listing_id === listing.id,
      )
    ) {
      response.json({ success: false, error: 'citymarkt_already_shared' })
      return
    }
    if (
      pagesPosts.some(
        (item) =>
          item.account_id === 1 &&
          item.source_type === 'citymarkt' &&
          item.created_at.slice(0, 10) === '2026-08-06',
      )
    ) {
      response.json({ success: false, error: 'citymarkt_daily_limit' })
      return
    }
    const id = `pages-${Date.now()}`
    pagesPosts.unshift({
      id,
      account_id: 1,
      author_name: pagesProfile.handle,
      source_type: 'citymarkt',
      citymarkt_listing_id: listing.id,
      title: listing.title,
      body: listing.description,
      category: 'citymarkt',
      district: listing.district,
      created_at: '2026-08-06 13:30:00',
      like_count: 0,
      images: listing.images,
    })
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'pages:react') {
    const index = pagesReactions.findIndex(
      (item) =>
        item.post_id === request.body.id &&
        item.account_id === 1 &&
        item.kind === request.body.kind,
    )
    if (request.body.active && index < 0)
      pagesReactions.push({
        post_id: request.body.id,
        account_id: 1,
        kind: request.body.kind,
      })
    if (!request.body.active && index >= 0) pagesReactions.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint === 'pages:delete') {
    const index = pagesPosts.findIndex(
      (item) => item.id === request.body.id && item.account_id === 1,
    )
    if (index < 0) {
      response.json({ success: false, error: 'post_not_found' })
      return
    }
    pagesPosts.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:list') {
    const query = String(request.body.search ?? '').toLowerCase()
    let items = marketplaceListings.filter((item) =>
      ['active', 'reserved'].includes(item.status),
    )
    if (request.body.category && request.body.category !== 'all')
      items = items.filter((item) => item.category === request.body.category)
    if (request.body.district && request.body.district !== 'all')
      items = items.filter((item) => item.district === request.body.district)
    if (query)
      items = items.filter((item) =>
        `${item.title} ${item.description}`.toLowerCase().includes(query),
      )
    if (request.body.favorites) items = items.filter((item) => item.is_favorite)
    response.json({ success: true, data: { hasMore: false, items, offset: 0 } })
    return
  }
  if (endpoint === 'marketplace:get') {
    const item = marketplaceListings.find(
      (listing) => listing.id === request.body.id,
    )
    response.json(
      item
        ? {
            success: true,
            data: {
              ...item,
              is_owner: authenticated && item.seller_account_id === 1,
            },
          }
        : { success: false, error: 'listing_not_found' },
    )
    return
  }
  if (endpoint === 'marketplace:auth') {
    const password = String(request.body.password ?? '')
    if (password.length < 6 || password.length > 64) {
      response.json({
        success: false,
        error:
          request.body.mode === 'register'
            ? 'invalid_password'
            : 'invalid_credentials',
      })
      return
    }
    if (request.body.mode === 'login') {
      response.json(
        marketplaceProfile.exists
          ? { success: true, data: marketplaceProfile }
          : { success: false, error: 'profile_not_found' },
      )
      return
    }
    if (request.body.mode !== 'register') {
      response.json({ success: false, error: 'invalid_request' })
      return
    }
    if (marketplaceProfile.exists) {
      response.json({ success: false, error: 'profile_exists' })
      return
    }
    const avatarMediaId = Number(request.body.avatarMediaId) || 0
    const avatar = mockMedia.find(
      (item) => item.id === avatarMediaId && item.mediaType === 'photo',
    )
    if (avatarMediaId > 0 && !avatar) {
      response.json({ success: false, error: 'invalid_profile_image' })
      return
    }
    marketplaceProfile = {
      ...marketplaceProfile,
      avatar_media_id: avatarMediaId || null,
      avatar_url: avatar?.url ?? null,
      bio: '',
      display_name: linkedAccount?.email?.split('@')[0] ?? 'CityMarkt',
      exists: true,
    }
    response.json({ success: true, data: marketplaceProfile })
    return
  }
  if (endpoint.startsWith('marketplace:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'marketplace:profile') {
    marketplaceProfile.listing_count = marketplaceListings.filter(
      (listing) => listing.seller_account_id === 1,
    ).length
    response.json({ success: true, data: marketplaceProfile })
    return
  }
  if (endpoint === 'marketplace:profile-save') {
    const displayName = String(request.body.displayName ?? '').trim()
    const bio = String(request.body.bio ?? '').trim()
    const avatarMediaId = Number(request.body.avatarMediaId)
    const avatar = mockMedia.find(
      (item) => item.id === avatarMediaId && item.mediaType === 'photo',
    )
    if (
      displayName.length < 2 ||
      displayName.length > 40 ||
      bio.length > 160 ||
      !Number.isInteger(avatarMediaId) ||
      avatarMediaId < 0 ||
      (avatarMediaId > 0 && !avatar)
    ) {
      response.json({ success: false, error: 'invalid_profile' })
      return
    }
    marketplaceProfile = {
      ...marketplaceProfile,
      avatar_media_id: avatarMediaId || null,
      avatar_url: avatar?.url ?? null,
      bio,
      display_name: displayName,
      exists: true,
    }
    response.json({ success: true, data: marketplaceProfile })
    return
  }
  if (endpoint === 'marketplace:counts') {
    response.json({
      success: true,
      data: {
        active: marketplaceListings.filter(
          (item) =>
            item.seller_account_id === 1 &&
            ['active', 'reserved'].includes(item.status),
        ).length,
        unread: marketplaceInquiries.reduce(
          (total, item) => total + item.unread,
          0,
        ),
      },
    })
    return
  }
  if (endpoint === 'marketplace:list-own') {
    response.json({
      success: true,
      data: {
        hasMore: false,
        items: marketplaceListings.filter(
          (item) => item.seller_account_id === 1,
        ),
        offset: 0,
      },
    })
    return
  }
  if (endpoint === 'marketplace:create') {
    const id = `81bc9d37-20e1-4d8a-82f8-${String(Date.now()).slice(-12)}`
    const selected = request.body.images.map((image) => {
      const photo =
        {
          'sunset-drive':
            'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
          'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
          'city-lights':
            'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
          'desert-road':
            'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)',
        }[image.id] ?? 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)'
      return { media_id: image.id, gradient: photo, sort_order: 1 }
    })
    marketplaceListings.unshift({
      ...request.body,
      id,
      seller_account_id: 1,
      seller_name: 'demo',
      seller_since: '2026-08-04 12:00:00',
      seller_active: 1,
      item_condition: request.body.condition,
      price_type: request.body.priceType,
      show_phone: request.body.showPhone ? 1 : 0,
      phone_number: request.body.showPhone ? (mockSim?.number ?? null) : null,
      status: 'active',
      revision: 1,
      created_at: '2026-08-06 11:00:00',
      updated_at: '2026-08-06 11:00:00',
      expires_at: '2026-08-13 11:00:00',
      images: selected,
      image: selected[0]?.gradient ?? null,
      is_favorite: false,
    })
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'marketplace:update') {
    const item = marketplaceListings.find(
      (listing) => listing.id === request.body.id,
    )
    if (!item) {
      response.json({ success: false, error: 'listing_not_found' })
      return
    }
    const selected = request.body.images.map((image, index) => ({
      media_id: image.id,
      gradient:
        {
          'sunset-drive':
            'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
          'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
          'city-lights':
            'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
          'desert-road':
            'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)',
        }[image.id] ?? item.image,
      sort_order: index + 1,
    }))
    Object.assign(item, request.body, {
      image: selected[0]?.gradient ?? null,
      images: selected,
      item_condition: request.body.condition,
      phone_number: request.body.showPhone ? (mockSim?.number ?? null) : null,
      price_type: request.body.priceType,
      revision: item.revision + 1,
      show_phone: request.body.showPhone ? 1 : 0,
    })
    response.json({ success: true, data: { revision: item.revision } })
    return
  }
  if (endpoint === 'marketplace:favorite') {
    const item = marketplaceListings.find(
      (listing) => listing.id === request.body.id,
    )
    if (item) item.is_favorite = request.body.favorite
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:set-status') {
    const item = marketplaceListings.find(
      (listing) => listing.id === request.body.id,
    )
    if (!item) {
      response.json({ success: false, error: 'listing_not_found' })
      return
    }
    const validTransitions = {
      active: ['reserved', 'expired', 'sold'],
      removed: ['active', 'reserved', 'expired'],
      reserved: ['active'],
      sold: ['active', 'reserved'],
    }
    if (!validTransitions[request.body.status]?.includes(item.status)) {
      response.json({ success: false, error: 'invalid_status' })
      return
    }
    item.status = request.body.status
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:list-inquiries') {
    response.json({ success: true, data: marketplaceInquiries })
    return
  }
  if (endpoint === 'marketplace:send-message') {
    let inquiry = marketplaceInquiries.find(
      (item) =>
        item.id === request.body.inquiryId ||
        item.listing_id === request.body.listingId,
    )
    if (!inquiry) {
      const listing = marketplaceListings.find(
        (item) => item.id === request.body.listingId,
      )
      inquiry = {
        id: '4903b923-409a-437e-971f-b7a2b10e9e31',
        listing_id: listing.id,
        seller_account_id: listing.seller_account_id,
        buyer_account_id: 1,
        title: listing.title,
        price: listing.price,
        price_type: listing.price_type,
        status: listing.status,
        image: listing.image,
        other_name: listing.seller_name,
        last_message: request.body.body,
        offer_id: null,
        offer_amount: null,
        offer_proposer_account_id: null,
        offer_status: null,
        offer_revision: 0,
        unread: 0,
        updated_at: '2026-08-06 11:30:00',
      }
      marketplaceInquiries.push(inquiry)
    }
    marketplaceMessages.push({
      id: marketplaceMessages.length + 1,
      inquiry_id: inquiry.id,
      sender_account_id: 1,
      body: request.body.body,
      created_at: '2026-08-06 12:00:00',
      read_at: null,
    })
    inquiry.last_message = request.body.body
    inquiry.unread = 0
    inquiry.updated_at = '2026-08-06 12:00:00'
    response.json({ success: true, data: { id: inquiry.id } })
    return
  }
  if (endpoint === 'marketplace:get-inquiry') {
    const inquiry = marketplaceInquiries.find(
      (item) => item.id === request.body.id,
    )
    if (inquiry) {
      inquiry.unread = 0
      for (const offer of marketplaceOffers) {
        if (offer.inquiry_id === inquiry.id && offer.proposer_account_id !== 1)
          offer.read_at = '2026-08-06 12:01:00'
        if (
          offer.inquiry_id === inquiry.id &&
          offer.proposer_account_id === 1 &&
          ['accepted', 'rejected'].includes(offer.status)
        )
          offer.response_read_at = '2026-08-06 12:01:00'
      }
    }
    const listing =
      inquiry &&
      marketplaceListings.find((item) => item.id === inquiry.listing_id)
    response.json(
      inquiry
        ? {
            success: true,
            data: {
              accountId: 1,
              inquiry: {
                ...inquiry,
                reserved_account_id: listing.reserved_account_id ?? null,
                status: listing.status,
              },
              messages: marketplaceMessages.filter(
                (message) => message.inquiry_id === inquiry.id,
              ),
              offers: marketplaceOffers.filter(
                (offer) => offer.inquiry_id === inquiry.id,
              ),
            },
          }
        : { success: false, error: 'inquiry_not_found' },
    )
    return
  }
  if (endpoint === 'marketplace:make-offer') {
    const inquiry = marketplaceInquiries.find(
      (item) => item.id === request.body.inquiryId,
    )
    const amount = Number(request.body.amount)
    if (!inquiry || !Number.isInteger(amount) || amount < 1) {
      response.json({ success: false, error: 'invalid_offer' })
      return
    }
    if (inquiry.offer_status === 'accepted') {
      response.json({ success: false, error: 'offer_closed' })
      return
    }
    if (
      inquiry.offer_status === 'pending' &&
      inquiry.offer_proposer_account_id === 1
    ) {
      response.json({ success: false, error: 'offer_waiting' })
      return
    }
    const previous = marketplaceOffers.find(
      (offer) => offer.id === inquiry.offer_id,
    )
    if (previous?.status === 'pending') previous.status = 'countered'
    const offer = {
      id: marketplaceOffers.length + 1,
      inquiry_id: inquiry.id,
      proposer_account_id: 1,
      amount,
      status: 'pending',
      read_at: null,
      response_read_at: null,
      created_at: '2026-08-06 12:02:00',
      updated_at: '2026-08-06 12:02:00',
    }
    marketplaceOffers.push(offer)
    inquiry.offer_id = offer.id
    inquiry.offer_amount = amount
    inquiry.offer_proposer_account_id = 1
    inquiry.offer_status = 'pending'
    inquiry.offer_revision += 1
    inquiry.updated_at = offer.updated_at
    response.json({ success: true, data: { id: offer.id } })
    return
  }
  if (endpoint === 'marketplace:respond-offer') {
    const inquiry = marketplaceInquiries.find(
      (item) => item.id === request.body.inquiryId,
    )
    const offer =
      inquiry && marketplaceOffers.find((item) => item.id === inquiry.offer_id)
    if (
      !inquiry ||
      !offer ||
      offer.status !== 'pending' ||
      offer.proposer_account_id === 1
    ) {
      response.json({ success: false, error: 'offer_not_actionable' })
      return
    }
    if (!['accepted', 'rejected'].includes(request.body.action)) {
      response.json({ success: false, error: 'invalid_offer_response' })
      return
    }
    offer.status = request.body.action
    offer.updated_at = '2026-08-06 12:03:00'
    inquiry.offer_status = request.body.action
    inquiry.offer_revision += 1
    inquiry.updated_at = offer.updated_at
    if (request.body.action === 'accepted') {
      const listing = marketplaceListings.find(
        (item) => item.id === inquiry.listing_id,
      )
      listing.status = 'reserved'
      listing.reserved_account_id = inquiry.buyer_account_id
      inquiry.status = 'reserved'
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:report' || endpoint === 'marketplace:block') {
    response.json({ success: true })
    return
  }
  if (
    endpoint === 'sim:insert' &&
    request.body.imei === '356938035643810' &&
    !request.body.confirmed
  ) {
    response.json({ success: false, error: 'confirmation_required' })
    return
  }
  if (endpoint === 'sim:insert') {
    mockSim = {
      id: `development-sim-${request.body.imei}`,
      number:
        request.body.imei === '356938035643810' ? '5559876543' : '5551234567',
      removable: true,
      registered: true,
      type: 'registered',
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'sim:eject') {
    if (!mockSim) {
      response.json({ success: false, error: 'no_sim' })
      return
    }
    mockSim = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'payphone:dial') {
    const phoneNumber = String(request.body.phoneNumber ?? '').replace(
      /\D/g,
      '',
    )
    if (phoneNumber.length !== 10) {
      response.json({ success: false, error: 'invalid_number' })
      return
    }
    if (phoneNumber === '5550000000') {
      response.json({ success: false, error: 'busy' })
      return
    }
    mockPayphoneCall = {
      answeredAt: Math.floor(Date.now() / 1000),
      elapsedSeconds: 0,
      id: `payphone-${Date.now()}`,
      otherNumber: phoneNumber,
      state: 'connected',
      totalCost: 0,
    }
    response.json({ success: true, data: mockPayphoneCall })
    return
  }
  if (endpoint === 'payphone:hangup') {
    mockPayphoneCall = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'payphone:close') {
    mockPayphoneCall = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'memos:list') {
    response.json({ success: true, data: mockMemos })
    return
  }
  if (endpoint === 'memos:devCapture') {
    const correlationId =
      typeof request.body.correlationId === 'string'
        ? request.body.correlationId
        : ''
    const title =
      typeof request.body.title === 'string' ? request.body.title.trim() : ''
    const note =
      request.body.note === undefined
        ? ''
        : typeof request.body.note === 'string'
          ? request.body.note.trim()
          : null
    const durationMs = Math.floor(Number(request.body.durationMs))
    const mimeType =
      request.body.mimeType === 'audio/ogg'
        ? 'audio/ogg'
        : ['audio/webm', 'audio/webm;codecs=opus'].includes(
              request.body.mimeType,
            )
          ? 'audio/webm'
          : null
    const waveform = Array.isArray(request.body.waveform)
      ? request.body.waveform.map(Number)
      : []
    const audioDataUrl =
      typeof request.body.audioDataUrl === 'string'
        ? request.body.audioDataUrl
        : ''
    const separator = audioDataUrl.indexOf(';base64,')
    const audioMime =
      separator > 5
        ? audioDataUrl.slice(5, separator).split(';', 1)[0].toLowerCase()
        : ''
    const encodedAudio = separator > 0 ? audioDataUrl.slice(separator + 8) : ''
    const validAudio =
      Boolean(mimeType) &&
      audioMime === mimeType &&
      encodedAudio.length > 0 &&
      encodedAudio.length % 4 === 0 &&
      /^[A-Za-z0-9+/]+={0,2}$/.test(encodedAudio)
    const sizeBytes = validAudio
      ? Buffer.from(encodedAudio, 'base64').byteLength
      : 0
    if (
      !correlationId ||
      correlationId.length > 80 ||
      !title ||
      title.length > 120 ||
      note === null ||
      note.length > 2000 ||
      !Number.isFinite(durationMs) ||
      durationMs < 300 ||
      durationMs > 300_000 ||
      typeof request.body.pinned !== 'boolean' ||
      waveform.length < 8 ||
      waveform.length > 96 ||
      waveform.some(
        (sample) => !Number.isFinite(sample) || sample < 0 || sample > 1,
      ) ||
      !validAudio ||
      sizeBytes < 1 ||
      sizeBytes > 2 * 1024 * 1024 ||
      mockMemos.length >= 100
    ) {
      response.json({ success: false, error: 'invalid_memo' })
      return
    }
    const now = Date.now()
    const memo = {
      createdAt: now,
      durationMs,
      id: randomUUID(),
      mediaId:
        Math.max(0, ...mockMemos.map((item) => Number(item.mediaId) || 0)) + 1,
      mimeType,
      note,
      pinned: request.body.pinned,
      revision: 1,
      sizeBytes,
      title,
      updatedAt: now,
      url: audioDataUrl,
      waveform,
    }
    mockMemos.unshift(memo)
    response.json({ success: true, data: memo })
    return
  }
  if (endpoint === 'memos:update') {
    const id = typeof request.body.id === 'string' ? request.body.id : ''
    const title =
      typeof request.body.title === 'string' ? request.body.title.trim() : ''
    const note =
      request.body.note === undefined
        ? ''
        : typeof request.body.note === 'string'
          ? request.body.note.trim()
          : null
    const revision = Math.floor(Number(request.body.revision) || 0)
    if (
      id.length !== 36 ||
      !title ||
      title.length > 120 ||
      note === null ||
      note.length > 2000 ||
      typeof request.body.pinned !== 'boolean' ||
      revision < 1
    ) {
      response.json({ success: false, error: 'invalid_memo' })
      return
    }
    const index = mockMemos.findIndex(
      (memo) => memo.id === id && memo.revision === revision,
    )
    if (index < 0) {
      response.json({ success: false, error: 'conflict', data: mockMemos })
      return
    }
    const memo = {
      ...mockMemos[index],
      note,
      pinned: request.body.pinned,
      revision: revision + 1,
      title,
      updatedAt: Date.now(),
    }
    mockMemos[index] = memo
    mockMemos.sort(
      (left, right) =>
        Number(right.pinned) - Number(left.pinned) ||
        right.updatedAt - left.updatedAt ||
        right.id.localeCompare(left.id),
    )
    response.json({ success: true, data: memo })
    return
  }
  if (endpoint === 'memos:delete') {
    const id = typeof request.body.id === 'string' ? request.body.id : ''
    if (id.length !== 36) {
      response.json({ success: false, error: 'invalid_memo' })
      return
    }
    const index = mockMemos.findIndex((memo) => memo.id === id)
    if (index < 0) {
      response.json({ success: false, error: 'memo_not_found' })
      return
    }
    mockMemos.splice(index, 1)
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'notes:list') {
    response.json({ success: true, data: mockNotes })
    return
  }
  if (endpoint === 'notes:create') {
    mockNotes.unshift({ ...request.body, revision: 1 })
    response.json({ success: true, data: mockNotes })
    return
  }
  if (endpoint === 'notes:update') {
    const index = mockNotes.findIndex((note) => note.id === request.body.id)
    if (index >= 0) {
      mockNotes[index] = {
        ...request.body,
        revision: mockNotes[index].revision + 1,
        updatedAt: Date.now(),
      }
    }
    response.json({ success: true, data: mockNotes })
    return
  }
  if (endpoint === 'notes:delete') {
    mockNotes = mockNotes.filter((note) => note.id !== request.body.id)
    response.json({ success: true, data: mockNotes })
    return
  }
  if (endpoint === 'mail:login' || endpoint === 'mail:register') {
    authenticated = true
    linkedAccount = {
      devices: accountDevices,
      email: 'demo@ifruit.com',
      id: 1,
    }
    response.json({ success: true, data: linkedAccount })
    return
  }
  if (endpoint === 'mail:logout') {
    authenticated = false
    response.json({ success: true })
    return
  }
  if (endpoint.startsWith('mail:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'mail:counts') {
    response.json({ success: true, data: counts() })
    return
  }
  if (endpoint === 'mail:mailboxes') {
    response.json({ success: true, data: { mailboxes: mailboxViews() } })
    return
  }
  if (endpoint === 'mail:create-mailbox') {
    const name = String(request.body.name ?? '').trim()
    if (!name || name.length > 50) {
      response.json({ success: false, error: 'invalid_mailbox' })
      return
    }
    if (
      mockMailboxes.some(
        (mailbox) => mailbox.name.toLowerCase() === name.toLowerCase(),
      )
    ) {
      response.json({ success: false, error: 'mailbox_exists' })
      return
    }
    if (mockMailboxes.length >= 20) {
      response.json({ success: false, error: 'mailbox_limit' })
      return
    }

    const mailbox = {
      count: 0,
      id: nextMockMailboxId,
      name,
      sort_order: mockMailboxes.length,
    }
    nextMockMailboxId += 1
    mockMailboxes.push(mailbox)
    response.json({ success: true, data: mailbox })
    return
  }
  if (endpoint === 'mail:delete-mailbox') {
    const mailboxId = Number(request.body.id)
    const mailboxIndex = mockMailboxes.findIndex(
      (mailbox) => mailbox.id === mailboxId,
    )
    if (mailboxIndex < 0) {
      response.json({ success: false, error: 'mailbox_not_found' })
      return
    }

    mockMailboxes.splice(mailboxIndex, 1)
    for (const message of messages) {
      if (message.mailbox_id === mailboxId) message.mailbox_id = null
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:move') {
    const message = messages.find(
      (item) => item.id === Number(request.body.id) && !item.trashed_at,
    )
    const mailboxId = Number(request.body.mailboxId)
    const mailboxExists = mockMailboxes.some(
      (mailbox) => mailbox.id === mailboxId,
    )
    if (!message) {
      response.json({ success: false, error: 'message_not_found' })
      return
    }
    if (mailboxId !== 0 && !mailboxExists) {
      response.json({ success: false, error: 'mailbox_not_found' })
      return
    }

    message.mailbox_id = mailboxId || null
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:list') {
    const { folder, search = '' } = request.body
    const mailboxMatch = /^mailbox:(\d+)$/.exec(String(folder))
    const mailboxId = mailboxMatch ? Number(mailboxMatch[1]) : null
    if (
      mailboxId &&
      !mockMailboxes.some((mailbox) => mailbox.id === mailboxId)
    ) {
      response.json({ success: false, error: 'mailbox_not_found' })
      return
    }
    let items =
      folder === 'drafts'
        ? draft
          ? [{ ...draft, created_at: draft.updated_at, preview: draft.body }]
          : []
        : mailboxId
          ? messages.filter(
              (item) => item.mailbox_id === mailboxId && !item.trashed_at,
            )
          : messages.filter((item) =>
              folder === 'trash'
                ? item.trashed_at
                : item.folder === folder &&
                  !item.mailbox_id &&
                  !item.trashed_at,
            )
    const query = String(search).toLowerCase()
    if (query) {
      items = items.filter((item) =>
        `${item.sender ?? ''} ${item.subject} ${item.preview}`
          .toLowerCase()
          .includes(query),
      )
    }
    response.json({ success: true, data: { hasMore: false, items, offset: 0 } })
    return
  }
  if (endpoint === 'mail:get') {
    const message = messages.find((item) => item.id === Number(request.body.id))
    if (message) message.is_read = true
    response.json(
      message
        ? { success: true, data: message }
        : { success: false, error: 'message_not_found' },
    )
    return
  }
  if (endpoint === 'mail:get-draft') {
    response.json(
      draft
        ? { success: true, data: draft }
        : { success: false, error: 'draft_not_found' },
    )
    return
  }
  if (endpoint === 'mail:save-draft') {
    draft = {
      ...request.body,
      id: request.body.id ?? '748836d2-2308-4c21-a4d8-3af6df6dd7eb',
      created_at: '2026-08-04 11:40:00',
      updated_at: '2026-08-04 11:40:00',
    }
    response.json({ success: true, data: { id: draft.id } })
    return
  }
  if (endpoint === 'mail:delete-draft') {
    draft = null
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:send') {
    draft = null
    response.json({ success: true, data: { id: 'mock-sent-message' } })
    return
  }
  if (endpoint === 'mail:delete-many') {
    const { folder, ids } = request.body
    if (
      !['drafts', 'inbox', 'sent', 'trash'].includes(folder) ||
      !Array.isArray(ids)
    ) {
      response.json({ success: false, error: 'invalid_request' })
      return
    }

    const selectedIds = new Set(ids.map(String))
    if (folder === 'drafts') {
      if (draft && selectedIds.has(String(draft.id))) draft = null
    } else if (folder === 'trash') {
      for (let index = messages.length - 1; index >= 0; index -= 1) {
        const message = messages[index]
        if (message.trashed_at && selectedIds.has(String(message.id))) {
          messages.splice(index, 1)
        }
      }
    } else {
      for (const message of messages) {
        if (
          message.folder === folder &&
          !message.trashed_at &&
          selectedIds.has(String(message.id))
        ) {
          message.trashed_at = '2026-08-04 12:00:00'
        }
      }
    }

    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:trash' || endpoint === 'mail:restore') {
    const message = messages.find((item) => item.id === Number(request.body.id))
    if (message)
      message.trashed_at =
        endpoint === 'mail:trash' ? '2026-08-04 12:00:00' : null
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:delete-forever') {
    const index = messages.findIndex(
      (item) => item.id === Number(request.body.id),
    )
    if (index >= 0) messages.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:empty-trash') {
    for (let index = messages.length - 1; index >= 0; index -= 1) {
      if (messages[index].trashed_at) messages.splice(index, 1)
    }
    response.json({ success: true })
    return
  }
  if (endpoint === 'mail:set-read') {
    const message = messages.find((item) => item.id === Number(request.body.id))
    if (message) message.is_read = request.body.read
    response.json({ success: true })
    return
  }
  console.error(`[NUI] Missing browser mock for ${endpoint}`)
  response.json({ success: false, error: 'mock_endpoint_missing' })
})

if (require.main === module) {
  app.listen(port, () => {
    console.log(`Mock NUI server listening on http://localhost:${port}`)
  })
}

module.exports = {
  app,
  skyPicMessageBody,
  skyPicRecipientIds,
  skyPicTextOverlay,
}
