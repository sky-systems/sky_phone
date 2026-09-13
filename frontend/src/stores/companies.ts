import { defineStore } from 'pinia'

import type {
  Company,
  CompanyAvailability,
  CompanyChangedPayload,
  CompanyDirectoryFilters,
  CompanyDirectoryPage,
  CompanyHours,
  CompanyMember,
  CompanyMembersResult,
  CompanyMutationResult,
  CompanyRequest,
  CompanyRequestList,
  CompanyRequestMutationResult,
  CompanyRequestPage,
  CompanyRequestStatus,
  CompanyRequestSummary,
  CompanyService,
  CompanySummary,
  CompanyUnreadCounts,
  CompanyWorkContext,
  CompanyWorkFilter,
  CompanyWorkQueuePage,
  CreateCompanyRequest,
  PublishCompanyAnnouncement,
  UpdateCompanyProfile,
} from '@/types/companies'
import type { PhoneCall } from '@/types/phone'
import { nuiCall, type NuiResponse } from '@/utils/nui'

function mergeById<T extends { id: string }>(current: T[], incoming: T[]): T[] {
  const merged = new Map(current.map((item) => [item.id, item]))
  for (const item of incoming) merged.set(item.id, item)
  return [...merged.values()]
}

function sameDirectoryFilters(
  current: CompanyDirectoryFilters,
  requested: CompanyDirectoryFilters,
): boolean {
  return (
    current.acceptsRequests === requested.acceptsRequests &&
    current.availability === requested.availability &&
    current.categoryId === requested.categoryId &&
    current.hasLocation === requested.hasLocation &&
    current.search === requested.search &&
    current.sort === requested.sort
  )
}

