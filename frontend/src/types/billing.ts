export type BillingDirection = 'inbox' | 'sent'

export type BillingStatus =
  | 'open'
  | 'partially_paid'
  | 'expired'
  | 'processing'
  | 'paid'
  | 'disputed'
  | 'cancelled'
  | 'refunded'

export type BillingFilter = 'all' | 'open' | 'overdue' | 'paid'

export type InvoiceSummary = {
  amount: number
  currency: string
  description: string
  direction: BillingDirection
  dueAt: number | null
  id: string
  isOverdue: boolean
  isUnread: boolean
  issuedAt: number
  issuerLabel: string
  paymentReference: string
  status: BillingStatus
  title: string
}

export type InvoiceDetail = InvoiceSummary & {
  amountPaid?: number
  canDispute: boolean
  canPay: boolean
  issuerAccount: string
  paidAt: number | null
}

export type BillingOverview = {
  currency: string
  openCount: number
  openTotal: number
  overdueCount: number
  supportsDisputes: boolean
  supportsSent: boolean
  unreadCount: number
  urgentInvoices: InvoiceSummary[]
}

export type BillingListResult = {
  hasMore: boolean
  invoices: InvoiceSummary[]
  nextOffset: number
}
