const fs = require('node:fs')
const path = require('node:path')

const frontendRoot = __dirname
const sourceDirectory = path.join(frontendRoot, 'dist')
const targetDirectory = path.join(
  frontendRoot,
  '..',
  'sky_phone',
  'source',
  'html',
)

if (!fs.existsSync(sourceDirectory)) {
  throw new Error(
    'Missing frontend/dist. Run vite build before publishing the NUI.',
  )
}

fs.rmSync(targetDirectory, { force: true, recursive: true })
fs.mkdirSync(targetDirectory, { recursive: true })
fs.cpSync(sourceDirectory, targetDirectory, { recursive: true })

const targetIndex = path.join(targetDirectory, 'index.html')
const normalizedIndex = fs
  .readFileSync(targetIndex, 'utf8')
  .replace(/\r\n?/g, '\n')
  .replace(/\n[ \t]*\n([ \t]*<\/body>)/g, '\n$1')
fs.writeFileSync(targetIndex, normalizedIndex)

console.log(`Published NUI to ${targetDirectory}`)
