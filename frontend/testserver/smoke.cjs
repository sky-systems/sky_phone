const assert = require('node:assert/strict')
const { once } = require('node:events')

const { app } = require('./index.cjs')

const browserDataRequests = [
  ['development:bootstrap', {}],
  ['account:devices', {}],
  ['banking:overview', {}],
  ['crypto:bootstrap', {}],
  ['crypto:market-tick', {}],
  ['crypto:recipient', { walletKey: 'VX-DEAD-BEEF-C0DE-2026' }],
  ['crypto:quote', { marketId: 'aurora', quantity: '1', side: 'buy' }],
  ['health:overview', {}],
  ['billing:overview', {}],
  ['billing:list', { filter: 'all', limit: 20, offset: 0 }],
  ['calendar:list', { endsAt: 4_102_444_800, startsAt: 0 }],
  ['citywarn:bootstrap', {}],
  ['calls:recents', {}],
  ['companies:list', {}],
  ['companies:my-requests', { limit: 20, offset: 0 }],
  ['companies:work-context', {}],
  ['companies:work-queue', { limit: 20, offset: 0 }],
  ['contacts:list', {}],
  ['crewlink:login', { password: 'CrewLink123!' }],
  ['crewlink:bootstrap', {}],
  ['crewlink:live', {}],
  ['crewlink:nearby', {}],
  ['darkchat:bootstrap', {}],
  ['easyshare:bootstrap', {}],
  ['easyshare:own-contact', {}],
  ['feather:bootstrap', {}],
  ['feather:feed', { limit: 20 }],
  ['feather:explore', { limit: 20 }],
  ['flare:bootstrap', {}],
  ['fliptok:bootstrap', {}],
  ['fliptok:feed', { limit: 20 }],
  ['fliptok:discover', { limit: 20 }],
  ['fliptok:activities', {}],
  ['gallery:list', {}],
  ['gallery:counts', {}],
  ['garage:vehicles', {}],
  ['garage:valet-state', {}],
  ['housing:overview', {}],
  ['housing:key-candidates', { action: 'give' }],
  ['mail:counts', {}],
  ['mail:list', { folder: 'inbox' }],
  ['mail:mailboxes', {}],
  ['map:getPlayerCoords', {}],
  ['map:markers', {}],
  ['marketplace:counts', {}],
  ['marketplace:list', {}],
  ['marketplace:list-own', {}],
  ['marketplace:list-inquiries', {}],
  ['marketplace:profile', {}],
  ['messages:conversations', {}],
  ['messages:gifs', { query: 'party' }],
  ['memos:list', {}],
  ['music:bootstrap', {}],
  ['notes:list', {}],
  ['pages:list', {}],
  ['pages:list-own', {}],
  ['pages:profile', {}],
  ['picstagram:bootstrap', {}],
  ['picstagram:feed', { limit: 20 }],
  ['picstagram:explore', { limit: 20 }],
  ['picstagram:saved', {}],
  ['picstagram:stories', {}],
  ['picstagram:activities', {}],
  ['radio:get', {}],
  ['skyride:bootstrap', {}],
  ['skyride:history', {}],
  ['skyride:get-player-coords', {}],
  ['weather:get', {}],
  ['weazel-news:context', {}],
  ['weazel-news:list', { category: null, offset: 0, search: '' }],
  ['weazel-news:manage-list', { offset: 0, search: '', status: 'all' }],
]

async function post(baseUrl, endpoint, body = {}) {
  const response = await fetch(`${baseUrl}/api/${endpoint}`, {
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
    method: 'POST',
  })
  assert.equal(response.status, 200, endpoint)
  return response.json()
}

async function expectSuccess(baseUrl, endpoint, body = {}, data = false) {
  const result = await post(baseUrl, endpoint, body)
  assert.equal(result.success, true, `${endpoint}: ${result.error ?? 'failed'}`)
  if (data) assert.notEqual(result.data, undefined, `${endpoint}: missing data`)
  return result.data
}

function expectItems(value, label, minimum = 1) {
  assert(
    Array.isArray(value) && value.length >= minimum,
    `${label} did not include enough browser test data`,
  )
}

