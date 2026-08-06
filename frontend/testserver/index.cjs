const cors = require('cors')
const express = require('express')

const app = express()
const port = Number(process.argv[2]) || 3001

app.use(cors())
app.use(express.json())

let authenticated = true
let draft = null
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
    body: 'Welcome to iFruit Mail. Your shared mailbox is ready to use.',
    created_at: '2026-08-04 11:30:00',
    folder: 'inbox',
    id: 1,
    is_read: false,
    message_id: 'b73f3872-54cc-4d74-a058-6caa24f0dfff',
    preview: 'Welcome to iFruit Mail. Your shared mailbox is ready to use.',
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
const marketplaceListings = [
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf01', seller_account_id: 2, seller_name: 'morgan',
    seller_since: '2026-07-02 10:00:00', seller_active: 2, title: 'Sultan RS in excellent condition',
    description: 'Clean Sultan RS with fresh service, tidy interior and no known damage. Viewing and test drive available in Vinewood.',
    category: 'vehicles', item_condition: 'very_good', price_type: 'negotiable', price: 185000,
    district: 'vinewood', status: 'active', revision: 1, show_phone: 0, phone_number: null,
    created_at: '2026-08-06 09:20:00', updated_at: '2026-08-06 09:20:00', expires_at: '2026-08-13 09:20:00',
    image: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)', is_favorite: false,
    images: [{ media_id: 'capture-car', gradient: 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)', sort_order: 1 }],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf02', seller_account_id: 3, seller_name: 'jamie',
    seller_since: '2026-06-14 10:00:00', seller_active: 1, title: 'Modern apartment near Vespucci',
    description: 'Bright apartment with a city view, underground parking and modern furniture. Available immediately after viewing.',
    category: 'property', item_condition: 'very_good', price_type: 'fixed', price: 420000,
    district: 'vespucci', status: 'active', revision: 1, show_phone: 0, phone_number: null,
    created_at: '2026-08-05 17:10:00', updated_at: '2026-08-05 17:10:00', expires_at: '2026-08-12 17:10:00',
    image: 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)', is_favorite: true,
    images: [{ media_id: 'desert-road', gradient: 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)', sort_order: 1 }],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf03', seller_account_id: 4, seller_name: 'citytech',
    seller_since: '2026-05-22 10:00:00', seller_active: 3, title: 'Nearly new gaming laptop',
    description: 'Fast gaming laptop including charger and carrying bag. Runs quietly and can be tested before purchase.',
    category: 'electronics', item_condition: 'very_good', price_type: 'fixed', price: 3500,
    district: 'los_santos', status: 'reserved', revision: 2, show_phone: 0, phone_number: null,
    created_at: '2026-08-05 12:30:00', updated_at: '2026-08-06 08:00:00', expires_at: '2026-08-12 12:30:00',
    image: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)', is_favorite: false,
    images: [{ media_id: 'ocean-air', gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)', sort_order: 1 }],
  },
  {
    id: '81bc9d37-20e1-4d8a-82f8-f4b85f77cf04', seller_account_id: 1, seller_name: 'demo',
    seller_since: '2026-08-04 12:00:00', seller_active: 1, title: 'Complete mechanic tool set',
    description: 'Complete mechanic tool set with trolley, sockets and diagnostic equipment. Everything is clean and ready for work.',
    category: 'tools', item_condition: 'very_good', price_type: 'fixed', price: 7800,
    district: 'south_los_santos', status: 'active', revision: 1, show_phone: 1, phone_number: '5551234567',
    created_at: '2026-08-06 10:45:00', updated_at: '2026-08-06 10:45:00', expires_at: '2026-08-13 10:45:00',
    image: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)', is_favorite: false,
    images: [{ media_id: 'capture-tools', gradient: 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)', sort_order: 1 }],
  },
]
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
]
const deviceData = {}
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

function counts() {
  return {
    drafts: draft ? 1 : 0,
    inbox: messages.filter(
      (item) => item.folder === 'inbox' && !item.trashed_at,
    ).length,
    sent: messages.filter((item) => item.folder === 'sent' && !item.trashed_at)
      .length,
    trash: messages.filter((item) => item.trashed_at).length,
    unread: messages.filter(
      (item) => item.folder === 'inbox' && !item.trashed_at && !item.is_read,
    ).length,
  }
}

