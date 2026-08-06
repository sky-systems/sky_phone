import type {
  MemoryCard,
  MemoryDifficulty,
  MemoryGameState,
} from './types'

export const MEMORY_PAIR_COUNTS: Record<MemoryDifficulty, number> = {
  small: 6,
  medium: 8,
  large: 10,
}

const MEMORY_SYMBOLS = [
  'star',
  'heart',
  'moon',
  'sun',
  'cloud',
  'bolt',
  'diamond',
  'circle',
  'triangle',
  'flower',
]

function shuffleCards(cards: MemoryCard[], random: () => number): MemoryCard[] {
  const shuffled = [...cards]

  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const target = Math.min(index, Math.floor(Math.max(0, random()) * (index + 1)))
    const current = shuffled[index]
    shuffled[index] = shuffled[target]
    shuffled[target] = current
  }

  return shuffled
}

export function createMemoryGame(
  difficulty: MemoryDifficulty,
  random: () => number = Math.random,
): MemoryGameState {
  const symbols = MEMORY_SYMBOLS.slice(0, MEMORY_PAIR_COUNTS[difficulty])
  const cards = symbols.flatMap((symbol) => [
    { id: `${symbol}-a`, state: 'hidden' as const, symbol },
    { id: `${symbol}-b`, state: 'hidden' as const, symbol },
  ])

  return {
    cards: shuffleCards(cards, random),
    difficulty,
    matchedPairs: 0,
    moves: 0,
    selectedIds: [],
    status: 'playing',
  }
}

export function flipMemoryCard(
  state: MemoryGameState,
  cardId: string,
): MemoryGameState {
  if (state.status !== 'playing') return state

  const selected = state.cards.find((card) => card.id === cardId)
  if (!selected || selected.state !== 'hidden') return state

  const cards = state.cards.map((card) =>
    card.id === cardId ? { ...card, state: 'revealed' as const } : card,
  )
  const selectedIds = [...state.selectedIds, cardId]
  if (selectedIds.length === 1) return { ...state, cards, selectedIds }

  const first = cards.find((card) => card.id === selectedIds[0])
  const second = cards.find((card) => card.id === selectedIds[1])
  const moves = state.moves + 1

  if (first?.symbol === second?.symbol) {
    const matchedCards = cards.map((card) =>
      selectedIds.includes(card.id)
        ? { ...card, state: 'matched' as const }
        : card,
    )
    const matchedPairs = state.matchedPairs + 1
    return {
      ...state,
      cards: matchedCards,
      matchedPairs,
      moves,
      selectedIds: [],
      status:
        matchedPairs === MEMORY_PAIR_COUNTS[state.difficulty]
          ? 'won'
          : 'playing',
    }
  }

  return { ...state, cards, moves, selectedIds, status: 'resolving' }
}

export function resolveMemoryMismatch(state: MemoryGameState): MemoryGameState {
  if (state.status !== 'resolving') return state

  return {
    ...state,
    cards: state.cards.map((card) =>
      state.selectedIds.includes(card.id)
        ? { ...card, state: 'hidden' as const }
        : card,
    ),
    selectedIds: [],
    status: 'playing',
  }
}
