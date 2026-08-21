import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const mediaConfig = readFileSync(
  new URL('../../sky_phone/config/media.lua', import.meta.url),
  'utf8',
)
const manifest = readFileSync(
  new URL('../../sky_phone/fxmanifest.lua', import.meta.url),
  'utf8',
)
const mediaProviderConfig = readFileSync(
  new URL(
    '../../sky_phone/source/server/media_provider_config.lua',
    import.meta.url,
  ),
  'utf8',
)
const mediaImportAdapter = readFileSync(
  new URL(
    '../../sky_phone/source/server/media_import/fivemanage.lua',
    import.meta.url,
  ),
  'utf8',
)
const mediaServer = readFileSync(
  new URL('../../sky_phone/source/server/media.lua', import.meta.url),
  'utf8',
)
const memoServer = readFileSync(
  new URL('../../sky_phone/source/server/memos.lua', import.meta.url),
  'utf8',
)
const mediaCapture = readFileSync(
  new URL('./components/PhoneMediaCapture.vue', import.meta.url),
  'utf8',
)
const memoRecorder = readFileSync(
  new URL('./components/PhoneMemoRecorder.vue', import.meta.url),
  'utf8',
)

describe('FiveManage server configuration contract', () => {
  it('keeps the provider token in the server-only media config', () => {
    expect(mediaConfig).toMatch(/FiveManage\s*=\s*{\s*ApiKey\s*=/)
    expect(mediaProviderConfig).toContain(
      'return trim_key(Config.Media.FiveManage.ApiKey)',
    )
    expect(mediaProviderConfig).not.toContain('GetConvar')
  })

  it('uses one resolver for Camera uploads and FiveManage imports', () => {
    expect(
      manifest.indexOf("'source/server/media_provider_config.lua'"),
    ).toBeLessThan(manifest.indexOf("'source/server/media_import.lua'"))
    expect(mediaServer).toContain(
      'SkyPhoneMediaProviderConfig.FiveManageApiKey()',
    )
    expect(mediaImportAdapter).toContain(
      'SkyPhoneMediaProviderConfig.FiveManageApiKey(website.ApiKey)',
    )
  })

  it('uses the direct FiveManage upload response flow for Camera and voice memos', () => {
    expect(mediaConfig).not.toContain('VerificationRetryDelaysMs')
    expect(mediaCapture).toContain("form.append('file', blob, fileName)")
    expect(mediaCapture).not.toContain("form.append('path'")
    expect(mediaCapture).not.toContain("form.append(\n    'metadata'")
    expect(memoRecorder).toContain(
      "form.append('file', pending.blob, pending.fileName)",
    )
    expect(memoRecorder).not.toContain("form.append('path'")
    expect(memoRecorder).not.toContain("form.append(\n    'metadata'")
    expect(mediaServer).toContain(
      'Accepting the direct FiveManage upload response',
    )
    expect(mediaServer).toContain('remote_id = remote_id')
    expect(mediaServer).toContain('url = uploaded_url')
    expect(mediaServer).not.toContain('"HEAD"')
    expect(mediaServer).not.toContain('authenticated upload-path lookup')
  })

  it('allowlists the FiveManage API and media hosts', () => {
    expect(mediaServer).toContain('["api.fivemanage.com"] = true')
    expect(mediaServer).toContain('["fmapi.net"] = true')
    expect(mediaServer).toContain(
      'uploaded_host:lower() ~= "r2.fivemanage.com"',
    )
  })

  it('validates and preserves the recorded memo size before upload', () => {
    expect(memoRecorder).toContain('sizeBytes: blob.size')
    expect(memoServer).toContain(
      'local size_bytes = tonumber(data.sizeBytes)',
    )
    expect(memoServer).toContain(
      'size_bytes < 1 or size_bytes > Config.Memos.MaximumBytes',
    )
    expect(memoServer).toContain('size_bytes = memo.size_bytes')
    expect(mediaServer).toContain('size = state.size_bytes')
  })
})
