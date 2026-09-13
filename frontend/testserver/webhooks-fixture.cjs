const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')

// Read names only. Never load file-configured webhook URLs into browser fixtures.
const source = readFileSync(
  resolve(__dirname, '../../sky_phone/config/WebHooks.lua'),
  'utf8',
)
const categories = [...source.matchAll(/^    (\w+) =/gm)]
  .map((match) => match[1])
  .filter(
    (key) =>
      ![
        'Enabled',
        'Username',
        'AvatarUrl',
        'Actions',
        'QueueLimit',
        'MaxAttempts',
      ].includes(key),
  )
const defaults = {
  Enabled: true,
  Username: 'Sky Phone',
  AvatarUrl: '',
  QueueLimit: 1000,
  MaxAttempts: 5,
}
const options = { ...defaults }
const rows = categories.map((path) => ({
  path,
  category: path,
  mode: 'file',
  effectiveMode: 'inherit',
  configured: false,
}))
for (const [action, category] of Object.entries({
  'calls:created': 'Calls',
  'calls:answered': 'Calls',
  'calls:ended': 'Calls',
  'skypic:send-snap': 'SkyPic',
  'skypic:delete-message': 'SkyPic',
  'picstagram:create-post': 'Picstagram',
  'admin:save-webhooks': 'Admin',
}))
  rows.push({
    path: `Actions.${action}`,
    category,
    mode: 'file',
    effectiveMode: 'inherit',
    configured: false,
  })
let revision = 0

function getWebhooks() {
  return {
    revision,
    defaults: { ...defaults },
    settings: { ...options },
    endpoints: rows.map((row) => ({ ...row })),
  }
}

function saveWebhooks(data) {
  if (data.revision !== revision)
    return { success: false, error: 'revision_conflict' }
  if (!Array.isArray(data.changes) || !data.changes.length)
    return { success: false, error: 'invalid_request' }
  const nextOptions = { ...options }
  const nextRows = rows.map((row) => ({ ...row }))
  for (const change of data.changes) {
    if (Object.hasOwn(defaults, change.path)) {
      nextOptions[change.path] =
        change.mode === 'file' ? defaults[change.path] : change.value
      continue
    }
    const row = nextRows.find((entry) => entry.path === change.path)
    if (!row) return { success: false, error: 'invalid_field' }
    if (!['file', 'inherit', 'disabled', 'custom'].includes(change.mode))
      return { success: false, error: 'invalid_value' }
    if (change.mode === 'custom' && (change.url || !row.configured)) {
      if (
        !/^https:\/\/(?:discord\.com|discordapp\.com|canary\.discord\.com|ptb\.discord\.com)\/api\/(?:v\d+\/)?webhooks\/\d+\/[\w-]+$/.test(
          change.url ?? '',
        )
      )
        return { success: false, error: 'invalid_webhook' }
    }
    row.mode = change.mode
    row.effectiveMode = change.mode === 'file' ? 'inherit' : change.mode
    row.configured = change.mode === 'custom'
  }
  Object.assign(options, nextOptions)
  rows.splice(0, rows.length, ...nextRows)
  revision += 1
  return { success: true, data: getWebhooks() }
}

module.exports = { getWebhooks, saveWebhooks }
