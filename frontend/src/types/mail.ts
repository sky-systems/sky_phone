export type MailFolder = 'inbox' | 'sent' | 'drafts' | 'trash'

export type MailCounts = {
  drafts: number
  inbox: number
  sent: number
  trash: number
  unread: number
}

export type MailListItem = {
  body?: string
  created_at: string
  folder?: 'inbox' | 'sent'
  id: number | string
  is_read?: boolean
  message_id?: string
  preview: string
  recipients: string[]
  sender?: string
  subject: string
  trashed_at?: string | null
  updated_at?: string
}

export type MailMessage = MailListItem & {
  body: string
  folder: 'inbox' | 'sent'
  id: number
  message_id: string
  sender: string
}

export type MailDraft = {
  body: string
  created_at: string
  id: string
  recipients: string[]
  subject: string
  updated_at: string
}

export type MailSession = {
  counts: MailCounts
  email: string
}

export type MailListResponse = {
  hasMore: boolean
  items: MailListItem[]
  offset: number
}

export type MailComposeDraft = {
  body: string
  id?: string
  recipients: string[]
  subject: string
}
