import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useCompaniesStore } from '@/stores/companies'
import type {
  Company,
  CompanyDirectoryFilters,
  CompanyDirectoryPage,
  CompanyRequest,
  CompanyRequestPage,
  CompanySummary,
  CompanyWorkContext,
} from '@/types/companies'
import { nuiCall, type NuiResponse } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)

const summary: CompanySummary = {
  acceptsRequests: true,
  announcement: null,
  availability: 'available',
  availabilityUpdatedAt: '2026-08-10T10:00:00.000Z',
  canCall: true,
  canMessage: false,
  categoryId: 'public',
  categoryName: 'Public services',
  description: 'City emergency service.',
  id: 'police',
  location: {
    address: 'Mission Row',
    coords: { x: 441, y: -981, z: 30 },
    district: 'Mission Row',
    label: 'Mission Row Station',
  },
  logoUrl: null,
  name: 'Los Santos Police',
  phoneNumber: '911',
  serviceSummary: 'Emergency response',
  verified: true,
}

const company: Company = {
  ...summary,
  coverUrl: null,
  hours: [],
  revision: 3,
  services: [],
}

const workContext: CompanyWorkContext = {
  authorized: true,
  callAvailable: false,
  callDispatcher: false,
  company,
  metrics: { assigned: 0, completedToday: 0, new: 0, waiting: 0 },
  ownRequests: [],
  permissions: {
    canAssign: false,
    canManageAnnouncement: false,
    canManageHours: false,
    canManageProfile: false,
    canManageServices: false,
    canSetAvailability: false,
    canTakeCalls: true,
  },
  recentRequests: [],
  role: 'employee',
  unreadCount: 0,
}

const request: CompanyRequest = {
  actions: {
    allowedStatuses: ['in_progress'],
    canAssign: false,
    canCall: true,
    canCancel: true,
    canClaim: false,
    canReply: true,
  },
  assignedLabel: null,
  companyId: company.id,
  companyLogoUrl: null,
  companyName: company.name,
  createdAt: '2026-08-10T10:00:00.000Z',
  description: 'I need assistance.',
  events: [],
  id: 'request-1',
  media: [],
  messages: [],
  phoneNumber: '911',
  revision: 1,
  serviceId: 'response',
  serviceName: 'Emergency response',
  status: 'new',
  subject: 'Help needed',
  unreadCount: 1,
  updatedAt: '2026-08-10T10:00:00.000Z',
}

const filters: CompanyDirectoryFilters = {
  acceptsRequests: false,
  availability: null,
  categoryId: null,
  hasLocation: false,
  search: '',
  sort: 'relevance',
}

