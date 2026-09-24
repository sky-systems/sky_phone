export type CryptoSide = 'buy' | 'sell'

export type CryptoMarket = {
  changePercent: number
  color: string
  enabled: boolean
  high24h: string
  id: string
  issuedSupply: string
  logo: string
  low24h: string
  name: string
  price: string
  priceHistory?: string[]
  sparkline: number[]
  symbol: string
  treasuryAvailable: string
  updatedAt?: number
  version?: number
}

export type CryptoMarketUpdate = Pick<CryptoMarket, 'id' | 'price'> &
  Partial<CryptoMarket>

export type CryptoMarketChangedData = {
  markets: CryptoMarketUpdate[]
  updatedAt: number
}

export type CryptoHolding = {
  assetId: string
  averagePrice: string
  quantity: string
  value: string
}

export type CryptoActivity = {
  amount: string
  counterpartyKey?: string
  createdAt: number
  id: string
  marketId?: string
  quantity?: string
  status: string
  type:
    | 'buy'
    | 'sell'
    | 'deposit'
    | 'withdrawal'
    | 'transfer_in'
    | 'transfer_out'
}

export type CryptoProfile = {
  createdAt: number
  handle: string
  hideBalances: boolean
  id: string
  priceAlerts: boolean
  status: 'active' | 'frozen' | 'closed'
  totalTrades: number
  totalVolume: string
  tradeConfirmations: boolean
  walletKey: string
}

export type CryptoBootstrap = {
  activity: CryptoActivity[]
  authenticated: boolean
  cashBalance: string
  holdings: CryptoHolding[]
  markets: CryptoMarket[]
  portfolioValue: string
  profile: CryptoProfile | null
  registered?: boolean
}

export type CryptoRecipient = {
  handle: string
  walletKey: string
}

export type CryptoQuote = {
  expiresAt: number
  fee: string
  gross: string
  id: string
  marketId: string
  net: string
  price: string
  quantity: string
  side: CryptoSide
}