app.post('/api/:endpoint', (request, response) => {
  console.log(`[NUI] ${request.params.endpoint}`, request.body)
  const endpoint = request.params.endpoint
  if (endpoint === 'weather:get') {
    response.json({
      success: true,
      data: {
        clock: { year: 2026, month: 8, day: 5, hour: 17, minute: 20 },
        condition: 'partly_cloudy',
        rainLevel: 0.08,
        region: 'los_santos',
        windSpeed: 3.2,
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
  if (endpoint === 'device:factory-reset') {
    authenticated = false
    linkedAccount = null
    mockNotes = []
    for (const key of Object.keys(deviceData)) delete deviceData[key]
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:list') {
    const query = String(request.body.search ?? '').toLowerCase()
    let items = marketplaceListings.filter((item) => ['active', 'reserved'].includes(item.status))
    if (request.body.category && request.body.category !== 'all') items = items.filter((item) => item.category === request.body.category)
    if (request.body.district && request.body.district !== 'all') items = items.filter((item) => item.district === request.body.district)
    if (query) items = items.filter((item) => `${item.title} ${item.description}`.toLowerCase().includes(query))
    if (request.body.favorites) items = items.filter((item) => item.is_favorite)
    response.json({ success: true, data: { hasMore: false, items, offset: 0 } })
    return
  }
  if (endpoint === 'marketplace:get') {
    const item = marketplaceListings.find((listing) => listing.id === request.body.id)
    response.json(item ? { success: true, data: { ...item, is_owner: authenticated && item.seller_account_id === 1 } } : { success: false, error: 'listing_not_found' })
    return
  }
  if (endpoint.startsWith('marketplace:') && !authenticated) {
    response.json({ success: false, error: 'not_authenticated' })
    return
  }
  if (endpoint === 'marketplace:counts') {
    response.json({ success: true, data: { active: marketplaceListings.filter((item) => item.seller_account_id === 1 && ['active', 'reserved'].includes(item.status)).length, unread: marketplaceInquiries.reduce((total, item) => total + item.unread, 0) } })
    return
  }
  if (endpoint === 'marketplace:list-own') {
    response.json({ success: true, data: { hasMore: false, items: marketplaceListings.filter((item) => item.seller_account_id === 1), offset: 0 } })
    return
  }
  if (endpoint === 'marketplace:create') {
    const id = `81bc9d37-20e1-4d8a-82f8-${String(Date.now()).slice(-12)}`
    const selected = request.body.images.map((image) => {
      const photo = { 'sunset-drive': 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)', 'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)', 'city-lights': 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)', 'desert-road': 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)' }[image.id] ?? 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)'
      return { media_id: image.id, gradient: photo, sort_order: 1 }
    })
    marketplaceListings.unshift({ ...request.body, id, seller_account_id: 1, seller_name: 'demo', seller_since: '2026-08-04 12:00:00', seller_active: 1, item_condition: request.body.condition, price_type: request.body.priceType, show_phone: request.body.showPhone ? 1 : 0, phone_number: null, status: 'active', revision: 1, created_at: '2026-08-06 11:00:00', updated_at: '2026-08-06 11:00:00', expires_at: '2026-08-13 11:00:00', images: selected, image: selected[0]?.gradient, is_favorite: false })
    response.json({ success: true, data: { id } })
    return
  }
  if (endpoint === 'marketplace:update') {
    const item = marketplaceListings.find((listing) => listing.id === request.body.id)
    if (!item) {
      response.json({ success: false, error: 'listing_not_found' })
      return
    }
    const selected = request.body.images.map((image, index) => ({
      media_id: image.id,
      gradient: { 'sunset-drive': 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)', 'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)', 'city-lights': 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)', 'desert-road': 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)' }[image.id] ?? item.image,
      sort_order: index + 1,
    }))
    Object.assign(item, request.body, {
      image: selected[0]?.gradient,
      images: selected,
      item_condition: request.body.condition,
      price_type: request.body.priceType,
      revision: item.revision + 1,
    })
    response.json({ success: true, data: { revision: item.revision } })
    return
  }
  if (endpoint === 'marketplace:favorite') {
    const item = marketplaceListings.find((listing) => listing.id === request.body.id)
    if (item) item.is_favorite = request.body.favorite
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:set-status') {
    const item = marketplaceListings.find((listing) => listing.id === request.body.id)
    if (item) item.status = request.body.status
    response.json({ success: true })
    return
  }
  if (endpoint === 'marketplace:list-inquiries') {
    response.json({ success: true, data: marketplaceInquiries })
    return
  }
  if (endpoint === 'marketplace:send-message') {
    let inquiry = marketplaceInquiries.find((item) => item.id === request.body.inquiryId || item.listing_id === request.body.listingId)
    if (!inquiry) {
      const listing = marketplaceListings.find((item) => item.id === request.body.listingId)
      inquiry = { id: '4903b923-409a-437e-971f-b7a2b10e9e31', listing_id: listing.id, seller_account_id: listing.seller_account_id, buyer_account_id: 1, title: listing.title, price: listing.price, price_type: listing.price_type, status: listing.status, image: listing.image, other_name: listing.seller_name, last_message: request.body.body, offer_id: null, offer_amount: null, offer_proposer_account_id: null, offer_status: null, offer_revision: 0, unread: 0, updated_at: '2026-08-06 11:30:00' }
      marketplaceInquiries.push(inquiry)
    }
    marketplaceMessages.push({ id: marketplaceMessages.length + 1, inquiry_id: inquiry.id, sender_account_id: 1, body: request.body.body, created_at: '2026-08-06 12:00:00', read_at: null })
    inquiry.last_message = request.body.body
    inquiry.unread = 0
    inquiry.updated_at = '2026-08-06 12:00:00'
    response.json({ success: true, data: { id: inquiry.id } })
    return
  }
  if (endpoint === 'marketplace:get-inquiry') {
    const inquiry = marketplaceInquiries.find((item) => item.id === request.body.id)
    if (inquiry) {
      inquiry.unread = 0
      for (const offer of marketplaceOffers) {
        if (offer.inquiry_id === inquiry.id && offer.proposer_account_id !== 1) offer.read_at = '2026-08-06 12:01:00'
        if (offer.inquiry_id === inquiry.id && offer.proposer_account_id === 1 && ['accepted', 'rejected'].includes(offer.status)) offer.response_read_at = '2026-08-06 12:01:00'
      }
    }
    const listing = inquiry && marketplaceListings.find((item) => item.id === inquiry.listing_id)
    response.json(inquiry ? { success: true, data: { accountId: 1, inquiry: { ...inquiry, reserved_account_id: listing.reserved_account_id ?? null, status: listing.status }, messages: marketplaceMessages.filter((message) => message.inquiry_id === inquiry.id), offers: marketplaceOffers.filter((offer) => offer.inquiry_id === inquiry.id) } } : { success: false, error: 'inquiry_not_found' })
    return
  }
  if (endpoint === 'marketplace:make-offer') {
    const inquiry = marketplaceInquiries.find((item) => item.id === request.body.inquiryId)
    const amount = Number(request.body.amount)
    if (!inquiry || !Number.isInteger(amount) || amount < 1) {
      response.json({ success: false, error: 'invalid_offer' })
      return
    }
    if (inquiry.offer_status === 'accepted') {
      response.json({ success: false, error: 'offer_closed' })
      return
    }
    if (inquiry.offer_status === 'pending' && inquiry.offer_proposer_account_id === 1) {
      response.json({ success: false, error: 'offer_waiting' })
      return
    }
    const previous = marketplaceOffers.find((offer) => offer.id === inquiry.offer_id)
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
    const inquiry = marketplaceInquiries.find((item) => item.id === request.body.inquiryId)
    const offer = inquiry && marketplaceOffers.find((item) => item.id === inquiry.offer_id)
    if (!inquiry || !offer || offer.status !== 'pending' || offer.proposer_account_id === 1) {
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
      const listing = marketplaceListings.find((item) => item.id === inquiry.listing_id)
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
  if (endpoint === 'mail:list') {
    const { folder, search = '' } = request.body
    let items =
      folder === 'drafts'
        ? draft
          ? [{ ...draft, created_at: draft.updated_at, preview: draft.body }]
          : []
        : messages.filter((item) =>
            folder === 'trash'
              ? item.trashed_at
              : item.folder === folder && !item.trashed_at,
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
  response.json({ success: true })
})

app.listen(port, () => {
  console.log(`Mock NUI server listening on http://localhost:${port}`)
})
