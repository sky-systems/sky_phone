export type MemoryDifficulty = 'small' | 'medium' | 'large'

export type MemoryCardState = 'hidden' | 'revealed' | 'matched'

export type MemoryCard = {
  id: string
  state: MemoryCardState
  symbol: string
}

export type MemoryGameStatus = 'playing' | 'resolving' | 'won'

export type MemoryGameState = {
  cards: MemoryCard[]
  difficulty: MemoryDifficulty
  matchedPairs: number
  moves: number
  selectedIds: string[]
  status: MemoryGameStatus
}

export type MemoryBest = {
  moves: number
  timeMs: number
}
