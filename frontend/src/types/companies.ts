export type CompanyAvailability = 'available' | 'busy' | 'closed'

export type CompanyDirectorySort = 'name' | 'relevance' | 'updated'

export type CompanyRequestList = 'closed' | 'open'

export type CompanyRequestStatus =
  | 'assigned'
  | 'cancelled'
  | 'completed'
  | 'in_progress'
  | 'new'
  | 'waiting_customer'

export type CompanyWorkFilter =
  | 'assigned'
  | 'completed'
  | 'in_progress'
  | 'new'
  | 'waiting_customer'

export type CompanyRequestEventType =
  | 'assigned'
  | 'cancelled'
  | 'completed'
  | 'created'
  | 'status_changed'

export type CompanyCategory = {
  id: string
  name: string
}

export type CompanyCoordinates = {
  x: number
  y: number
  z: number
}

export type CompanyLocation = {
  address: string
  coords: CompanyCoordinates
  district: string
  label: string
}

export type CompanyAnnouncement = {
  body: string
  expiresAt: string | null
  publishedAt: string
}

export type CompanyService = {
  acceptsRequests: boolean
  active: boolean
  description: string
  id: string
  priceText: string | null
  title: string
}

export type CompanyHours = {
  closesAt: string | null
  day: number
  isClosed: boolean
  opensAt: string | null
}

export type CompanySummary = {
  acceptsRequests: boolean
  announcement: CompanyAnnouncement | null
  availability: CompanyAvailability
  availabilityUpdatedAt: string
  canCall: boolean
  canMessage: boolean
  categoryId: string
  categoryName: string
  description: string
  id: string
  location: CompanyLocation | null
  logoUrl: string | null
  name: string
  phoneNumber: string | null
  serviceSummary: string
  verified: boolean
}

export type Company = CompanySummary & {
  coverUrl: string | null
  hours: CompanyHours[]
  revision: number
  services: CompanyService[]
}

export type CompanyDirectoryFilters = {
  acceptsRequests: boolean
  availability: CompanyAvailability | null
  categoryId: string | null
  hasLocation: boolean
  search: string
  sort: CompanyDirectorySort
}

export type CompanyDirectoryPage = {
  categories: CompanyCategory[]
  companies: CompanySummary[]
  nextCursor: string | null
}

export type CompanyRequestActions = {
  allowedStatuses: CompanyRequestStatus[]
  canAssign: boolean
  canCall: boolean
  canCancel: boolean
  canClaim: boolean
  canReply: boolean
}

export type CompanyRequestSummary = {
  assignedLabel: 'assigned' | 'you' | null
  companyId: string
  companyLogoUrl: string | null
  companyName: string
  createdAt: string
  id: string
  serviceId: string | null
  serviceName: string | null
  status: CompanyRequestStatus
  subject: string
  unreadCount: number
  updatedAt: string
}

export type CompanyRequestMessage = {
  author: 'company' | 'customer'
  authorLabel: 'company' | 'customer' | 'you'
  body: string
  createdAt: string
  id: string
  isMine: boolean
}

export type CompanyRequestMedia = {
  id: number
  url: string
}

export type CompanyRequestEvent = {
  createdAt: string
  id: string
  status: CompanyRequestStatus | null
  type: CompanyRequestEventType
}

export type CompanyRequest = CompanyRequestSummary & {
  actions: CompanyRequestActions
  description: string
  events: CompanyRequestEvent[]
  media: CompanyRequestMedia[]
  messages: CompanyRequestMessage[]
  phoneNumber: string | null
  revision: number
}

export type CompanyRequestPage = {
  nextCursor: string | null
  requests: CompanyRequestSummary[]
  unreadCount: number
}

export type CompanyWorkMetrics = {
  assigned: number
  completedToday: number
  new: number
  waiting: number
}

export type CompanyWorkPermissions = {
  canAssign: boolean
  canManageAnnouncement: boolean
  canManageHours: boolean
  canManageProfile: boolean
  canManageServices: boolean
  canSetAvailability: boolean
  canTakeCalls: boolean
}

export type CompanyWorkContext = {
  authorized: boolean
  callAvailable: boolean
  company: Company | null
  metrics: CompanyWorkMetrics
  ownRequests: CompanyRequestSummary[]
  permissions: CompanyWorkPermissions
  recentRequests: CompanyRequestSummary[]
  role: 'employee' | 'manager' | null
  unreadCount: number
}

export type CompanyWorkQueuePage = {
  nextCursor: string | null
  requests: CompanyRequestSummary[]
}

export type CompanyMember = {
  id: string
  name: string
  online: boolean
  role: string
}

export type CompanyMembersResult = {
  members: CompanyMember[]
}

export type CreateCompanyRequest = {
  companyId: string
  description: string
  mediaIds: string[]
  serviceId: string
  subject: string
}

export type CompanyRequestMutationResult = {
  context?: CompanyWorkContext
  request: CompanyRequest
}

export type CompanyMutationResult = {
  company: Company
  context?: CompanyWorkContext
}

export type UpdateCompanyProfile = {
  acceptsRequests: boolean
  address: string
  coords?: CompanyCoordinates
  description: string
  district: string
  logoMediaId?: number
  locationLabel: string
  revision: number
}

export type UpdateCompanyHours = {
  hours: CompanyHours[]
  revision: number
}

export type UpdateCompanyServices = {
  revision: number
  services: CompanyService[]
}

export type PublishCompanyAnnouncement = {
  body: string
  expiresAt: string | null
  revision: number
}

export type CompanyUnreadCounts = {
  customer?: number
  work?: number
}

export type CompanyChangedPayload = {
  area: 'all' | 'customer' | 'directory' | 'work'
  companyId?: string
  requestId?: string
}
