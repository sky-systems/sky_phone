import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useBillingStore } from '@/stores/billing'
import type { BillingOverview, InvoiceDetail } from '@/types/billing'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)

const overview: BillingOverview = {
  currency: '$',
  openCount: 2,
  openTotal: 2299,
  overdueCount: 1,
  supportsDisputes: true,
  supportsSent: true,
  unreadCount: 2,
  urgentInvoices: [],
}

const detail: InvoiceDetail = {
  amount: 1300,
  canDispute: true,
  canPay: true,
  currency: '$',
  description: 'Treatment',
  direction: 'inbox',
  dueAt: 1_800_000,
  id: 'invoice-id',
  isOverdue: false,
  isUnread: false,
  issuedAt: 1_000_000,
  issuerAccount: 'ambulance',
  issuerLabel: 'Los Santos Medical',
  paidAt: null,
  paymentReference: '',
  status: 'open',
  title: 'Treatment',
}

describe('billing store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads the billing overview', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: overview, success: true })
    const billing = useBillingStore()

    expect(await billing.loadOverview()).toBe(true)
    expect(billing.overview).toEqual(overview)
    expect(mockNuiCall).toHaveBeenCalledWith('billing:overview', {
      direction: 'inbox',
    })
  })

  it('loads and appends paged invoices', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { hasMore: true, invoices: [detail], nextOffset: 1 },
        success: true,
      })
      .mockResolvedValueOnce({
        data: {
          hasMore: false,
          invoices: [{ ...detail, id: 'second' }],
          nextOffset: 2,
        },
        success: true,
      })
    const billing = useBillingStore()

    await billing.loadInvoices('inbox', 'open')
    await billing.loadInvoices('inbox', 'open', '', true)

    expect(billing.invoices.map((invoice) => invoice.id)).toEqual([
      'invoice-id',
      'second',
    ])
  })

  it('does not invent a payment snapshot without a loaded invoice', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { ...detail, status: 'paid' },
        success: true,
      })
      .mockResolvedValueOnce({ data: overview, success: true })
    const billing = useBillingStore()

    await billing.pay(detail.id)

    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'billing:pay', {
      id: detail.id,
    })
  })
  it('binds provider payment to the amount the player reviewed', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { ...detail, status: 'paid' },
        success: true,
      })
      .mockResolvedValueOnce({ data: overview, success: true })
    const billing = useBillingStore()
    billing.detail = {
      ...detail,
      id: 'fixture-provider:17',
      amount: 400,
      amountPaid: 100,
    }

    await billing.pay(billing.detail.id)

    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'billing:pay', {
      id: 'fixture-provider:17',
      amount: 400,
      amountPaid: 100,
    })
  })
})
