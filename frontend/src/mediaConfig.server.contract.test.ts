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

  it('resolves uploads through their server-generated FiveManage path', () => {
    expect(mediaConfig).not.toContain('VerificationRetryDelaysMs')
    expect(mediaServer).toContain('upload_path = "sky_phone-" .. capture_token')
    expect(mediaServer).toContain(
      '"?limit=100&page=1&path=" .. SkyPhoneMediaImport.UrlEncode(state.upload_path)',
    )
    expect(mediaCapture).toContain("form.append('path', ready.uploadPath)")
    expect(memoRecorder).toContain("form.append('path', ready.uploadPath)")
    expect(mediaCapture).toContain('originalUrl: uploaded.originalUrl')
    expect(memoRecorder).toContain('originalUrl: uploaded.originalUrl')
    expect(mediaServer).toContain(
      'local verified_url = remote.url or remote.originalUrl',
    )
  })

  it('binds metadata verification to the FiveManage host that issued the upload URL', () => {
    expect(mediaServer).toContain('["api.fivemanage.com"] = true')
    expect(mediaServer).toContain('["fmapi.net"] = true')
    expect(mediaServer).toContain('provider_base_url = provider_base_url')
    expect(mediaServer).toContain('state.provider_base_url')
  })

  it('authenticates the exact returned ID from the filtered file list', () => {
    expect(mediaServer).toContain('remote.id == remote_id')
    expect(mediaServer).toContain(
      'FiveManage upload-path lookup found the exact uploaded file ID.',
    )
  })

  it('binds an unindexed upload to the server path before probing R2', () => {
    expect(mediaServer).toContain('host:lower() ~= "r2.fivemanage.com"')
    expect(mediaServer).toContain(
      'path:find("/" .. state.upload_path .. "/", 1, true)',
    )
    expect(mediaServer).toContain('object_id ~= remote_id')
    expect(mediaServer).toContain('"HEAD"')
    expect(mediaServer).toContain(
      'SkyPhoneMediaImport.ResponseHeader(response.headers, "content-type")',
    )
    expect(mediaServer).toContain(
      'SkyPhoneMediaImport.ResponseHeader(response.headers, "content-length")',
    )
  })
})
