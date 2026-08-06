export type BankingTransactionKind =
  | 'deposit'
  | 'withdrawal'
  | 'transfer_in'
  | 'transfer_out'

export type BankingTransaction = {
  amount: number
  createdAt: number
  id: number
  kind: BankingTransactionKind
  label: string
  reference: string
}

export type BankingOverview = {
  bank: number
  cash: number
  currency: string
  playerId: number
  playerName: string
  transactions: BankingTransaction[]
}

export type BankingAction = 'deposit' | 'withdraw' | 'transfer'