function verifyBrowserTestData(dataByEndpoint) {
  const development = dataByEndpoint.get('development:bootstrap')
  expectItems(development.device.data.alarms.payload, 'clock alarms', 3)
  expectItems(
    development.device.data.media.payload.captures,
    'camera captures',
    2,
  )
  expectItems(
    development.device.data.apps.payload.claimedApps,
    'installed demo apps',
    41,
  )
  assert.equal(
    new Set(development.device.data.apps.payload.claimedApps).size,
    41,
    'browser demo apps were not uniquely installed',
  )
  assert.equal(
    development.device.data.settings.payload.settings.wallpaper,
    'custom',
    'browser demo home wallpaper was not configured',
  )
  assert.equal(
    development.device.data.settings.payload.settings.lockWallpaper,
    'custom',
    'browser demo Lock Screen wallpaper was not configured',
  )
  assert.match(
    development.device.data.settings.payload.settings.wallpaperImageUrl,
    /sky-phone-demo-gradient\.png$/,
    'browser demo wallpaper image was not configured',
  )
  expectItems(development.memos, 'memos', 3)
  expectItems(development.notes, 'notes', 4)
  assert(
    Object.keys(development.device.data.games.payload).length >= 7,
    'games did not include saved browser test progress',
  )

  expectItems(dataByEndpoint.get('health:overview').days, 'health history', 7)
  const crypto = dataByEndpoint.get('crypto:bootstrap')
  expectItems(crypto.markets, 'crypto markets', 24)
  assert.equal(typeof crypto.profile.priceAlerts, 'boolean')
  assert.match(crypto.profile.walletKey, /^VX-(?:[A-F0-9]{4}-){3}[A-F0-9]{4}$/)
  assert.equal(typeof crypto.markets[0].issuedSupply, 'string')
  assert(crypto.markets.every((market) => typeof market.logo === 'string'))
  assert(
    crypto.markets.every(
      (market) =>
        Array.isArray(market.priceHistory) &&
        market.priceHistory.length >= 2 &&
        market.priceHistory.at(-1) === Number(market.price).toFixed(2),
    ),
  )
  assert(
    Math.max(...crypto.markets.map((market) => Number(market.price))) >=
      1000000,
  )
  assert(
    Math.min(...crypto.markets.map((market) => Number(market.price))) <= 0.01,
  )
  const cryptoTick = dataByEndpoint.get('crypto:market-tick')
  expectItems(cryptoTick, 'live crypto market tick', 24)
  assert(
    cryptoTick.every(
      (market) =>
        typeof market.updatedAt === 'number' &&
        market.priceHistory.at(-1) === market.price,
    ),
  )
  expectItems(
    dataByEndpoint.get('billing:list').invoices,
    'billing invoices',
    3,
  )
  expectItems(dataByEndpoint.get('calendar:list'), 'calendar events', 5)
  const cityWarn = dataByEndpoint.get('citywarn:bootstrap')
  expectItems(cityWarn.active, 'active CityWarn alerts', 2)
  expectItems(cityWarn.archive, 'CityWarn alert history')
  assert.equal(cityWarn.context.canPublish, true)
  assert.deepEqual(
    cityWarn.active.map((alert) => alert.title),
    ['Police operation in Mission Row', 'Water supply disruption'],
  )
  assert.equal(cityWarn.archive[0].title, 'City radio network restored')
  expectItems(dataByEndpoint.get('calls:recents'), 'recent calls', 5)
  expectItems(dataByEndpoint.get('companies:list').companies, 'companies', 3)
  expectItems(dataByEndpoint.get('contacts:list'), 'contacts', 10)
  expectItems(
    dataByEndpoint.get('crewlink:bootstrap').groups,
    'CrewLink groups',
    2,
  )
  expectItems(
    dataByEndpoint.get('darkchat:bootstrap').conversations,
    'DarkChat conversations',
  )
  expectItems(dataByEndpoint.get('feather:feed').items, 'Feather posts', 5)
  expectItems(
    dataByEndpoint.get('flare:bootstrap').suggestions,
    'Flare suggestions',
    5,
  )
  expectItems(dataByEndpoint.get('fliptok:feed').items, 'FlipTok videos', 2)
  expectItems(dataByEndpoint.get('gallery:list'), 'gallery media', 30)
  expectItems(
    dataByEndpoint.get('garage:vehicles').vehicles,
    'garage vehicles',
    4,
  )
  expectItems(
    dataByEndpoint.get('housing:overview').properties,
    'housing properties',
    5,
  )
  expectItems(dataByEndpoint.get('mail:list').items, 'inbox mail', 2)
  expectItems(
    dataByEndpoint.get('mail:mailboxes').mailboxes,
    'custom mailboxes',
  )
  expectItems(dataByEndpoint.get('map:markers'), 'map markers')
  expectItems(
    dataByEndpoint.get('marketplace:list').items,
    'CityMarkt listings',
    4,
  )
  expectItems(
    dataByEndpoint.get('messages:conversations'),
    'message conversations',
    5,
  )
  expectItems(
    dataByEndpoint.get('music:bootstrap').serverTracks,
    'music tracks',
    3,
  )
  expectItems(dataByEndpoint.get('pages:list').items, 'Local Pages posts', 4)
  expectItems(
    dataByEndpoint.get('picstagram:feed').items,
    'Picstagram posts',
    2,
  )
  expectItems(dataByEndpoint.get('radio:get').history, 'radio history', 2)
  expectItems(dataByEndpoint.get('skyride:history').items, 'SkyRide history', 2)
  expectItems(
    dataByEndpoint.get('weazel-news:list').items,
    'Weazel News articles',
    5,
  )
  expectItems(
    dataByEndpoint.get('weazel-news:manage-list').items,
    'Weazel News editorial articles',
    7,
  )
}

