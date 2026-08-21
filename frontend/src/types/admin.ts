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

export type AdminMessageActivity = {
  body: string
  createdAt: string
  direction: 'incoming' | 'outgoing'
  id: string
  messageType: string
  otherNumber: string
  readAt: string | null
}

export type AdminCallActivity = {
  answeredAt: string | null
  direction: 'incoming' | 'outgoing'
  durationSeconds: number
  endedAt: string | null
  id: string
  otherNumber: string
  startedAt: string
  status: string
}

export type AdminActivityResponse =
  | { entries: AdminMessageActivity[]; kind: 'messages' }
  | { entries: AdminCallActivity[]; kind: 'calls' }

export type AdminConfiguratorField = {
  configured?: boolean
  label: string
  path: string
  structure?: AdminConfiguratorStructure
  scope: 'config' | 'media'
  sensitive: boolean
  type: 'boolean' | 'json' | 'number' | 'string' | 'stringOrFalse'
  value: unknown
}

export type AdminConfiguratorStructure =
  | {
      kind: 'list'
      items: AdminConfiguratorStructure[]
    }
  | {
      fields: Record<string, AdminConfiguratorStructure>
      kind: 'table'
    }
  | {
      entries: Array<{
        key: number | string
        keyType: 'number' | 'string'
        structure: AdminConfiguratorStructure
      }>
      kind: 'map'
    }
  | {
      kind: 'value'
      valueType: 'boolean' | 'number' | 'string'
    }
  | {
      kind: 'optionalString'
    }
  | {
      kind: 'vector'
      vectorType: 'vector2' | 'vector3' | 'vector4'
    }

export type AdminConfiguratorSection = {
  fields: AdminConfiguratorField[]
  id: string
  label: string
  scope: 'config' | 'media'
}

export type AdminConfigurator = {
  enabled: boolean
  revision: number
  sections: AdminConfiguratorSection[]
  updatedAt: string | null
  updatedBy: string | null
}

export type AdminConfiguratorChange = {
  path: string
  scope: 'config' | 'media'
  value: unknown
}
