type LuaToken = {
  kind: string
  value: string
}

function tokenizeLua(source: string): LuaToken[] {
  const tokens: LuaToken[] = []
  let index = 0
  while (index < source.length) {
    const character = source[index]
    if (/\s/.test(character)) {
      index += 1
      continue
    }
    if (source.startsWith('--', index)) {
      const nextLine = source.indexOf('\n', index)
      if (nextLine < 0) break
      index = nextLine
      continue
    }
    if ('{}[]=,;'.includes(character)) {
      tokens.push({ kind: character, value: character })
      index += 1
      continue
    }
    if (character === '"' || character === "'") {
      const quote = character
      let value = ''
      index += 1
      while (index < source.length && source[index] !== quote) {
        if (source[index] === '\\' && index + 1 < source.length) {
          value += source[index + 1]
          index += 2
        } else {
          value += source[index]
          index += 1
        }
      }
      tokens.push({ kind: 'string', value })
      index += 1
      continue
    }
    const match = source
      .slice(index)
      .match(/^[A-Za-z_][A-Za-z0-9_]*|^-?\d+(?:\.\d+)?/)
    if (match) {
      tokens.push({ kind: 'word', value: match[0] })
      index += match[0].length
      continue
    }
    index += 1
  }
  return tokens
}

export function collectLuaLocaleValues(source: string): Map<string, string> {
  const tokens = tokenizeLua(source)
  let position =
    tokens.findIndex(
      (token, index) => token.kind === '=' && tokens[index + 1]?.kind === '{',
    ) + 1
  const values = new Map<string, string>()

  function parseValue(path: string[]): void {
    if (tokens[position]?.kind === '{') {
      parseTable(path)
      return
    }
    if (path.length) values.set(path.join('.'), tokens[position]?.value ?? '')
    position += 1
  }

  function parseTable(path: string[]): void {
    position += 1
    while (position < tokens.length && tokens[position].kind !== '}') {
      let key: string | null = null
      if (
        tokens[position].kind === 'word' &&
        tokens[position + 1]?.kind === '='
      ) {
        key = tokens[position].value
        position += 2
      } else if (
        tokens[position].kind === '[' &&
        tokens[position + 1]?.kind === 'string' &&
        tokens[position + 2]?.kind === ']' &&
        tokens[position + 3]?.kind === '='
      ) {
        key = tokens[position + 1].value
        position += 4
      }
      parseValue(key === null ? [] : [...path, key])
      while (tokens[position]?.kind === ',' || tokens[position]?.kind === ';') {
        position += 1
      }
    }
    position += 1
  }

  parseTable([])
  while (position < tokens.length) {
    const assignment = tokens.findIndex(
      (token, index) => index >= position && token.kind === '=',
    )
    if (assignment < 0) break
    const nui = tokens.findIndex(
      (token, index) =>
        index >= position && index < assignment && token.value === 'Nui',
    )
    if (nui < 0) {
      position = assignment + 1
      continue
    }
    const path = [
      'Nui',
      ...tokens
        .slice(nui + 1, assignment)
        .filter((token) => token.kind === 'word')
        .map((token) => token.value),
    ]
    position = assignment + 1
    parseValue(path)
  }
  return values
}