async function verifyStatefulActions(baseUrl) {
  const cryptoBeforeTransfer = await expectSuccess(
    baseUrl,
    'crypto:bootstrap',
    {},
    true,
  )
  const auroraBeforeTransfer = cryptoBeforeTransfer.holdings.find(
    (holding) => holding.assetId === 'aurora',
  )
  const cryptoAfterTransfer = await expectSuccess(
    baseUrl,
    'crypto:transfer',
    {
      idempotencyKey: 'smoke-transfer-1',
      marketId: 'aurora',
      password: 'VaultX123!',
      quantity: '0.5',
      walletKey: 'VX-DEAD-BEEF-C0DE-2026',
    },
    true,
  )
  const auroraAfterTransfer = cryptoAfterTransfer.holdings.find(
    (holding) => holding.assetId === 'aurora',
  )
  assert.equal(
    Number(auroraAfterTransfer.quantity),
    Number(auroraBeforeTransfer.quantity) - 0.5,
  )
  assert.equal(cryptoAfterTransfer.activity[0].type, 'transfer_out')
  assert.equal(
    cryptoAfterTransfer.activity[0].counterpartyKey,
    'VX-DEAD-BEEF-C0DE-2026',
  )

  const companyCall = await expectSuccess(
    baseUrl,
    'companies:dial-service-line',
    { phoneNumber: '5551110001' },
    true,
  )
  assert.equal(companyCall.direction, 'outgoing')
  assert.equal(companyCall.otherNumber, '5551110001')
  assert.equal(companyCall.state, 'ringing')

  let gallery = await expectSuccess(baseUrl, 'gallery:list', {}, true)
  assert(gallery.length >= 10, 'gallery:list did not include enough test media')
  assert(
    gallery.filter((item) => item.mediaType === 'video').length >= 3,
    'gallery:list did not include enough test videos',
  )
  assert(
    gallery
      .filter((item) => item.mediaType === 'video')
      .every((item) => typeof item.thumbnailUrl === 'string'),
    'gallery:list returned a test video without a thumbnail',
  )
  const flipTokPhotos = gallery
    .filter((item) => item.mediaType === 'photo')
    .slice(0, 3)
  const createdFlipTok = await expectSuccess(
    baseUrl,
    'fliptok:publish',
    {
      caption: 'Browser mock photo slideshow',
      commentsEnabled: true,
      coverTimeMs: 0,
      customMusicUrl: '',
      draft: false,
      mediaId: flipTokPhotos[0].id,
      mediaIds: flipTokPhotos.map((item) => item.id),
      mediaType: 'photo',
      musicTrack: '',
      musicVolume: 0,
      originalVolume: 0,
      trimEndMs: null,
      trimStartMs: 0,
      visibility: 'public',
    },
    true,
  )
  let flipTokFeed = await expectSuccess(
    baseUrl,
    'fliptok:feed',
    { mode: 'for-you', offset: 0 },
    true,
  )
  const photoFlipTok = flipTokFeed.items.find(
    (item) => item.id === createdFlipTok.id,
  )
  assert.equal(photoFlipTok.media_type, 'photo')
  assert.deepEqual(
    photoFlipTok.media.map((item) => item.id),
    flipTokPhotos.map((item) => item.id),
    'fliptok:publish did not preserve photo order',
  )
  await expectSuccess(baseUrl, 'fliptok:comment', {
    body: 'Browser mock scoped comment',
    id: createdFlipTok.id,
  })
  const createdComments = await expectSuccess(
    baseUrl,
    'fliptok:comments',
    { id: createdFlipTok.id },
    true,
  )
  assert(
    createdComments.some((comment) => comment.body.includes('scoped comment')),
    'fliptok:comment did not persist for its video',
  )
  const otherComments = await expectSuccess(
    baseUrl,
    'fliptok:comments',
    { id: 'fliptok-1' },
    true,
  )
  assert(
    !otherComments.some((comment) => comment.body.includes('scoped comment')),
    'fliptok:comments leaked comments from another video',
  )
  await expectSuccess(baseUrl, 'fliptok:delete', { id: createdFlipTok.id })
  flipTokFeed = await expectSuccess(
    baseUrl,
    'fliptok:feed',
    { mode: 'for-you', offset: 0 },
    true,
  )
  assert(
    !flipTokFeed.items.some((item) => item.id === createdFlipTok.id),
    'fliptok:delete kept the removed video in the feed',
  )
  await expectSuccess(
    baseUrl,
    'gallery:favorite',
    { favorite: true, id: gallery[0].id },
    true,
  )
  gallery = await expectSuccess(baseUrl, 'gallery:list', {}, true)
  assert.equal(
    gallery.find((item) => item.id === gallery[0].id)?.favorite,
    true,
  )
  const articlePhotos = gallery
    .filter((item) => item.mediaType === 'photo')
    .slice(0, 7)
  assert.equal(
    articlePhotos.length,
    7,
    'gallery:list did not include enough photos for Weazel News',
  )
  const weazelContext = await expectSuccess(
    baseUrl,
    'weazel-news:context',
    {},
    true,
  )
  assert.equal(weazelContext.maximumImages, 6)
  const createdArticleResponse = await expectSuccess(
    baseUrl,
    'weazel-news:create',
    {
      body: 'Created by the browser mock smoke test with several photos.',
      category: 'news',
      imageMediaIds: articlePhotos.slice(0, 3).map((item) => item.id),
      status: 'published',
      title: 'Browser test Weazel article',
    },
    true,
  )
  const createdArticle = createdArticleResponse.article
  assert.deepEqual(
    createdArticle.images.map((image) => image.mediaId),
    articlePhotos.slice(0, 3).map((item) => item.id),
    'weazel-news:create did not preserve image order',
  )
  assert.equal(createdArticle.imageMediaId, articlePhotos[0].id)

  const updatedArticleResponse = await expectSuccess(
    baseUrl,
    'weazel-news:update',
    {
      body: createdArticle.body,
      category: 'business',
      id: createdArticle.id,
      imageMediaIds: [articlePhotos[2].id, articlePhotos[0].id],
      revision: createdArticle.revision,
      status: 'draft',
      title: 'Updated browser test Weazel article',
    },
    true,
  )
  const updatedArticle = updatedArticleResponse.article
  assert.deepEqual(
    updatedArticle.images.map((image) => image.mediaId),
    [articlePhotos[2].id, articlePhotos[0].id],
    'weazel-news:update did not preserve the reordered images',
  )
  assert.equal(updatedArticle.imageMediaId, articlePhotos[2].id)

  const loadedArticleResponse = await expectSuccess(
    baseUrl,
    'weazel-news:get',
    { id: updatedArticle.id, manage: true },
    true,
  )
  assert.deepEqual(loadedArticleResponse.article.images, updatedArticle.images)

  const tooManyImages = await post(baseUrl, 'weazel-news:create', {
    body: 'This article must be rejected because it has too many photos.',
    category: 'news',
    imageMediaIds: articlePhotos.map((item) => item.id),
    status: 'draft',
    title: 'Invalid Weazel article',
  })
  assert.equal(tooManyImages.success, false)
  assert.equal(tooManyImages.error, 'invalid_attachment')

  const firstSmsPhoto = await expectSuccess(
    baseUrl,
    'messages:send',
    {
      body: '',
      mediaAssetId: String(articlePhotos[0].id),
      messageType: 'image',
      phoneNumber: '5558675309',
    },
    true,
  )
  const captionedSmsPhoto = await expectSuccess(
    baseUrl,
    'messages:send',
    {
      body: 'Two photos from one composer draft.',
      mediaAssetId: String(articlePhotos[1].id),
      messageType: 'image',
      phoneNumber: '5558675309',
    },
    true,
  )
  assert.notEqual(firstSmsPhoto.id, captionedSmsPhoto.id)
  assert.equal(captionedSmsPhoto.body, 'Two photos from one composer draft.')
  const smsPhotoThread = await expectSuccess(
    baseUrl,
    'messages:thread',
    { phoneNumber: '5558675309' },
    true,
  )
  assert(smsPhotoThread.some((message) => message.id === firstSmsPhoto.id))
  assert(smsPhotoThread.some((message) => message.id === captionedSmsPhoto.id))

  await expectSuccess(baseUrl, 'weazel-news:delete', {
    id: updatedArticle.id,
    revision: updatedArticle.revision,
  })

  const memoBootstrap = await expectSuccess(
    baseUrl,
    'development:bootstrap',
    {},
    true,
  )
  assert(
    Array.isArray(memoBootstrap.memos) && memoBootstrap.memos.length >= 3,
    'development:bootstrap did not include realistic memo data',
  )
  assert(
    memoBootstrap.memos.every(
      (memo) =>
        typeof memo.url === 'string' &&
        memo.url.length > 0 &&
        Array.isArray(memo.waveform) &&
        memo.waveform.length >= 8,
    ),
    'development:bootstrap returned an invalid memo response shape',
  )

  let memos = await expectSuccess(baseUrl, 'memos:list', {}, true)
  const capturedMemo = await expectSuccess(
    baseUrl,
    'memos:devCapture',
    {
      audioDataUrl: 'data:audio/webm;base64,T2dnUw==',
      correlationId: 'browser-smoke-memo',
      durationMs: 1_250,
      mimeType: 'audio/webm;codecs=opus',
      note: 'Recorded in the browser preview.',
      pinned: false,
      title: 'Browser recording',
      waveform: Array(16).fill(0.35),
    },
    true,
  )
  assert.equal(capturedMemo.title, 'Browser recording')
  assert.equal(capturedMemo.mimeType, 'audio/webm')
  assert.equal(capturedMemo.sizeBytes, 4)
  assert.match(capturedMemo.id, /^[0-9a-f-]{36}$/)
  memos = await expectSuccess(baseUrl, 'memos:list', {}, true)
  assert(
    memos.some((item) => item.id === capturedMemo.id),
    'memos:devCapture did not persist',
  )
  await expectSuccess(baseUrl, 'memos:delete', { id: capturedMemo.id }, true)
  memos = await expectSuccess(baseUrl, 'memos:list', {}, true)

  const memo = memos.find((item) => !item.pinned)
  assert(memo, 'memos:list did not return an editable memo')
  const updatedMemo = await expectSuccess(
    baseUrl,
    'memos:update',
    {
      id: memo.id,
      note: 'Updated by the browser mock smoke test.',
      pinned: true,
      revision: memo.revision,
      title: 'Updated browser memo',
    },
    true,
  )
  assert.equal(updatedMemo.id, memo.id)
  assert.equal(updatedMemo.title, 'Updated browser memo')
  assert.equal(updatedMemo.note, 'Updated by the browser mock smoke test.')
  assert.equal(updatedMemo.pinned, true)
  assert.equal(updatedMemo.revision, memo.revision + 1)
  assert(Array.isArray(updatedMemo.waveform) && updatedMemo.waveform.length > 0)

  const deletedMemo = await expectSuccess(
    baseUrl,
    'memos:delete',
    { id: updatedMemo.id },
    true,
  )
  assert.deepEqual(deletedMemo, { id: updatedMemo.id })
  memos = await expectSuccess(baseUrl, 'memos:list', {}, true)
  assert(
    !memos.some((item) => item.id === updatedMemo.id),
    'memos:delete did not persist',
  )

  const noteId = `browser-note-${Date.now()}`
  let notes = await expectSuccess(
    baseUrl,
    'notes:create',
    {
      body: 'Created by the browser mock smoke test.',
      id: noteId,
      title: 'Browser test',
    },
    true,
  )
  assert(
    notes.some((note) => note.id === noteId),
    'notes:create did not persist',
  )
  notes = await expectSuccess(
    baseUrl,
    'notes:update',
    {
      body: 'Updated browser test note.',
      id: noteId,
      title: 'Browser test updated',
    },
    true,
  )
  assert.equal(
    notes.find((note) => note.id === noteId)?.title,
    'Browser test updated',
  )
  notes = await expectSuccess(baseUrl, 'notes:delete', { id: noteId }, true)
  assert(
    !notes.some((note) => note.id === noteId),
    'notes:delete did not persist',
  )

  const contact = await expectSuccess(
    baseUrl,
    'contacts:save',
    {
      email: 'browser.tester',
      name: 'Browser Tester',
      phoneNumber: '5552223333',
    },
    true,
  )
  assert.equal(contact.email, 'browser.tester@ifruit.com')
  await expectSuccess(
    baseUrl,
    'contacts:favorite',
    { favorite: true, id: contact.id },
    true,
  )
  let contacts = await expectSuccess(baseUrl, 'contacts:list', {}, true)
  const savedContact = contacts.find((item) => item.id === contact.id)
  assert.equal(savedContact?.favorite, true)
  assert.equal(savedContact?.email, 'browser.tester@ifruit.com')
  await expectSuccess(baseUrl, 'contacts:delete', { id: contact.id })
  contacts = await expectSuccess(baseUrl, 'contacts:list', {}, true)
  assert(
    !contacts.some((item) => item.id === contact.id),
    'contacts:delete did not persist',
  )

  const event = await expectSuccess(
    baseUrl,
    'calendar:create',
    {
      allDay: false,
      description: 'Stateful browser mock check',
      endsAt: 2_000_003_600,
      location: 'Legion Square',
      reminderMinutes: 15,
      startsAt: 2_000_000_000,
      title: 'Browser test event',
    },
    true,
  )
  let events = await expectSuccess(
    baseUrl,
    'calendar:list',
    { endsAt: 4_102_444_800, startsAt: 0 },
    true,
  )
  const storedEvent = events.find((item) => item.id === event.id)
  assert(storedEvent, 'calendar:create did not persist')
  await expectSuccess(baseUrl, 'calendar:update', {
    ...storedEvent,
    endsAt: storedEvent.endsAt / 1000,
    startsAt: storedEvent.startsAt / 1000,
    title: 'Updated browser test event',
  })
  events = await expectSuccess(
    baseUrl,
    'calendar:list',
    { endsAt: 4_102_444_800, startsAt: 0 },
    true,
  )
  assert.equal(
    events.find((item) => item.id === event.id)?.title,
    'Updated browser test event',
  )
  await expectSuccess(baseUrl, 'calendar:delete', { id: event.id })

  const marker = await expectSuccess(
    baseUrl,
    'map:create-marker',
    {
      color: '#2dd4bf',
      coords: { x: 215.2, y: -810.1, z: 30.7 },
      icon: 'pin',
      label: 'Browser test marker',
    },
    true,
  )
  let markers = await expectSuccess(baseUrl, 'map:markers', {}, true)
  assert(
    markers.some((item) => item.id === marker.id),
    'map:create-marker did not persist',
  )
  await expectSuccess(baseUrl, 'map:delete-marker', { id: marker.id })
  markers = await expectSuccess(baseUrl, 'map:markers', {}, true)
  assert(
    !markers.some((item) => item.id === marker.id),
    'map:delete-marker did not persist',
  )

  const bankingBefore = await expectSuccess(
    baseUrl,
    'banking:overview',
    {},
    true,
  )
  const bankingAfter = await expectSuccess(
    baseUrl,
    'banking:transfer',
    { amount: 125, phoneNumber: '5551110001' },
    true,
  )
  assert.equal(bankingAfter.bank, bankingBefore.bank - 125)

  const health = await expectSuccess(baseUrl, 'health:overview', {}, true)
  assert.equal(health.dailyStepGoal, 8000)
  assert.equal(health.days.length, 7)
  assert.equal(health.days.at(-1).steps, 6420)
  assert.equal('snapshot' in health, false)

  const medicalId = await expectSuccess(
    baseUrl,
    'health:save-profile',
    {
      allergies: 'Penicillin',
      bloodType: 'A+',
      conditions: 'Asthma',
      emergencyName: 'Jamie Morgan',
      emergencyPhone: '5550102211',
      emergencyRelation: 'Sibling',
      medication: 'Inhaler',
    },
    true,
  )
  assert.equal(medicalId.bloodType, 'A+')
  assert.equal(medicalId.allergies, 'Penicillin')

  let radio = await expectSuccess(
    baseUrl,
    'radio:connect',
    { frequency: 42.5, secondaryFrequency: 7.25 },
    true,
  )
  assert.equal(radio.frequency, 42.5)
  radio = await expectSuccess(baseUrl, 'radio:set-volume', { volume: 44 }, true)
  assert.equal(radio.volume, 44)
  radio = await expectSuccess(
    baseUrl,
    'radio:set-speaker',
    { enabled: true },
    true,
  )
  assert.equal(radio.speakerEnabled, true)
  await expectSuccess(baseUrl, 'radio:disconnect')

  const playlistState = await expectSuccess(
    baseUrl,
    'music:create-playlist',
    { name: 'Browser Test Mix' },
    true,
  )
  const playlist = playlistState.playlists.find(
    (item) => item.name === 'Browser Test Mix',
  )
  assert(playlist, 'music:create-playlist did not persist')
  await expectSuccess(
    baseUrl,
    'music:rename-playlist',
    { id: playlist.id, name: 'Updated Browser Mix' },
    true,
  )
  await expectSuccess(
    baseUrl,
    'music:delete-playlist',
    { id: playlist.id },
    true,
  )

  await expectSuccess(baseUrl, 'sim:eject')
  let bootstrap = await expectSuccess(
    baseUrl,
    'development:bootstrap',
    {},
    true,
  )
  assert.equal(bootstrap.device.sim, null)
  const simConfirmation = await post(baseUrl, 'sim:insert', {
    imei: '356938035643810',
  })
  assert.deepEqual(simConfirmation, {
    error: 'confirmation_required',
    success: false,
  })
  await expectSuccess(baseUrl, 'sim:insert', {
    confirmed: true,
    imei: '356938035643810',
  })
  bootstrap = await expectSuccess(baseUrl, 'development:bootstrap', {}, true)
  assert.equal(bootstrap.device.sim.number, '5559876543')

  const payphoneCall = await expectSuccess(
    baseUrl,
    'payphone:dial',
    { phoneNumber: '5551110001' },
    true,
  )
  assert.equal(payphoneCall.state, 'connected')
  await expectSuccess(baseUrl, 'payphone:hangup')

  const mailbox = await expectSuccess(
    baseUrl,
    'mail:create-mailbox',
    { name: 'Browser Test' },
    true,
  )
  const mailboxes = await expectSuccess(baseUrl, 'mail:mailboxes', {}, true)
  assert(
    mailboxes.mailboxes.some((item) => item.id === mailbox.id),
    'mail:create-mailbox did not update the mock mailbox list',
  )
  await expectSuccess(baseUrl, 'mail:move', {
    id: 2,
    mailboxId: mailbox.id,
  })
  const mailboxItems = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: `mailbox:${mailbox.id}` },
    true,
  )
  assert(
    mailboxItems.items.some((message) => message.id === 2),
    'mail:move did not add the message to the custom mailbox',
  )
  await expectSuccess(baseUrl, 'mail:move', { id: 2, mailboxId: 0 })
  await expectSuccess(baseUrl, 'mail:delete-mailbox', { id: mailbox.id })

  const draft = await expectSuccess(
    baseUrl,
    'mail:save-draft',
    {
      body: 'Browser test body',
      recipients: ['alex@ifruit.com'],
      subject: 'Browser test mail',
    },
    true,
  )
  const storedDraft = await expectSuccess(
    baseUrl,
    'mail:get-draft',
    { id: draft.id },
    true,
  )
  assert.equal(storedDraft.subject, 'Browser test mail')
  await expectSuccess(baseUrl, 'mail:delete-many', {
    folder: 'drafts',
    ids: [draft.id],
  })
  const drafts = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: 'drafts' },
    true,
  )
  assert.equal(drafts.items.length, 0, 'mail:delete-many kept selected draft')

  await expectSuccess(baseUrl, 'mail:delete-many', {
    folder: 'inbox',
    ids: [1],
  })
  const inbox = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: 'inbox' },
    true,
  )
  assert(
    inbox.items.some((message) => message.id === 2),
    'mail:delete-many removed a non-selected inbox message',
  )
  const trash = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: 'trash' },
    true,
  )
  assert(
    trash.items.some((message) => message.id === 1),
    'mail:delete-many did not move selected inbox mail to trash',
  )

  await expectSuccess(baseUrl, 'mail:delete-many', {
    folder: 'sent',
    ids: [3],
  })
  const sent = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: 'sent' },
    true,
  )
  assert.equal(sent.items.length, 0, 'mail:delete-many kept selected sent mail')

  await expectSuccess(baseUrl, 'mail:delete-many', {
    folder: 'trash',
    ids: [1],
  })
  const remainingTrash = await expectSuccess(
    baseUrl,
    'mail:list',
    { folder: 'trash' },
    true,
  )
  assert(
    !remainingTrash.items.some((message) => message.id === 1),
    'mail:delete-many kept permanently deleted trash mail',
  )
  assert(
    remainingTrash.items.some((message) => message.id === 4),
    'mail:delete-many removed non-selected trash mail',
  )

  const flareBeforeDelete = await expectSuccess(
    baseUrl,
    'flare:bootstrap',
    {},
    true,
  )
  assert(flareBeforeDelete.profile, 'flare:bootstrap did not include a profile')
  assert(
    flareBeforeDelete.profile.photoMediaIds.length >= 1 &&
      flareBeforeDelete.profile.photoMediaIds.length <= 6,
    'flare:bootstrap profile did not include one to six gallery photos',
  )
  assert.equal(
    flareBeforeDelete.profile.photoMediaIds.length,
    flareBeforeDelete.profile.photoUrls.length,
    'flare:bootstrap profile photo IDs and URLs were out of sync',
  )
  const galleryPhotoUrls = new Set(
    gallery
      .filter((item) => item.mediaType === 'photo')
      .map((item) => item.url),
  )
  assert(
    flareBeforeDelete.profile.photoUrls.every((url) =>
      galleryPhotoUrls.has(url),
    ),
    'flare:bootstrap profile used photos outside the phone gallery',
  )
  assert(
    flareBeforeDelete.suggestions.every(
      (profile) =>
        profile.photoUrls.length >= 1 &&
        profile.photoUrls.every((url) => galleryPhotoUrls.has(url)),
    ),
    'Flare suggestions used photos outside the phone gallery',
  )
  assert(
    flareBeforeDelete.matches.length > 0,
    'flare:bootstrap did not include a deletable match',
  )
  assert(
    flareBeforeDelete.matches.every(
      (match) =>
        match.profile.photoUrls.length >= 1 &&
        match.profile.photoUrls.every((url) => galleryPhotoUrls.has(url)),
    ),
    'Flare matches used photos outside the phone gallery',
  )
  const [removedProfilePhotoId, retainedProfilePhotoId] =
    flareBeforeDelete.profile.photoMediaIds
  await expectSuccess(baseUrl, 'gallery:delete', {
    id: removedProfilePhotoId,
  })
  const flareAfterGalleryDelete = await expectSuccess(
    baseUrl,
    'flare:bootstrap',
    {},
    true,
  )
  assert.deepEqual(
    flareAfterGalleryDelete.profile.photoMediaIds,
    [retainedProfilePhotoId],
    'gallery:delete did not remove the deleted photo from the Flare profile',
  )
  assert.deepEqual(
    flareAfterGalleryDelete.profile.photoUrls,
    [gallery.find((item) => item.id === retainedProfilePhotoId)?.url],
    'gallery:delete left Flare photo IDs and URLs out of sync',
  )
  const rejectedLastPhotoDelete = await post(baseUrl, 'gallery:delete', {
    id: retainedProfilePhotoId,
  })
  assert.deepEqual(rejectedLastPhotoDelete, {
    error: 'profile_photo_required',
    success: false,
  })
  const nonProfilePhotoId = gallery.find(
    (item) =>
      item.mediaType === 'photo' &&
      !flareBeforeDelete.profile.photoMediaIds.includes(item.id),
  )?.id
  const rejectedBulkLastPhotoDelete = await post(
    baseUrl,
    'gallery:delete-many',
    {
      correlationId: 'flare-last-photo-protection',
      ids: [retainedProfilePhotoId, nonProfilePhotoId],
    },
  )
  assert.deepEqual(rejectedBulkLastPhotoDelete, {
    error: 'profile_photo_required',
    success: false,
  })
  const swipedProfile = flareBeforeDelete.suggestions[0]
  await expectSuccess(baseUrl, 'flare:swipe', {
    choice: 'pass',
    targetId: swipedProfile.id,
  })
  const flareAfterSwipe = await expectSuccess(
    baseUrl,
    'flare:bootstrap',
    {},
    true,
  )
  assert(
    !flareAfterSwipe.suggestions.some(
      (profile) => profile.id === swipedProfile.id,
    ),
    'flare:swipe did not filter the swiped profile',
  )
  await expectSuccess(baseUrl, 'flare:delete-profile')
  const flareAfterDelete = await expectSuccess(
    baseUrl,
    'flare:bootstrap',
    {},
    true,
  )
  assert.equal(flareAfterDelete.profile, null)
  assert.deepEqual(flareAfterDelete.suggestions, [])
  assert.deepEqual(flareAfterDelete.likes, [])
  assert.deepEqual(flareAfterDelete.matches, [])
  const repeatedFlareDelete = await post(baseUrl, 'flare:delete-profile')
  assert.deepEqual(repeatedFlareDelete, {
    error: 'profile_not_found',
    success: false,
  })
  const rejectedEmptyFlare = await post(baseUrl, 'flare:save-profile', {
    ...flareBeforeDelete.profile,
    photoMediaIds: [],
    photoUrls: undefined,
  })
  assert.deepEqual(rejectedEmptyFlare, {
    error: 'invalid_profile_photos',
    success: false,
  })
  const flareStillDeleted = await expectSuccess(
    baseUrl,
    'flare:bootstrap',
    {},
    true,
  )
  assert.equal(
    flareStillDeleted.profile,
    null,
    'an invalid empty Flare profile was persisted',
  )
  const recreatedFlare = await expectSuccess(
    baseUrl,
    'flare:save-profile',
    {
      ...flareBeforeDelete.profile,
      photoMediaIds: [retainedProfilePhotoId],
      photoUrls: undefined,
    },
    true,
  )
  assert(
    recreatedFlare.suggestions.some(
      (profile) => profile.id === swipedProfile.id,
    ),
    'recreated Flare profile retained a deleted swipe filter',
  )
  assert.deepEqual(
    recreatedFlare.profile.photoMediaIds,
    [retainedProfilePhotoId],
    'recreated Flare profile did not retain its valid gallery photo',
  )

  await expectSuccess(baseUrl, 'account:logout')
  const signedOutFlareBootstrap = await post(baseUrl, 'flare:bootstrap')
  assert.deepEqual(signedOutFlareBootstrap, {
    error: 'not_authenticated',
    success: false,
  })
  const signedOutFlareDelete = await post(baseUrl, 'flare:delete-profile')
  assert.deepEqual(signedOutFlareDelete, {
    error: 'not_authenticated',
    success: false,
  })
}

