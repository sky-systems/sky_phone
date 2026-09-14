import { createPinia, setActivePinia } from 'pinia'
import { describe, expect, it } from 'vitest'

import { snakeProgression } from './progression'
import { useSnakeStore } from './store'

describe('Snake levels', () => {
  it.each([
    [0, 1, 'apple', 'green'],
    [9, 1, 'apple', 'green'],
    [10, 2, 'strawberry', 'green'],
    [20, 3, 'orange', 'green'],
    [29, 3, 'orange', 'green'],
    [30, 4, 'grapes', 'blue'],
    [40, 5, 'banana', 'blue'],
    [50, 6, 'watermelon', 'blue'],
    [60, 7, 'apple', 'gold'],
    [90, 10, 'grapes', 'violet'],
    [120, 13, 'apple', 'green'],
    [477, 48, 'watermelon', 'violet'],
  ])('score %i selects level %i with %s and %s', (score, level, food, skin) => {
    const result = snakeProgression(score)
    expect(result.level).toBe(level)
    expect(result.food.id).toBe(food)
    expect(result.skin.id).toBe(skin)
    expect(result.nextLevelScore).toBeGreaterThan(score)
    expect(result.progress).toBe(score % 10)
  })

  it('changes fruit and skin on the scoring tick, preserves them on pause, and resets on restart', () => {
    setActivePinia(createPinia())
    const snake = useSnakeStore()
    snake.start()
    snake.game!.score = 29
    snake.game!.fruit = {
      x: snake.game!.body[0].x + 1,
      y: snake.game!.body[0].y,
    }
    snake.tick()
    expect(snake.progression.level).toBe(4)
    expect(snake.progression.food.id).toBe('grapes')
    expect(snake.progression.skin.id).toBe('blue')
    snake.pause()
    snake.tick()
    expect(snake.progression.level).toBe(4)
    snake.start()
    expect(snake.progression.level).toBe(1)
    expect(snake.progression.skin.id).toBe('green')
  })
})
