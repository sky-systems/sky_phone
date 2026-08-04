import { defineStore } from 'pinia'
import { ref } from 'vue'

import type {
  MailComposeDraft,
  MailCounts,
  MailDraft,
  MailFolder,
  MailListItem,
  MailListResponse,
  MailMessage,
  MailSession,
} from '@/types/mail'
import { nuiCall } from '@/utils/nui'

const emptyCounts = (): MailCounts => ({
  drafts: 0,
  inbox: 0,
  sent: 0,
  trash: 0,
  unread: 0,
})

export const useMailStore = defineStore('mail', () => {
  const accountEmail = ref('')
  const counts = ref<MailCounts>(emptyCounts())
  const folder = ref<MailFolder>('inbox')
  const hasMore = ref(false)
  const items = ref<MailListItem[]>([])
  const loading = ref(false)
  const search = ref('')

  function applySession(session: MailSession): void {
    accountEmail.value = session.email
    counts.value = session.counts
  }

  async function login(email: string, password: string) {
    const response = await nuiCall<MailSession>('mail:login', {
      email,
      password,
    })
    if (response.success && response.data) applySession(response.data)
    return response
  }

  async function register(email: string, password: string) {
    const response = await nuiCall<MailSession>('mail:register', {
      email,
      password,
    })
    if (response.success && response.data) applySession(response.data)
    return response
  }

  async function logout(): Promise<void> {
    if (accountEmail.value) await nuiCall('mail:logout')
    accountEmail.value = ''
    counts.value = emptyCounts()
    items.value = []
    hasMore.value = false
    folder.value = 'inbox'
    search.value = ''
  }

  async function loadFolder(
    nextFolder: MailFolder,
    nextSearch = '',
    append = false,
  ): Promise<boolean> {
    loading.value = true
    const offset = append ? items.value.length : 0
    const response = await nuiCall<MailListResponse>('mail:list', {
      folder: nextFolder,
      offset,
      search: nextSearch,
    })
    loading.value = false
    if (!response.success || !response.data) return false

    folder.value = nextFolder
    search.value = nextSearch
    items.value = append
      ? [...items.value, ...response.data.items]
      : response.data.items
    hasMore.value = response.data.hasMore
    return true
  }

  async function refreshCounts(): Promise<void> {
    const response = await nuiCall<MailCounts>('mail:counts')
    if (response.success && response.data) counts.value = response.data
  }

  async function openMessage(id: number): Promise<MailMessage | null> {
    const response = await nuiCall<MailMessage>('mail:get', { id })
    if (!response.success || !response.data) return null
    await refreshCounts()
    return response.data
  }

  async function openDraft(id: string): Promise<MailDraft | null> {
    const response = await nuiCall<MailDraft>('mail:get-draft', { id })
    return response.success && response.data ? response.data : null
  }

  async function saveDraft(draft: MailComposeDraft): Promise<string | null> {
    const response = await nuiCall<{ id: string }>('mail:save-draft', {
      body: draft.body,
      id: draft.id,
      recipients: draft.recipients,
      subject: draft.subject,
    })
    if (response.success && response.data) {
      await refreshCounts()
      return response.data.id
    }
    return null
  }

  async function deleteDraft(id: string): Promise<boolean> {
    const response = await nuiCall('mail:delete-draft', { id })
    if (response.success) await refreshCounts()
    return response.success
  }

  async function send(draft: MailComposeDraft) {
    const response = await nuiCall<{ id: string }>('mail:send', {
      body: draft.body,
      draftId: draft.id,
      recipients: draft.recipients,
      subject: draft.subject,
    })
    if (response.success) await refreshCounts()
    return response
  }

  async function mutateEntry(
    endpoint: string,
    id: number,
    extra: Record<string, unknown> = {},
  ): Promise<boolean> {
    const response = await nuiCall(endpoint, { id, ...extra })
    if (response.success) {
      await Promise.all([
        refreshCounts(),
        loadFolder(folder.value, search.value),
      ])
    }
    return response.success
  }

  async function emptyTrash(): Promise<boolean> {
    const response = await nuiCall('mail:empty-trash')
    if (response.success) {
      await Promise.all([refreshCounts(), loadFolder('trash', search.value)])
    }
    return response.success
  }

  return {
    accountEmail,
    counts,
    deleteDraft,
    emptyTrash,
    folder,
    hasMore,
    items,
    loadFolder,
    loading,
    login,
    logout,
    mutateEntry,
    openDraft,
    openMessage,
    refreshCounts,
    register,
    saveDraft,
    search,
    send,
    setCounts(nextCounts: MailCounts) {
      counts.value = nextCounts
    },
  }
})
