const fs = require('node:fs')
const path = require('node:path')

const licenseFilename = /^(?:licen[cs]e|copying)(?:[._-]|$)/i
const noticeFilename =
  /^(?:licen[cs]e|copying|notice|third[_-]?party[_-]?(?:licenses?|notices?(?:text)?))(?:[._-]|$)/i

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0
}

function resolvePackage(name, fromDirectory) {
  let directory = fromDirectory
  while (true) {
    const candidate = path.join(directory, 'node_modules', name, 'package.json')
    if (fs.existsSync(candidate))
      return path.dirname(fs.realpathSync(candidate))
    const parent = path.dirname(directory)
    if (parent === directory) return null
    directory = parent
  }
}

function readText(filename) {
  const text = fs.readFileSync(filename, 'utf8').replace(/\r\n?/g, '\n')
  if (!text.trim())
    throw new Error(`Empty third-party notice file: ${filename}`)
  return text
}

function fencedText(text) {
  const longestFence = Math.max(
    2,
    ...Array.from(text.matchAll(/`+/g), (match) => match[0].length),
  )
  const fence = '`'.repeat(longestFence + 1)
  return `${fence}text\n${text}${text.endsWith('\n') ? '' : '\n'}${fence}`
}

function generateThirdPartyNotices({
  frontendRoot,
  additionalNoticesPath = path.join(
    frontendRoot,
    '..',
    'licenses',
    'ADDITIONAL_NOTICES.md',
  ),
  packageLicenseOverridesPath = path.join(
    frontendRoot,
    '..',
    'licenses',
    'package-license-overrides.json',
  ),
}) {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(frontendRoot, 'package.json'), 'utf8'),
  )
  const additionalNotices = readText(additionalNoticesPath)
  const overrides = fs.existsSync(packageLicenseOverridesPath)
    ? JSON.parse(fs.readFileSync(packageLicenseOverridesPath, 'utf8'))
    : {}
  const packages = new Map()
  const visitedDirectories = new Set()

  function visit(name, fromDirectory, required, requestedBy) {
    const directory = resolvePackage(name, fromDirectory)
    if (!directory) {
      if (required)
        throw new Error(
          `Missing required dependency ${name}, requested by ${requestedBy}. Install the locked frontend dependencies before generating notices.`,
        )
      return
    }
    if (visitedDirectories.has(directory)) return
    visitedDirectories.add(directory)

    const pkg = JSON.parse(
      fs.readFileSync(path.join(directory, 'package.json'), 'utf8'),
    )
    if (
      !pkg.name ||
      !pkg.version ||
      typeof pkg.license !== 'string' ||
      !pkg.license.trim()
    ) {
      throw new Error(
        `Missing package name, version, or license metadata for ${name}, requested by ${requestedBy}.`,
      )
    }
    const identity = `${pkg.name}@${pkg.version}`
    if (!packages.has(identity)) {
      const files = fs
        .readdirSync(directory, { withFileTypes: true })
        .filter((entry) => entry.isFile() && noticeFilename.test(entry.name))
        .map((entry) => ({
          name: entry.name,
          text: readText(path.join(directory, entry.name)),
        }))
        .sort((left, right) => compareText(left.name, right.name))

      if (!files.some((file) => licenseFilename.test(file.name))) {
        const supplement = overrides[identity]
        if (
          !supplement ||
          typeof supplement.path !== 'string' ||
          typeof supplement.source !== 'string'
        ) {
          throw new Error(
            `Missing license text for ${identity}. Add a verified, exact-version package license supplement; a license identifier alone is insufficient.`,
          )
        }
        files.push({
          name: 'Upstream license supplement',
          source: supplement.source,
          text: readText(
            path.resolve(
              path.dirname(packageLicenseOverridesPath),
              supplement.path,
            ),
          ),
        })
      }

      const repository =
        typeof pkg.repository === 'string'
          ? pkg.repository
          : pkg.repository?.url
      const project = (pkg.homepage || repository || '')
        .replace(/^git\+/, '')
        .replace(/^git:\/\//, 'https://')
      packages.set(identity, { identity, license: pkg.license, project, files })
    }

    const dependencies = new Map()
    for (const dependency of Object.keys(pkg.peerDependencies || {})) {
      dependencies.set(
        dependency,
        !pkg.peerDependenciesMeta?.[dependency]?.optional,
      )
    }
    for (const dependency of Object.keys(pkg.dependencies || {}))
      dependencies.set(dependency, true)
    for (const dependency of Object.keys(pkg.optionalDependencies || {}))
      dependencies.set(dependency, false)
    for (const [dependency, isRequired] of dependencies)
      visit(dependency, directory, isRequired, identity)
  }

  const roots = new Set([
    ...Object.keys(manifest.dependencies || {}),
    'tailwindcss',
  ])
  for (const name of [...roots].sort(compareText))
    visit(name, path.resolve(frontendRoot), true, manifest.name || 'frontend')

  const sections = [
    '# Third-party notices',
    '<!-- Generated by frontend/scripts/third-party-notices.cjs. Do not edit this file directly. -->',
    'This distribution includes third-party software and data under their respective licenses. These notices do not relicense third-party material under the Sky Phone project license.',
    'The package inventory conservatively includes the installed dependency, peer-dependency, and optional-dependency graph of frontend runtime dependencies, plus Tailwind CSS because its generated styles are distributed. Graph membership does not mean that every listed package is included in the production bundle; compiler, type, and development support packages may be removed during the build. Build and test tools outside this graph are not inventoried here.',
    'Package versions and license declarations below come from the installed packages. License and notice texts are retained with normalized line endings. Exact-version upstream supplements cover packages whose published archive omits its license file.',
    additionalNotices.trimEnd(),
    `## Installed package inventory (${packages.size} packages)`,
  ]
  for (const pkg of [...packages.values()].sort((left, right) =>
    compareText(left.identity, right.identity),
  )) {
    sections.push(`### ${pkg.identity}`, `Declared license: \`${pkg.license}\``)
    if (pkg.project) sections.push(`Project: <${pkg.project}>`)
    for (const file of pkg.files) {
      sections.push(`#### ${file.name}`)
      if (file.source) sections.push(`Source: <${file.source}>`)
      sections.push(fencedText(file.text))
    }
  }
  return `${sections.join('\n\n')}\n`
}

module.exports = { generateThirdPartyNotices }

if (require.main === module) {
  try {
    const mode = process.argv[2]
    if (!['--write', '--check'].includes(mode) || process.argv.length !== 3) {
      throw new Error(
        'Usage: node scripts/third-party-notices.cjs --write|--check',
      )
    }
    const frontendRoot = path.resolve(__dirname, '..')
    const target = path.join(frontendRoot, '..', 'THIRD_PARTY_NOTICES.md')
    const generated = generateThirdPartyNotices({ frontendRoot })
    if (mode === '--write') {
      fs.writeFileSync(target, generated, 'utf8')
      console.log(
        'Generated THIRD_PARTY_NOTICES.md from the installed frontend dependency graph.',
      )
    } else {
      if (
        !fs.existsSync(target) ||
        fs.readFileSync(target, 'utf8').replace(/\r\n?/g, '\n') !== generated
      ) {
        throw new Error(
          'THIRD_PARTY_NOTICES.md is missing or outdated. Run node scripts/third-party-notices.cjs --write after installing the locked dependencies.',
        )
      }
      console.log(
        'THIRD_PARTY_NOTICES.md matches the installed frontend dependency graph.',
      )
    }
  } catch (error) {
    console.error(`Third-party notices: ${error.message}`)
    process.exitCode = 1
  }
}