function deferred<T>(): {
  promise: Promise<T>
  resolve: (value: T) => void
} {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

describe('companies store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads, filters and deduplicates cursor pages', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: {
          categories: [{ id: 'public', name: 'Public services' }],
          companies: [summary],
          nextCursor: 'page-2',
        },
        success: true,
      })
      .mockResolvedValueOnce({
        data: {
          categories: [],
          companies: [
            { ...summary, description: 'Updated description' },
            { ...summary, id: 'medical', name: 'Los Santos Medical' },
          ],
          nextCursor: null,
        },
        success: true,
      })
    const store = useCompaniesStore()

    expect(await store.loadCompanies(filters)).toBe(true)
    expect(await store.loadCompanies(filters, true)).toBe(true)

    expect(store.directory.map((item) => item.id)).toEqual([
      'police',
      'medical',
    ])
    expect(store.directory[0].description).toBe('Updated description')
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'companies:list', {
      acceptsRequests: false,
      availability: null,
      categoryId: null,
      cursor: 'page-2',
      hasLocation: false,
      search: '',
      sort: 'relevance',
    })
  })

  it('ignores an older directory response after the filters change', async () => {
    const firstResponse = deferred<NuiResponse<CompanyDirectoryPage>>()
    const secondResponse = deferred<NuiResponse<CompanyDirectoryPage>>()
    mockNuiCall
      .mockReturnValueOnce(firstResponse.promise)
      .mockReturnValueOnce(secondResponse.promise)
    const store = useCompaniesStore()
    const searchedFilters = { ...filters, search: 'medical' }
    const medical = {
      ...summary,
      id: 'medical',
      name: 'Los Santos Medical',
    }

    const firstLoad = store.loadCompanies(filters)
    const secondLoad = store.loadCompanies(searchedFilters)
    secondResponse.resolve({
      data: { categories: [], companies: [medical], nextCursor: null },
      success: true,
    })

    await expect(secondLoad).resolves.toBe(true)
    firstResponse.resolve({
      data: { categories: [], companies: [summary], nextCursor: null },
      success: true,
    })

    await expect(firstLoad).resolves.toBe(false)
    expect(store.directory).toEqual([medical])
    expect(store.directoryFilters).toEqual(searchedFilters)
    expect(store.directoryLoading).toBe(false)
  })

  it('ignores an older customer request response after the list changes', async () => {
    const firstResponse = deferred<NuiResponse<CompanyRequestPage>>()
    const secondResponse = deferred<NuiResponse<CompanyRequestPage>>()
    mockNuiCall
      .mockReturnValueOnce(firstResponse.promise)
      .mockReturnValueOnce(secondResponse.promise)
    const store = useCompaniesStore()
    const closedRequest = { ...request, id: 'request-closed' }

    const firstLoad = store.loadMyRequests('open')
    const secondLoad = store.loadMyRequests('closed')
    secondResponse.resolve({
      data: { nextCursor: null, requests: [closedRequest], unreadCount: 1 },
      success: true,
    })

    await expect(secondLoad).resolves.toBe(true)
    firstResponse.resolve({
      data: { nextCursor: null, requests: [request], unreadCount: 7 },
      success: true,
    })

    await expect(firstLoad).resolves.toBe(false)
    expect(store.myRequests).toEqual([closedRequest])
    expect(store.myRequestsList).toBe('closed')
    expect(store.customerUnreadCount).toBe(1)
    expect(store.myRequestsLoading).toBe(false)
  })

  it('keeps directory data and its initial error when an append fails', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        error: 'temporarily_unavailable',
        success: false,
      })
      .mockResolvedValueOnce({
        data: {
          categories: [],
          companies: [
            { ...summary, id: 'medical', name: 'Los Santos Medical' },
          ],
          nextCursor: null,
        },
        success: true,
      })
    const store = useCompaniesStore()
    store.directory = [summary]
    store.directoryError = 'initial_error'
    store.directoryFilters = { ...filters }
    store.directoryNextCursor = 'page-2'

    expect(await store.loadCompanies(filters, true)).toBe(false)
    expect(store.directory).toEqual([summary])
    expect(store.directoryNextCursor).toBe('page-2')
    expect(store.directoryError).toBe('initial_error')
    expect(store.directoryAppendError).toBe('temporarily_unavailable')

    expect(await store.loadCompanies(filters, true)).toBe(true)
    expect(store.directory.map((item) => item.id)).toEqual([
      'police',
      'medical',
    ])
    expect(store.directoryError).toBe('initial_error')
    expect(store.directoryAppendError).toBe('')
  })

  it('keeps customer requests and their initial error when an append fails', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        error: 'temporarily_unavailable',
        success: false,
      })
      .mockResolvedValueOnce({
        data: {
          nextCursor: null,
          requests: [{ ...request, id: 'request-2' }],
          unreadCount: 2,
        },
        success: true,
      })
    const store = useCompaniesStore()
    store.customerUnreadCount = 1
    store.myRequests = [request]
    store.myRequestsError = 'initial_error'
    store.myRequestsList = 'open'
    store.myRequestsNextCursor = 'page-2'

    expect(await store.loadMyRequests('open', true)).toBe(false)
    expect(store.myRequests).toEqual([request])
    expect(store.myRequestsNextCursor).toBe('page-2')
    expect(store.customerUnreadCount).toBe(1)
    expect(store.myRequestsError).toBe('initial_error')
    expect(store.myRequestsAppendError).toBe('temporarily_unavailable')

    expect(await store.loadMyRequests('open', true)).toBe(true)
    expect(store.myRequests.map((item) => item.id)).toEqual([
      'request-1',
      'request-2',
    ])
    expect(store.customerUnreadCount).toBe(2)
    expect(store.myRequestsError).toBe('initial_error')
    expect(store.myRequestsAppendError).toBe('')
  })

  it('invalidates an in-flight customer page when the device scope is cleared', async () => {
    const response = deferred<NuiResponse<CompanyRequestPage>>()
    mockNuiCall.mockReturnValueOnce(response.promise)
    const store = useCompaniesStore()
    store.bindDeviceScope('device-a', 'sim-a')
    store.myRequests = [request]
    store.myRequestsList = 'open'
    store.myRequestsNextCursor = 'page-2'

    const load = store.loadMyRequests('open', true)
    store.resetDeviceScope()
    response.resolve({
      data: {
        nextCursor: null,
        requests: [{ ...request, id: 'request-stale' }],
        unreadCount: 8,
      },
      success: true,
    })

    await expect(load).resolves.toBe(false)
    expect(store.myRequests).toEqual([])
    expect(store.customerUnreadCount).toBe(0)
    expect(store.myRequestsLoaded).toBe(false)
    expect(store.myRequestsLoadingMore).toBe(false)
  })

  it('guards directory appends by loading state, cursor and exact filters', async () => {
    const store = useCompaniesStore()
    store.directoryFilters = { ...filters }
    store.directoryNextCursor = 'page-2'
    store.directoryLoading = true

    expect(await store.loadCompanies(filters, true)).toBe(false)
    store.directoryLoading = false
    expect(
      await store.loadCompanies({ ...filters, categoryId: 'public' }, true),
    ).toBe(false)
    store.directoryNextCursor = null
    expect(await store.loadCompanies(filters, true)).toBe(false)
    store.directoryNextCursor = 'page-2'
    store.directoryLoadingMore = true
    expect(await store.loadCompanies(filters, true)).toBe(false)

    expect(mockNuiCall).not.toHaveBeenCalled()
  })

  it('guards customer appends by loading state, cursor and exact list', async () => {
    const store = useCompaniesStore()
    store.myRequestsList = 'open'
    store.myRequestsNextCursor = 'page-2'
    store.myRequestsLoading = true

    expect(await store.loadMyRequests('open', true)).toBe(false)
    store.myRequestsLoading = false
    expect(await store.loadMyRequests('closed', true)).toBe(false)
    store.myRequestsNextCursor = null
    expect(await store.loadMyRequests('open', true)).toBe(false)
    store.myRequestsNextCursor = 'page-2'
    store.myRequestsLoadingMore = true
    expect(await store.loadMyRequests('open', true)).toBe(false)

    expect(mockNuiCall).not.toHaveBeenCalled()
  })

  it('uses server-provided unread counts for the app badge', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: {
        nextCursor: null,
        requests: [request],
        unreadCount: 4,
      },
      success: true,
    })
    const store = useCompaniesStore()

    await store.loadMyRequests('open')
    store.applyUnreadCounts({ work: 2 })

    expect(store.customerUnreadCount).toBe(4)
    expect(store.workUnreadCount).toBe(2)
    expect(store.unreadCount).toBe(6)
  })

  it('does not refresh directory data before the app has loaded it', async () => {
    const store = useCompaniesStore()

    await store.applyChanged({ area: 'directory', companyId: 'police' })

    expect(mockNuiCall).not.toHaveBeenCalled()

    mockNuiCall.mockResolvedValue({
      data: { categories: [], companies: [summary], nextCursor: null },
      success: true,
    })
    await store.loadCompanies(filters)
    mockNuiCall.mockClear()

    await store.applyChanged({ area: 'directory', companyId: 'police' })

    expect(mockNuiCall).toHaveBeenCalledOnce()
  })

  it('clears customer badge state when the active device has no usable SIM', async () => {
    mockNuiCall.mockResolvedValueOnce({ error: 'no_sim', success: false })
    const store = useCompaniesStore()
    store.customerUnreadCount = 4

    expect(await store.loadMyRequests('open')).toBe(false)
    expect(store.customerUnreadCount).toBe(0)
  })

  it('drops SIM-scoped request data when the active device changes', () => {
    const store = useCompaniesStore()
    store.bindDeviceScope('device-a', 'sim-a')
    store.customerUnreadCount = 3
    store.myRequests = [request]
    store.request = request

    store.bindDeviceScope('device-a', 'sim-b')

    expect(store.customerUnreadCount).toBe(0)
    expect(store.myRequests).toEqual([])
    expect(store.request).toBeNull()
  })

  it('keeps server-resolved request media in the loaded thread', async () => {
    const requestWithMedia = {
      ...request,
      media: [{ id: 12, url: 'https://example.test/request-photo.jpg' }],
    }
    mockNuiCall.mockResolvedValueOnce({
      data: { request: requestWithMedia },
      success: true,
    })
    const store = useCompaniesStore()

    expect(await store.loadRequest(request.id)).toBe(true)
    expect(store.request?.media).toEqual(requestWithMedia.media)
  })

  it('refreshes counts without replacing the selected request list', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { nextCursor: null, requests: [], unreadCount: 3 },
        success: true,
      })
      .mockResolvedValueOnce({
        data: {
          context: {
            authorized: false,
            callAvailable: false,
            callDispatcher: false,
            company: null,
            metrics: { assigned: 0, completedToday: 0, new: 0, waiting: 0 },
            ownRequests: [],
            permissions: {
              canAssign: false,
              canManageAnnouncement: false,
              canManageHours: false,
              canManageProfile: false,
              canManageServices: false,
              canSetAvailability: false,
              canTakeCalls: false,
            },
            recentRequests: [],
            role: null,
            unreadCount: 0,
          },
        },
        success: true,
      })
    const store = useCompaniesStore()
    store.myRequestsList = 'closed'

    await store.refreshUnreadCounts()

    expect(mockNuiCall).toHaveBeenCalledWith('companies:my-requests', {
      cursor: null,
      list: 'closed',
    })
  })

  it('sends only server-resolved request identifiers when claiming', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { request: { ...request, revision: 2, status: 'assigned' } },
      success: true,
    })
    const store = useCompaniesStore()

    await store.claimRequest(request.id, request.revision)

    expect(mockNuiCall).toHaveBeenCalledWith('companies:claim-request', {
      requestId: request.id,
      revision: request.revision,
    })
    expect(store.request?.status).toBe('assigned')
  })

  it('does not apply manager edits until the server confirms them', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'revision_conflict',
      success: false,
    })
    const store = useCompaniesStore()
    store.company = company

    await store.updateProfile({
      acceptsRequests: false,
      address: 'New address',
      description: 'Changed locally',
      district: 'Downtown',
      locationLabel: 'Office',
      revision: company.revision,
    })

    expect(store.company).toEqual(company)
    expect(store.mutationError).toBe('revision_conflict')
  })

  it('includes the current revision when availability changes', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { company: { ...company, availability: 'busy', revision: 4 } },
      success: true,
    })
    const store = useCompaniesStore()

    await store.updateAvailability('busy', 3)

    expect(mockNuiCall).toHaveBeenCalledWith('companies:update-availability', {
      availability: 'busy',
      revision: 3,
    })
  })

  it('creates requests without client-owned identity fields', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { request },
      success: true,
    })
    const store = useCompaniesStore()

    await store.createRequest({
      companyId: 'police',
      description: 'I need assistance.',
      mediaIds: ['10'],
      serviceId: 'response',
      subject: 'Help needed',
    })

    expect(mockNuiCall).toHaveBeenCalledWith('companies:create-request', {
      companyId: 'police',
      description: 'I need assistance.',
      mediaIds: ['10'],
      serviceId: 'response',
      subject: 'Help needed',
    })
  })

  it('uses the server dispatch role and clears it when call availability is disabled', async () => {
    const dispatcher = {
      ...workContext,
      callAvailable: true,
      callDispatcher: true,
    }
    mockNuiCall
      .mockResolvedValueOnce({ data: { context: dispatcher }, success: true })
      .mockResolvedValueOnce({ data: { context: workContext }, success: true })
    const store = useCompaniesStore()

    await store.setCallAvailability(true, true)
    expect(mockNuiCall).toHaveBeenLastCalledWith(
      'companies:set-call-availability',
      {
        available: true,
        dispatcher: true,
      },
    )
    expect(store.workContext?.callDispatcher).toBe(true)
    expect(store.workContext?.callAvailable).toBe(true)

    await store.setCallAvailability(false)
    expect(mockNuiCall).toHaveBeenLastCalledWith(
      'companies:set-call-availability',
      {
        available: false,
        dispatcher: false,
      },
    )
    expect(store.workContext?.callDispatcher).toBe(false)
    expect(store.workContext?.callAvailable).toBe(false)
    expect(store.mutating).toBe(false)
  })

  it('preserves the current role when taking dispatch duty is rejected', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'not_authorized',
      success: false,
    })
    const store = useCompaniesStore()
    store.workContext = workContext

    await store.setCallAvailability(true, true)

    expect(store.workContext?.callDispatcher).toBe(false)
    expect(store.mutationError).toBe('not_authorized')
    expect(store.mutating).toBe(false)
  })

  it('ignores a dispatch response after the active device changes', async () => {
    const pending = deferred<NuiResponse<{ context: CompanyWorkContext }>>()
    mockNuiCall.mockReturnValueOnce(pending.promise)
    const store = useCompaniesStore()
    store.bindDeviceScope('device-a', 'sim-a')
    store.workContext = workContext
    const mutation = store.setCallAvailability(true, true)
    store.bindDeviceScope('device-b', 'sim-b')
    pending.resolve({
      data: {
        context: { ...workContext, callAvailable: true, callDispatcher: true },
      },
      success: true,
    })

    expect((await mutation).success).toBe(false)
    expect(store.workContext?.callDispatcher).toBe(false)
    expect(store.mutating).toBe(false)
  })

  it('dials through the service line with only the target number and returns the server call state', async () => {
    const call = {
      direction: 'outgoing' as const,
      id: 'company-call-1',
      otherNumber: '5551110001',
      speakerEnabled: false,
      speakerSupported: true,
      startedAt: 1_776_000_000,
      state: 'ringing' as const,
    }
    mockNuiCall.mockResolvedValueOnce({ data: call, success: true })
    const store = useCompaniesStore()

    const response = await store.dialServiceLine(call.otherNumber)

    expect(mockNuiCall).toHaveBeenCalledOnce()
    expect(mockNuiCall).toHaveBeenCalledWith('companies:dial-service-line', {
      phoneNumber: call.otherNumber,
    })
    expect(response).toEqual({ data: call, success: true })
    expect(store.mutating).toBe(false)
    expect(store.mutationError).toBe('')
  })
})