async function main() {
  const server = app.listen(0, '127.0.0.1')
  await once(server, 'listening')
  const address = server.address()
  const baseUrl = `http://127.0.0.1:${address.port}`

  try {
    const dataByEndpoint = new Map()
    for (const [endpoint, body] of browserDataRequests) {
      dataByEndpoint.set(
        endpoint,
        await expectSuccess(baseUrl, endpoint, body, true),
      )
    }
    verifyBrowserTestData(dataByEndpoint)

    await verifyStatefulActions(baseUrl)

    const lifecycleEndpoints = [
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
      'ui:input-focus',
      'ui:live-activity',
      'ui:opened',
      'ui:ready',
    ]
    for (const endpoint of lifecycleEndpoints) {
      await expectSuccess(baseUrl, endpoint)
    }

    await expectSuccess(baseUrl, 'device:factory-reset')
    const resetBootstrap = await expectSuccess(
      baseUrl,
      'development:bootstrap',
      { _testScenario: 'setupPreview' },
      true,
    )
    assert.equal(
      resetBootstrap.device.data.settings.payload.settings.setupCompleted,
      false,
      'factory reset did not restore a browser-testable setup state',
    )

    const loggedRequests = []
    const originalConsoleLog = console.log
    try {
      console.log = (...values) => loggedRequests.push(values)
      await post(baseUrl, '%25s', { marker: 'format-string' })
    } finally {
      console.log = originalConsoleLog
    }
    assert.deepEqual(loggedRequests, [
      ['[NUI]', '%s', { marker: 'format-string' }],
    ])

    const unknown = await post(baseUrl, 'development:missing-mock', {})
    assert.deepEqual(unknown, {
      error: 'mock_endpoint_missing',
      success: false,
    })
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()))
    })
  }

  console.log(
    `Verified ${browserDataRequests.length} browser data endpoints and stateful app actions.`,
  )
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
