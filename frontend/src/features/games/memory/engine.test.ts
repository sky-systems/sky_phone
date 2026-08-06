import { describe, expect, it } from 'vitest'

import {
  createMemoryGame,
  flipMemoryCard,
  MEMORY_PAIR_COUNTS,
  resolveMemoryMismatch,
} from './engine'

describe('Memory engine', () => {
  it.each(['small', 'medium', 'large'] as const)(
    'creates exactly two cards per symbol for %s',
    (difficulty) => {
      const game = createMemoryGame(difficulty, () => 0.5)
      const counts = game.cards.reduce<Record<string, number>>((result, card) => {
        result[card.symbol] = (result[card.symbol] ?? 0) + 1
        return result
      }, {})

      expect(game.cards).toHaveLength(MEMORY_PAIR_COUNTS[difficulty] * 2)
      expect(Object.values(counts).every((count) => count === 2)).toBe(true)
    },
  )

  it('does not count the same card twice', () => {
    const game = createMemoryGame('small', () => 0)
    const once = flipMemoryCard(game, game.cards[0].id)

    expect(flipMemoryCard(once, game.cards[0].id)).toBe(once)
    expect(once.moves).toBe(0)
  })

  it('matches equal cards and counts one move', () => {
    const game = createMemoryGame('small', () => 0)
    const pair = game.cards.filter((card) => card.symbol === game.cards[0].symbol)
    const first = flipMemoryCard(game, pair[0].id)
    const second = flipMemoryCard(first, pair[1].id)

    expect(second.moves).toBe(1)
    expect(second.matchedPairs).toBe(1)
    expect(second.selectedIds).toEqual([])
    expect(second.cards.filter((card) => card.state === 'matched')).toHaveLength(2)
  })

  it('blocks a third card until a mismatch is resolved', () => {
    const game = createMemoryGame('small', () => 0)
    const firstCard = game.cards[0]
    const secondCard = game.cards.find((card) => card.symbol !== firstCard.symbol)!
    const thirdCard = game.cards.find(
      (card) => card.symbol !== firstCard.symbol && card.id !== secondCard.id,
    )!
    const first = flipMemoryCard(game, firstCard.id)
    const mismatch = flipMemoryCard(first, secondCard.id)

    expect(mismatch.status).toBe('resolving')
    expect(flipMemoryCard(mismatch, thirdCard.id)).toBe(mismatch)
    expect(resolveMemoryMismatch(mismatch).selectedIds).toEqual([])
  })

  it('marks the completed round as won exactly on the final pair', () => {
    let game = createMemoryGame('small', () => 0)
    const symbols = [...new Set(game.cards.map((card) => card.symbol))]

    for (const symbol of symbols) {
      const pair = game.cards.filter((card) => card.symbol === symbol)
      game = flipMemoryCard(game, pair[0].id)
      game = flipMemoryCard(game, pair[1].id)
    }

    expect(game.status).toBe('won')
    expect(game.moves).toBe(MEMORY_PAIR_COUNTS.small)
    expect(flipMemoryCard(game, game.cards[0].id)).toBe(game)
  })
})
