const cors = require('cors')
const express = require('express')

const app = express()
const port = Number(process.argv[2]) || 3001

app.use(cors())
app.use(express.json())

let authenticated = false
let draft = null
let linkedAccount = null
let mockNotes = []
const deviceData = {}
let contactSequence = 2
const contacts = [
  {
    created_at: '2026-08-04 12:00:00',
    id: 'contact-1',
    name: 'Jenica Chong',
    phone_number: '5558675309',
    updated_at: '2026-08-04 12:00:00',
  },
]
const attachmentAssets = {
  gif: new Set(['celebrate', 'hearts', 'party', 'thumbs_up', 'wow']),
  image: new Set([
    'camera-1', 'camera-2', 'camera-3', 'city-lights', 'desert-road',
    'ocean-air', 'sunset-drive',
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
  if (endpoint === 'messages:gifs') {
    const offset = Math.max(0, Number(request.body.offset ?? 0))
    const pageSize = 6
    const results = gifMocks.slice(offset, offset + pageSize).map(([id, title]) => ({
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
  if (endpoint === 'messages:thread') {
    const number = String(request.body.phoneNumber)
    const thread = smsMessages.filter(
      (message) =>
        message.sender_number === number || message.recipient_number === number,
    )
    for (const message of thread) {
      if (message.direction === 'received') message.read_at = message.read_at ?? '2026-08-06 13:06:00'
    }
    response.json({
      success: true,
      data: thread.map(({ media_payload, ...message }) => ({
        ...message,
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
    const attachmentId = String(request.body.mediaAssetId ?? '')
    if (
      !phoneNumber ||
      (messageType === 'text' && !body) ||
      (messageType === 'voice' && !request.body.mediaPayload) ||
      (isAttachment &&
        !attachmentAssets[messageType].has(attachmentId) &&
        !attachmentId.startsWith('https://'))
    ) {
      response.json({ success: false, error: 'invalid_message' })
      return
    }
    const message = {
      body,
      created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      direction: 'sent',
      id: `sms-${Date.now()}`,
      media_duration_ms:
        ['voice', 'video'].includes(messageType)
          ? request.body.mediaDurationMs ?? null
          : null,
      media_mime:
        messageType === 'voice'
          ? request.body.mediaMime
          : messageType === 'image'
            ? 'image/jpeg'
            : messageType === 'gif'
              ? 'image/gif'
              : messageType === 'video'
                ? 'video/mp4'
                : null,
      media_payload:
        messageType === 'voice'
          ? request.body.mediaPayload
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
    const phoneNumber = String(request.body.phoneNumber ?? '').trim()
    if (!name || !phoneNumber) {
      response.json({ success: false, error: 'invalid_contact' })
      return
    }
    let contact = contacts.find((item) => item.id === request.body.id)
    if (contact) {
      contact.name = name
      contact.phone_number = phoneNumber
      contact.updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ')
    } else {
      const now = new Date().toISOString().slice(0, 19).replace('T', ' ')
      contact = {
        created_at: now,
        id: `contact-${contactSequence++}`,
        name,
        phone_number: phoneNumber,
        updated_at: now,
      }
      contacts.push(contact)
    }
    response.json({ success: true, data: contact })
    return
  }
  if (endpoint === 'contacts:delete') {
    const index = contacts.findIndex((item) => item.id === request.body.id)
    if (index >= 0) contacts.splice(index, 1)
    response.json({ success: true })
    return
  }
  if (endpoint === 'account:login' || endpoint === 'account:register') {
    authenticated = true
    linkedAccount = {
      devices: accountDevices,
      email: request.body.email.includes('@')
        ? request.body.email
        : `${request.body.email}@ifruit.com`,
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
