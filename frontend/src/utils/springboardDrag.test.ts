import { describe, expect, it } from 'vitest'

import {
  maximumRenderedWidgetPage,
  nearestSpringboardRectIndex,
  resolveSpringboardEdgeTurn,
  resolveSpringboardHomeEdgeTurn,
  springboardEdgeDirection,
  springboardPageDragCompensation,
  springboardSwipeIntent,
  springboardViewportDeltaToLocal,
  springboardViewportToLocal,
} from '@/utils/springboardDrag'

describe('springboard widget drag', () => {
  it('turns pages from the reachable phone edge zones', () => {
    expect(springboardEdgeDirection(113, 100, 468)).toBe(-1)
    expect(springboardEdgeDirection(455, 100, 468)).toBe(1)
    expect(springboardEdgeDirection(284, 100, 468)).toBe(0)
  })

  it('keeps both phone edges reachable at normal and reduced FiveM scales', () => {
    expect(springboardEdgeDirection(125, 100, 468)).toBe(-1)
    expect(springboardEdgeDirection(150, 100, 468)).toBe(0)
    expect(springboardEdgeDirection(420, 100, 468)).toBe(0)
    expect(springboardEdgeDirection(443, 100, 468)).toBe(1)
    expect(springboardEdgeDirection(117, 100, 247)).toBe(-1)
    expect(springboardEdgeDirection(200, 100, 247)).toBe(0)
    expect(springboardEdgeDirection(230, 100, 247)).toBe(1)
    expect(springboardEdgeDirection(100, 100, 100)).toBe(0)
  })

  it('resolves reachable page destinations without crossing page bounds', () => {
    expect(resolveSpringboardEdgeTurn(455, 100, 468, 1, 0, 3)).toEqual({
      destination: 2,
      direction: 1,
    })
    expect(resolveSpringboardEdgeTurn(113, 100, 468, 2, 0, 3)).toEqual({
      destination: 1,
      direction: -1,
    })
    expect(resolveSpringboardEdgeTurn(113, 100, 468, 0, 0, 3)).toBeNull()
    expect(resolveSpringboardEdgeTurn(455, 100, 468, 3, 0, 3)).toBeNull()
  })

  it('resolves consecutive edge turns while an app remains at the same edge', () => {
    const firstTurn = resolveSpringboardHomeEdgeTurn(
      113,
      100,
      468,
      4,
      4,
      5,
      false,
    )
    expect(firstTurn).toEqual({
      destination: 3,
      direction: -1,
      previewsPage: false,
    })
    expect(
      resolveSpringboardHomeEdgeTurn(
        113,
        100,
        468,
        firstTurn?.destination ?? 4,
        4,
        5,
        false,
      ),
    ).toEqual({ destination: 2, direction: -1, previewsPage: false })
  })

  it('previews one new trailing page without crossing the home-page limit', () => {
    expect(
      resolveSpringboardHomeEdgeTurn(455, 100, 468, 2, 2, 5, false),
    ).toEqual({ destination: 3, direction: 1, previewsPage: true })
    expect(
      resolveSpringboardHomeEdgeTurn(455, 100, 468, 2, 3, 5, true),
    ).toEqual({ destination: 3, direction: 1, previewsPage: false })
    expect(
      resolveSpringboardHomeEdgeTurn(455, 100, 468, 5, 5, 5, false),
    ).toBeNull()
  })

  it('keeps the original widget page mounted during a drag preview', () => {
    expect(maximumRenderedWidgetPage([1, 3], [1, 2])).toBe(3)
    expect(maximumRenderedWidgetPage([], [])).toBe(1)
  })

  it('distinguishes a page swipe from a tap or vertical gesture', () => {
    expect(springboardSwipeIntent(5, 2)).toBe('pending')
    expect(springboardSwipeIntent(30, 8)).toBe('horizontal')
    expect(springboardSwipeIntent(8, 30)).toBe('vertical')
  })

  it('keeps a dragged item under the pointer while the track changes pages', () => {
    expect(springboardPageDragCompensation(3, 2, 368)).toBe(-368)
    expect(springboardPageDragCompensation(2, 3, 368)).toBe(368)
    expect(springboardPageDragCompensation(2, 2, 368)).toBe(0)
  })

  it('selects drop slots directly in viewport order', () => {
    const slots = [
      { height: 80, left: 100, top: 150, width: 70 },
      { height: 80, left: 180, top: 150, width: 70 },
      { height: 80, left: 260, top: 150, width: 70 },
    ]

    expect(nearestSpringboardRectIndex(115, 190, slots)).toBe(0)
    expect(nearestSpringboardRectIndex(300, 190, slots)).toBe(2)
    expect(nearestSpringboardRectIndex(220, 190, slots)).toBe(1)
    expect(nearestSpringboardRectIndex(220, 190, [])).toBeNull()
  })

  it('converts viewport coordinates into local phone coordinates under zoom', () => {
    const point = springboardViewportToLocal(
      169,
      238,
      100,
      100,
      253.92,
      582.36,
      368,
      844,
    )
    expect(point.x).toBeCloseTo(100)
    expect(point.y).toBeCloseTo(200)
    expect(
      springboardViewportToLocal(200, 250, 100, 50, 0, 0, 368, 844),
    ).toEqual({ x: 100, y: 200 })
    const delta = springboardViewportDeltaToLocal(
      69,
      138,
      253.92,
      582.36,
      368,
      844,
    )
    expect(delta.x).toBeCloseTo(100)
    expect(delta.y).toBeCloseTo(200)
  })

  it.each([
    ['80% preview', 0.6624],
    ['80% production clamp', 2 / 3],
    ['100%', 0.828],
    ['120%', 0.9936],
  ])('keeps the rendered drag delta 1:1 at %s zoom', (_label, zoom) => {
    const layoutWidth = 350
    const layoutHeight = 808
    const viewportLeft = 128.25
    const viewportTop = 64.5
    const viewportWidth = layoutWidth * zoom
    const viewportHeight = layoutHeight * zoom
    const pointerStart = {
      x: viewportLeft + 48.5 * zoom,
      y: viewportTop + 132.25 * zoom,
    }
    const viewportDelta = { x: 73.25, y: -41.75 }
    const start = springboardViewportToLocal(
      pointerStart.x,
      pointerStart.y,
      viewportLeft,
      viewportTop,
      viewportWidth,
      viewportHeight,
      layoutWidth,
      layoutHeight,
    )
    const end = springboardViewportToLocal(
      pointerStart.x + viewportDelta.x,
      pointerStart.y + viewportDelta.y,
      viewportLeft,
      viewportTop,
      viewportWidth,
      viewportHeight,
      layoutWidth,
      layoutHeight,
    )
    const localDelta = springboardViewportDeltaToLocal(
      viewportDelta.x,
      viewportDelta.y,
      viewportWidth,
      viewportHeight,
      layoutWidth,
      layoutHeight,
    )

    expect((end.x - start.x) * zoom).toBeCloseTo(viewportDelta.x, 6)
    expect((end.y - start.y) * zoom).toBeCloseTo(viewportDelta.y, 6)
    expect(localDelta.x * zoom).toBeCloseTo(viewportDelta.x, 6)
    expect(localDelta.y * zoom).toBeCloseTo(viewportDelta.y, 6)
  })
})
