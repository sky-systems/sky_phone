export type TowerStatus = 'over' | 'paused' | 'playing'

export type TowerBlock = {
  colorIndex: number
  id: number
  level: number
  width: number
  x: number
}

export type TowerActiveBlock = TowerBlock & {
  direction: -1 | 1
  speed: number
}

export type TowerGameState = {
  active: TowerActiveBlock | null
  blocks: TowerBlock[]
  perfects: number
  score: number
  status: TowerStatus
}

export type TowerPlacement = {
  cutSide: 'left' | 'right' | null
  cutWidth: number
  outcome: 'missed' | 'perfect' | 'placed'
  state: TowerGameState
}