export const useCompaniesStore = defineStore('companies', {
  state: () => ({
    categories: [] as CompanyDirectoryPage['categories'],
    company: null as Company | null,
    customerUnreadCount: 0,
    directory: [] as CompanySummary[],
    directoryFilters: {
      acceptsRequests: false,
      availability: null,
      categoryId: null,
      hasLocation: false,
      search: '',
      sort: 'relevance',
    } as CompanyDirectoryFilters,
    directoryAppendError: '',
    directoryError: '',
    directoryLoaded: false,
    directoryLoading: false,
    directoryLoadingMore: false,
    directoryNextCursor: null as string | null,
    directoryRequestGeneration: 0,
    deviceScopeKey: '',
    deviceScopeVersion: 0,
    members: [] as CompanyMember[],
    membersLoading: false,
    mutationError: '',
    mutating: false,
    myRequests: [] as CompanyRequestSummary[],
    myRequestsAppendError: '',
    myRequestsList: 'open' as CompanyRequestList,
    myRequestsError: '',
    myRequestsLoaded: false,
    myRequestsLoading: false,
    myRequestsLoadingMore: false,
    myRequestsNextCursor: null as string | null,
    myRequestsRequestGeneration: 0,
    request: null as CompanyRequest | null,
    requestError: '',
    requestLoading: false,
    workContext: null as CompanyWorkContext | null,
    workContextError: '',
    workContextLoaded: false,
    workContextLoading: false,
    workQueue: [] as CompanyRequestSummary[],
    workQueueFilter: 'new' as CompanyWorkFilter,
    workQueueError: '',
    workQueueLoading: false,
    workQueueLoadingMore: false,
    workQueueNextCursor: null as string | null,
    workUnreadCount: 0,
  }),
  getters: {
    unreadCount: (state): number =>
      state.customerUnreadCount + state.workUnreadCount,
  },
  actions: {
    bindDeviceScope(imei: string, simId: string | null): void {
      const key = `${imei}:${simId ?? 'no-sim'}`
      if (!this.deviceScopeKey) {
        this.deviceScopeKey = key
        return
      }
      if (this.deviceScopeKey === key) return
      this.deviceScopeKey = key
      this.resetDeviceScope()
    },
    applyUnreadCounts(counts: CompanyUnreadCounts): void {
      if (typeof counts.customer === 'number') {
        this.customerUnreadCount = Math.max(0, Math.floor(counts.customer))
      }
      if (typeof counts.work === 'number') {
        this.workUnreadCount = Math.max(0, Math.floor(counts.work))
      }
    },
    async refreshUnreadCounts(): Promise<void> {
      await Promise.all([
        this.loadMyRequests(this.myRequestsList),
        this.loadWorkContext(),
      ])
    },
    async applyChanged(change: CompanyChangedPayload): Promise<void> {
      const refreshDirectory =
        this.directoryLoaded &&
        (change.area === 'all' || change.area === 'directory')
      const refreshCustomer =
        this.myRequestsLoaded &&
        (change.area === 'all' || change.area === 'customer')
      const refreshWork =
        this.workContextLoaded &&
        (change.area === 'all' || change.area === 'work')
      const tasks: Promise<unknown>[] = []
      if (refreshDirectory) {
        tasks.push(this.loadCompanies(this.directoryFilters))
        if (change.companyId && this.company?.id === change.companyId) {
          tasks.push(this.loadCompany(change.companyId))
        }
      }
      if (refreshCustomer) tasks.push(this.loadMyRequests(this.myRequestsList))
      if (refreshWork) {
        tasks.push(
          this.loadWorkContext().then((loaded) =>
            loaded && this.workContext?.authorized
              ? this.loadWorkQueue(this.workQueueFilter)
              : false,
          ),
        )
      }
      if (
        change.requestId &&
        this.request?.id === change.requestId &&
        (refreshCustomer || refreshWork)
      ) {
        tasks.push(this.loadRequest(change.requestId))
      }
      await Promise.all(tasks)
    },
    async loadCompanies(
      filters: CompanyDirectoryFilters,
      append = false,
    ): Promise<boolean> {
      const requestFilters = { ...filters }
      if (
        append &&
        (this.directoryLoading ||
          this.directoryLoadingMore ||
          !this.directoryNextCursor ||
          !sameDirectoryFilters(this.directoryFilters, requestFilters))
      ) {
        return false
      }
      if (append) {
        this.directoryLoadingMore = true
      } else {
        this.directoryRequestGeneration += 1
        this.directoryLoading = true
        this.directoryLoadingMore = false
        this.directoryAppendError = ''
        this.directoryError = ''
        this.directoryFilters = requestFilters
      }
      this.directoryLoaded = true
      const requestGeneration = this.directoryRequestGeneration
      const requestCursor = append ? this.directoryNextCursor : null
      const response = await nuiCall<CompanyDirectoryPage>('companies:list', {
        acceptsRequests: requestFilters.acceptsRequests,
        availability: requestFilters.availability,
        categoryId: requestFilters.categoryId,
        cursor: requestCursor,
        hasLocation: requestFilters.hasLocation,
        search: requestFilters.search,
        sort: requestFilters.sort,
      })
      const isCurrentRequest =
        requestGeneration === this.directoryRequestGeneration &&
        sameDirectoryFilters(this.directoryFilters, requestFilters)
      if (!isCurrentRequest) {
        if (requestGeneration === this.directoryRequestGeneration) {
          if (append) this.directoryLoadingMore = false
          else this.directoryLoading = false
        }
        return false
      }
      if (append) this.directoryLoadingMore = false
      else this.directoryLoading = false
      if (!response.success || !response.data) {
        if (append) {
          this.directoryAppendError = response.error ?? 'request_failed'
          return false
        }
        this.directoryError = response.error ?? 'request_failed'
        this.directory = []
        this.directoryNextCursor = null
        return false
      }
      this.categories = response.data.categories ?? this.categories
      this.directory = append
        ? mergeById(this.directory, response.data.companies)
        : response.data.companies
      this.directoryNextCursor = response.data.nextCursor
      if (append) this.directoryAppendError = ''
      else this.directoryError = ''
      return true
    },
    async loadCompany(companyId: string): Promise<boolean> {
      this.directoryError = ''
      this.directoryLoading = true
      const response = await nuiCall<{ company: Company }>('companies:get', {
        companyId,
      })
      this.directoryLoading = false
      if (!response.success || !response.data?.company) {
        this.directoryError = response.error ?? 'request_failed'
        return false
      }
      this.company = response.data.company
      this.replaceCompanySummary(response.data.company)
      return true
    },
    async loadMyRequests(
      list: CompanyRequestList,
      append = false,
    ): Promise<boolean> {
      if (
        append &&
        (this.myRequestsLoading ||
          this.myRequestsLoadingMore ||
          !this.myRequestsNextCursor ||
          list !== this.myRequestsList)
      ) {
        return false
      }
      if (append) {
        this.myRequestsLoadingMore = true
      } else {
        this.myRequestsRequestGeneration += 1
        this.myRequestsLoading = true
        this.myRequestsLoadingMore = false
        this.myRequestsAppendError = ''
        this.myRequestsError = ''
        this.myRequestsList = list
      }
      this.myRequestsLoaded = true
      const deviceScopeVersion = this.deviceScopeVersion
      const requestGeneration = this.myRequestsRequestGeneration
      const requestCursor = append ? this.myRequestsNextCursor : null
      const response = await nuiCall<CompanyRequestPage>(
        'companies:my-requests',
        {
          cursor: requestCursor,
          list,
        },
      )
      const isCurrentRequest =
        deviceScopeVersion === this.deviceScopeVersion &&
        requestGeneration === this.myRequestsRequestGeneration &&
        list === this.myRequestsList
      if (!isCurrentRequest) {
        if (
          deviceScopeVersion === this.deviceScopeVersion &&
          requestGeneration === this.myRequestsRequestGeneration
        ) {
          if (append) this.myRequestsLoadingMore = false
          else this.myRequestsLoading = false
        }
        return false
      }
      if (append) this.myRequestsLoadingMore = false
      else this.myRequestsLoading = false
      if (!response.success || !response.data) {
        if (append) {
          this.myRequestsAppendError = response.error ?? 'request_failed'
          return false
        }
        this.myRequestsError = response.error ?? 'request_failed'
        this.myRequests = []
        this.myRequestsNextCursor = null
        if (
          response.error === 'anonymous_sim' ||
          response.error === 'device_not_found' ||
          response.error === 'no_sim'
        ) {
          this.customerUnreadCount = 0
        }
        return false
      }
      this.myRequests = append
        ? mergeById(this.myRequests, response.data.requests)
        : response.data.requests
      this.myRequestsNextCursor = response.data.nextCursor
      this.customerUnreadCount = Math.max(0, response.data.unreadCount)
      if (append) this.myRequestsAppendError = ''
      else this.myRequestsError = ''
      return true
    },
    async loadRequest(requestId: string): Promise<boolean> {
      this.requestLoading = true
      const deviceScopeVersion = this.deviceScopeVersion
      const response = await nuiCall<{ request: CompanyRequest }>(
        'companies:get-request',
        { requestId },
      )
      this.requestLoading = false
      if (deviceScopeVersion !== this.deviceScopeVersion) return false
      if (!response.success || !response.data?.request) {
        this.requestError = response.error ?? 'request_failed'
        return false
      }
      this.request = response.data.request
      this.requestError = ''
      this.replaceRequestSummary(response.data.request)
      return true
    },
    async loadWorkContext(): Promise<boolean> {
      this.workContextLoaded = true
      this.workContextLoading = true
      const response = await nuiCall<{ context: CompanyWorkContext }>(
        'companies:work-context',
      )
      this.workContextLoading = false
      if (!response.success || !response.data?.context) {
        this.workContextError = response.error ?? 'request_failed'
        return false
      }
      this.workContext = response.data.context
      this.workUnreadCount = Math.max(0, response.data.context.unreadCount)
      this.workContextError = ''
      return true
    },
    async loadWorkQueue(
      filter: CompanyWorkFilter,
      append = false,
    ): Promise<boolean> {
      if (append && (!this.workQueueNextCursor || this.workQueueLoadingMore)) {
        return false
      }
      if (append) this.workQueueLoadingMore = true
      else this.workQueueLoading = true
      this.workQueueFilter = filter
      const response = await nuiCall<CompanyWorkQueuePage>(
        'companies:work-queue',
        {
          cursor: append ? this.workQueueNextCursor : null,
          filter,
        },
      )
      this.workQueueLoading = false
      this.workQueueLoadingMore = false
      if (!response.success || !response.data) {
        this.workQueueError = response.error ?? 'request_failed'
        if (!append) {
          this.workQueue = []
          this.workQueueNextCursor = null
        }
        return false
      }
      this.workQueue = append
        ? mergeById(this.workQueue, response.data.requests)
        : response.data.requests
      this.workQueueNextCursor = response.data.nextCursor
      this.workQueueError = ''
      return true
    },
    async loadMembers(): Promise<boolean> {
      this.membersLoading = true
      const response = await nuiCall<CompanyMembersResult>(
        'companies:list-members',
      )
      this.membersLoading = false
      if (!response.success || !response.data) {
        this.mutationError = response.error ?? 'request_failed'
        return false
      }
      this.members = response.data.members
      this.mutationError = ''
      return true
    },
    async createRequest(
      draft: CreateCompanyRequest,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:create-request', draft)
    },
    async cancelRequest(
      requestId: string,
      revision: number,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:cancel-request', {
        requestId,
        revision,
      })
    },
    async sendMessage(
      requestId: string,
      body: string,
      revision: number,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:send-message', {
        body,
        requestId,
        revision,
      })
    },
    async claimRequest(
      requestId: string,
      revision: number,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:claim-request', {
        requestId,
        revision,
      })
    },
    async assignRequest(
      requestId: string,
      memberId: string,
      revision: number,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:assign-request', {
        memberId,
        requestId,
        revision,
      })
    },
    async updateRequestStatus(
      requestId: string,
      status: CompanyRequestStatus,
      revision: number,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      return this.mutateRequest('companies:update-request-status', {
        requestId,
        revision,
        status,
      })
    },
    async updateAvailability(
      availability: CompanyAvailability,
      revision: number,
    ): Promise<NuiResponse<CompanyMutationResult>> {
      return this.mutateCompany('companies:update-availability', {
        availability,
        revision,
      })
    },
    async updateProfile(
      profile: UpdateCompanyProfile,
    ): Promise<NuiResponse<CompanyMutationResult>> {
      return this.mutateCompany('companies:update-profile', profile)
    },
    async updateHours(
      revision: number,
      hours: CompanyHours[],
    ): Promise<NuiResponse<CompanyMutationResult>> {
      return this.mutateCompany('companies:update-hours', { hours, revision })
    },
    async updateServices(
      revision: number,
      services: CompanyService[],
    ): Promise<NuiResponse<CompanyMutationResult>> {
      return this.mutateCompany('companies:update-services', {
        revision,
        services,
      })
    },
    async publishAnnouncement(
      announcement: PublishCompanyAnnouncement,
    ): Promise<NuiResponse<CompanyMutationResult>> {
      return this.mutateCompany('companies:publish-announcement', announcement)
    },
    async setCallAvailability(
      available: boolean,
      dispatcher = false,
    ): Promise<NuiResponse<{ context: CompanyWorkContext }>> {
      this.mutating = true
      const deviceScopeVersion = this.deviceScopeVersion
      const response = await nuiCall<{ context: CompanyWorkContext }>(
        'companies:set-call-availability',
        { available, dispatcher },
      )
      this.mutating = false
      if (deviceScopeVersion !== this.deviceScopeVersion) {
        return { error: 'request_failed', success: false }
      }
      if (!response.success || !response.data?.context) {
        this.mutationError = response.error ?? 'request_failed'
        return response
      }
      this.workContext = response.data.context
      this.workUnreadCount = Math.max(0, response.data.context.unreadCount)
      this.mutationError = ''
      return response
    },
    async callCustomer(requestId: string): Promise<NuiResponse<PhoneCall>> {
      this.mutating = true
      const response = await nuiCall<PhoneCall>('companies:call-customer', {
        requestId,
      })
      this.mutating = false
      this.mutationError = response.success
        ? ''
        : (response.error ?? 'request_failed')
      return response
    },
    async dialServiceLine(
      phoneNumber: string,
    ): Promise<NuiResponse<PhoneCall>> {
      this.mutating = true
      const response = await nuiCall<PhoneCall>('companies:dial-service-line', {
        phoneNumber,
      })
      this.mutating = false
      this.mutationError = response.success
        ? ''
        : (response.error ?? 'request_failed')
      return response
    },
    async mutateRequest(
      endpoint: string,
      payload: Record<string, unknown>,
    ): Promise<NuiResponse<CompanyRequestMutationResult>> {
      this.mutating = true
      const deviceScopeVersion = this.deviceScopeVersion
      const response = await nuiCall<CompanyRequestMutationResult>(
        endpoint,
        payload,
      )
      this.mutating = false
      if (deviceScopeVersion !== this.deviceScopeVersion) {
        return { success: false, error: 'device_changed' }
      }
      if (!response.success || !response.data?.request) {
        this.mutationError = response.error ?? 'request_failed'
        return response
      }
      this.request = response.data.request
      this.replaceRequestSummary(response.data.request)
      if (response.data.context) {
        this.workContext = response.data.context
        this.workUnreadCount = Math.max(0, response.data.context.unreadCount)
      }
      this.mutationError = ''
      return response
    },
    async mutateCompany(
      endpoint: string,
      payload: Record<string, unknown>,
    ): Promise<NuiResponse<CompanyMutationResult>> {
      this.mutating = true
      const response = await nuiCall<CompanyMutationResult>(endpoint, payload)
      this.mutating = false
      if (!response.success || !response.data?.company) {
        this.mutationError = response.error ?? 'request_failed'
        return response
      }
      this.company = response.data.company
      this.replaceCompanySummary(response.data.company)
      if (this.workContext) this.workContext.company = response.data.company
      if (response.data.context) {
        this.workContext = response.data.context
        this.workUnreadCount = Math.max(0, response.data.context.unreadCount)
      }
      this.mutationError = ''
      return response
    },
    replaceCompanySummary(company: Company): void {
      const index = this.directory.findIndex((item) => item.id === company.id)
      if (index >= 0) this.directory[index] = company
    },
    replaceRequestSummary(request: CompanyRequest): void {
      const lists = [this.myRequests, this.workQueue]
      for (const list of lists) {
        const index = list.findIndex((item) => item.id === request.id)
        if (index >= 0) list[index] = request
      }
      if (this.workContext) {
        const contextLists = [
          this.workContext.ownRequests,
          this.workContext.recentRequests,
        ]
        for (const list of contextLists) {
          const index = list.findIndex((item) => item.id === request.id)
          if (index >= 0) list[index] = request
        }
      }
    },
    resetRequest(): void {
      this.request = null
      this.requestError = ''
    },
    resetDeviceScope(): void {
      this.deviceScopeVersion += 1
      this.myRequestsRequestGeneration += 1
      this.customerUnreadCount = 0
      this.myRequests = []
      this.myRequestsAppendError = ''
      this.myRequestsError = ''
      this.myRequestsLoaded = false
      this.myRequestsLoading = false
      this.myRequestsLoadingMore = false
      this.myRequestsNextCursor = null
      this.request = null
      this.requestError = ''
      this.requestLoading = false
    },
  },
})
