import banana from '@/assets/img/games/snake/banana.webp'
import blue from '@/assets/img/games/snake/blue.webp'
import gold from '@/assets/img/games/snake/gold.webp'
import grapes from '@/assets/img/games/snake/grapes.webp'
import orange from '@/assets/img/games/snake/orange.webp'
import strawberry from '@/assets/img/games/snake/strawberry.webp'
import violet from '@/assets/img/games/snake/violet.webp'
import watermelon from '@/assets/img/games/snake/watermelon.webp'

export const SNAKE_FOODS = [
  { id: 'apple', image: null },
  { id: 'strawberry', image: strawberry },
  { id: 'orange', image: orange },
  { id: 'grapes', image: grapes },
  { id: 'banana', image: banana },
  { id: 'watermelon', image: watermelon },
] as const

export const SNAKE_SKINS = [
  { id: 'green', image: null, body: '#6dcc62', tail: '#62be5c' },
  { id: 'blue', image: blue, body: '#49bfeb', tail: '#32addb' },
  { id: 'gold', image: gold, body: '#ffc957', tail: '#edaa36' },
  { id: 'violet', image: violet, body: '#b887f1', tail: '#a575dc' },
] as const

export function snakeProgression(score: number) {
  const points = Number.isFinite(score) ? Math.max(0, Math.floor(score)) : 0
  return {
    level: Math.floor(points / 10) + 1,
    progress: points % 10,
    nextLevelScore: (Math.floor(points / 10) + 1) * 10,
    food: SNAKE_FOODS[Math.floor(points / 10) % SNAKE_FOODS.length],
    skin: SNAKE_SKINS[Math.floor(points / 30) % SNAKE_SKINS.length],
  }
}
