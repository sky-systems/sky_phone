export type AdminStats = {
  accounts: number
  devices: number
  online: number
}

export type AdminPlayerSummary = {
  deviceCount: number
  grade: number
  identifier: string
  job: string
  name: string
  onDuty: boolean
  phoneNumber: string | null
  serverName: string
  source: number
}

export type AdminDevice = {
  account: {
    email: string
    id: number
    passwordAvailable: boolean
  } | null
  apps: {
    claimed: string[]
    revision: number
    uninstalled: string[]
  }
  createdAt: string
  imei: string
  name: string
  number: string | null
  security: {
    enabled: boolean
    failedAttempts: number
    length: number | null
    lockedUntil: number
  }
  simRegistered: boolean
  simType: string | null
  updatedAt: string
}

export type AdminPlayerDetail = {
  birthdate: string
  devices: AdminDevice[]
  firstName: string
  identifier: string
  job: {
    grade: number
    gradeLabel: string
    label: string
    name: string
    onDuty: boolean
  }
  lastName: string
  money: {
    bank: number
    cash: number
    currency: string
  }
  name: string
  serverName: string
  source: number
}

export type AdminAuditEntry = {
  action: string
  actorName: string
  createdAt: string
  details: Record<string, unknown>
  deviceImei: string | null
  id: number
  targetIdentifier: string
  targetSource: number | null
}

export type AdminBootstrap = {
  audit: AdminAuditEntry[]
  players: AdminPlayerSummary[]
  stats: AdminStats
}

export type AdminCredential = {
  email: string
  password: string
}
