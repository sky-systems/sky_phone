const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { test } = require('node:test')
const { generateThirdPartyNotices } = require('../third-party-notices.cjs')

function fixture(context, dependencies) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sky-phone-notices-test-'))
  context.after(() => {
    assert.equal(path.dirname(root), fs.realpathSync(os.tmpdir()))
    fs.rmSync(root, { recursive: true, force: true })
  })
  const frontendRoot = path.join(root, 'frontend')
  fs.mkdirSync(frontendRoot)
  fs.writeFileSync(
    path.join(frontendRoot, 'package.json'),
    JSON.stringify({ name: 'fixture', dependencies }),
  )
  const additionalNoticesPath = path.join(root, 'ADDITIONAL_NOTICES.md')
  fs.writeFileSync(
    additionalNoticesPath,
    '## Additional notices\n\nCurated copyright notice.\n',
  )
  const options = {
    frontendRoot,
    additionalNoticesPath,
    packageLicenseOverridesPath: path.join(root, 'overrides.json'),
  }
  writePackage(path.join(frontendRoot, 'node_modules', 'tailwindcss'), {
    name: 'tailwindcss',
    version: '1.0.0',
  })
  return { root, frontendRoot, options }
}

function writePackage(
  directory,
  metadata,
  license = 'Copyright Fixture\nPermission notice.\n',
) {
  fs.mkdirSync(directory, { recursive: true })
  fs.writeFileSync(
    path.join(directory, 'package.json'),
    JSON.stringify({
      license: 'MIT',
      homepage: 'https://example.org/project',
      ...metadata,
    }),
  )
  if (license !== null)
    fs.writeFileSync(path.join(directory, 'LICENSE'), license)
}

test('collects scoped pnpm packages, nested dependencies and full notices deterministically', (context) => {
  const { frontendRoot, options } = fixture(context, {
    '@scope/widget': '1.0.0',
  })
  const modules = path.join(frontendRoot, 'node_modules')
  const store = path.join(modules, '.pnpm', 'widget@1.0.0', 'node_modules')
  const widget = path.join(store, '@scope', 'widget')
  writePackage(
    widget,
    {
      name: '@scope/widget',
      version: '1.0.0',
      exports: { '.': './index.js' },
      dependencies: { nested: '2.0.0' },
      optionalDependencies: { unavailable: '1.0.0' },
      peerDependencies: { 'optional-peer': '1.0.0' },
      peerDependenciesMeta: { 'optional-peer': { optional: true } },
    },
    'Copyright Widget\nKeep these `ticks` and blank lines.\n\nEnd.\n',
  )
  fs.writeFileSync(path.join(widget, 'NOTICE.txt'), 'Additional attribution.\n')
  fs.writeFileSync(
    path.join(widget, 'ThirdPartyNoticeText.txt'),
    'Inherited third-party notices.\n',
  )
  writePackage(path.join(store, 'nested'), { name: 'nested', version: '2.0.0' })
  writePackage(path.join(modules, 'unrelated'), {
    name: 'unrelated',
    version: '8.0.0',
  })
  fs.mkdirSync(path.join(modules, '@scope'))
  fs.symlinkSync(widget, path.join(modules, '@scope', 'widget'), 'junction')

  const generated = generateThirdPartyNotices(options)
  assert.match(generated, /### @scope\/widget@1\.0\.0/)
  assert.match(generated, /### nested@2\.0\.0/)
  assert.match(generated, /### tailwindcss@1\.0\.0/)
  assert.match(
    generated,
    /Copyright Widget\nKeep these `ticks` and blank lines\.\n\nEnd\./,
  )
  assert.match(
    generated,
    /#### NOTICE\.txt\n\n```text\nAdditional attribution\./,
  )
  assert.match(
    generated,
    /#### ThirdPartyNoticeText\.txt\n\n```text\nInherited third-party notices\./,
  )
  assert.doesNotMatch(generated, /unrelated@|unavailable@|optional-peer@/)
  assert.ok(!generated.includes(frontendRoot))
  assert.equal(generateThirdPartyNotices(options), generated)

  fs.writeFileSync(
    path.join(frontendRoot, 'package.json'),
    JSON.stringify({
      name: 'fixture',
      dependencies: { tailwindcss: '1.0.0', '@scope/widget': '1.0.0' },
    }),
  )
  assert.equal(generateThirdPartyNotices(options), generated)
})

test('fails when a required dependency or required peer is not installed', (context) => {
  const { frontendRoot, options } = fixture(context, { missing: '1.0.0' })
  assert.throws(
    () => generateThirdPartyNotices(options),
    /Missing required dependency missing/,
  )
  writePackage(path.join(frontendRoot, 'node_modules', 'missing'), {
    name: 'missing',
    version: '1.0.0',
    peerDependencies: { 'required-peer': '1.0.0' },
  })
  assert.throws(
    () => generateThirdPartyNotices(options),
    /Missing required dependency required-peer/,
  )
})

test('requires license text and accepts only a verified supplement for the exact version', (context) => {
  const { root, frontendRoot, options } = fixture(context, { bare: '2.0.0' })
  writePackage(
    path.join(frontendRoot, 'node_modules', 'bare'),
    { name: 'bare', version: '2.0.0' },
    null,
  )
  assert.throws(
    () => generateThirdPartyNotices(options),
    /Missing license text for bare@2\.0\.0/,
  )
  fs.writeFileSync(
    path.join(root, 'bare-LICENSE'),
    'Copyright Bare\nOriginal upstream permission.\n',
  )
  const supplement = {
    path: 'bare-LICENSE',
    source: 'https://example.org/bare/v2/LICENSE',
  }
  fs.writeFileSync(
    options.packageLicenseOverridesPath,
    JSON.stringify({ 'bare@1.0.0': supplement }),
  )
  assert.throws(
    () => generateThirdPartyNotices(options),
    /Missing license text for bare@2\.0\.0/,
  )
  fs.writeFileSync(
    options.packageLicenseOverridesPath,
    JSON.stringify({ 'bare@2.0.0': supplement }),
  )
  const generated = generateThirdPartyNotices(options)
  assert.match(generated, /Source: <https:\/\/example\.org\/bare\/v2\/LICENSE>/)
  assert.match(generated, /Copyright Bare\nOriginal upstream permission\./)
})
