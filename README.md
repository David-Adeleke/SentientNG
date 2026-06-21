# SentientNG

> Real-time Fear & Greed Index for the Nigerian Stock Exchange (NGX)

SentientNG is a market sentiment tool that publishes a daily Fear & Greed score for the Nigerian Exchange at three levels — the whole market, individual sectors, and individual NGX 30 stocks. It is a spiritual successor to PulseNG, going one layer deeper from price data into market psychology.

---

## What It Does

Every weekday after market close, SentientNG:

1. Fetches raw market data from multiple sources
2. Computes a Fear & Greed score (0 – 100) for the overall NGX market, each active sector, and each of the 30 NGX 30 constituent stocks
3. Stores the results in a Supabase database
4. Serves them to a Vue 3 frontend where users can explore market sentiment at each level

**Score labels:**

| Score | Label |
|---|---|
| 0 – 20 | Extreme Fear |
| 21 – 40 | Fear |
| 41 – 60 | Neutral |
| 61 – 80 | Greed |
| 81 – 100 | Extreme Greed |

---

## Methodology

Based on CNN's Fear & Greed Index, adapted for the Nigerian market. All signals at each level are **equally weighted**. Each signal is normalized using **z-score normalization** — every reading is evaluated relative to its own 252-day (one trading year) history, so scores are always calibrated to recent NGX behaviour rather than fixed global thresholds.

### Market Level — 7 Signals

| # | Signal | Measures | Source |
|---|---|---|---|
| 1 | Market Momentum | ASI vs its 125-day moving average | NGX Pulse API |
| 2 | Stock Price Strength | NGX 30 stocks at 52-week highs vs lows | NGX Pulse API |
| 3 | Market Breadth | Advance/decline ratio | NGX Pulse API |
| 4 | Market Volatility | Rolling 30-day std dev of ASI returns (inverted) | NGX Pulse API |
| 5 | Safe Haven Demand | T-bill stop rate vs equity earnings yield (inverted) | NGX Pulse API |
| 6 | FX Pressure | 30-day USD/NGN momentum (inverted) | fawazahmed0 Currency API |
| 7 | Oil Price Momentum | 30-day Brent crude return | EIA / Commodity API |

Signals 4, 5, and 6 are inverted — a high raw value indicates fear, so the z-score is negated before mapping to 0 – 100.

### Sector Level — 5 Signals
Sector index momentum, constituent breadth, sector vs market relative strength, sector P/E premium, sector RSI. Computed for: Banking, Consumer Goods, Oil & Gas, Industrial, Insurance. Telecom is included with available signals only (no dedicated sector index).

### Stock Level — 6 Signals
RSI, 52-week position, MA position (20-day and 50-day), directional volume ratio, P/E vs sector, price momentum. Computed for all 30 NGX 30 constituent stocks.

---

## Tech Stack

**Frontend**
- Vue 3 + TypeScript
- Vite
- TanStack Router v1
- Pinia
- Chart.js via vue-chartjs

**Backend**
- Supabase (PostgreSQL + Edge Functions)
- Deno runtime (Edge Functions)
- Two scheduled Edge Functions run daily at 17:00 and 17:30 UTC (Mon–Fri)

**Data Sources**
- [NGX Pulse API](https://ngxpulse.ng/api) — stocks, market breadth, ASI, sector indices, T-bill rates (free tier)
- [@fawazahmed0/currency-api](https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json) — USD/NGN rate (free, no key)
- EIA API — Brent crude oil prices (free, requires registration)

---

## Project Structure

```
sentient-ng/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── package.json
├── .env.example
│
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   └── 001_initial.sql
│   └── functions/
│       ├── _shared/
│       │   ├── types.ts          # Canonical SignalResult interface
│       │   ├── cors.ts
│       │   ├── ngxpulse.ts       # NGX Pulse API client
│       │   ├── currencyapi.ts    # fawazahmed0 FX client
│       │   ├── oilprice.ts       # EIA Brent crude client
│       │   └── technicals.ts     # RSI, SMA, z-score utilities
│       ├── sync-market-data/
│       │   └── index.ts          # Fetches & stores raw data daily
│       └── compute-fear-greed/
│           └── index.ts          # Computes & stores F&G scores daily
│
└── src/
    ├── main.ts
    ├── App.vue
    ├── App.css
    ├── router/
    │   └── index.ts
    ├── types/
    │   └── index.ts
    ├── services/
    │   ├── supabase.ts
    │   └── fearGreed.ts
    ├── utils/
    │   ├── technicals.ts
    │   └── normalize.ts
    ├── stores/
    │   ├── marketStore.ts
    │   ├── sectorStore.ts
    │   └── stockStore.ts
    ├── composables/
    │   ├── useMarketFearGreed.ts
    │   ├── useSectorFearGreed.ts
    │   └── useStockFearGreed.ts
    ├── components/
    │   ├── gauge/
    │   │   ├── FearGreedGauge.vue
    │   │   └── FearGreedGauge.css
    │   ├── signals/
    │   │   ├── SignalBreakdown.vue
    │   │   └── SignalBreakdown.css
    │   ├── charts/
    │   │   ├── HistoryChart.vue
    │   │   └── HistoryChart.css
    │   ├── layout/
    │   │   ├── NavBar.vue
    │   │   ├── NavBar.css
    │   │   ├── PageHeader.vue
    │   │   └── PageHeader.css
    │   ├── market/
    │   │   ├── BreadthWidget.vue
    │   │   └── BreadthWidget.css
    │   ├── sector/
    │   │   ├── SectorCard.vue
    │   │   └── SectorCard.css
    │   └── stocks/
    │       ├── StockTable.vue
    │       └── StockTable.css
    └── views/
        ├── MarketView.vue
        ├── MarketView.css
        ├── SectorsView.vue
        ├── SectorsView.css
        ├── SectorDetailView.vue
        ├── SectorDetailView.css
        ├── StocksView.vue
        ├── StocksView.css
        ├── StockDetailView.vue
        └── StockDetailView.css
```

---

## Database Tables

| Table | Purpose |
|---|---|
| `ngx30_stocks` | Canonical NGX 30 constituent list |
| `market_breadth` | Daily advance/decline + ASI snapshot |
| `sector_index_history` | Daily closing value per sector index |
| `stock_price_history` | Daily close, change %, and volume per NGX 30 stock |
| `stock_metadata` | Latest P/E ratio and market cap per stock |
| `tbill_rates` | T-bill auction stop rates |
| `fx_rates` | Daily USD/NGN exchange rate |
| `oil_prices` | Daily Brent crude price |
| `market_fear_greed` | Computed daily F&G score for the whole market |
| `sector_fear_greed` | Computed daily F&G score per sector |
| `stock_fear_greed` | Computed daily F&G score per NGX 30 stock |
| `sync_log` | Audit trail of Edge Function runs |

All tables have Row Level Security enabled. Public read via anon key. Writes are restricted to the service role (Edge Functions only).

---

## Frontend Routes

| Route | Page |
|---|---|
| `/` | Market overview — gauge, signal breakdown, history chart |
| `/sectors` | Sector grid — all sectors with their F&G scores |
| `/sectors/:id` | Sector detail — sector gauge + constituent stocks ranked by score |
| `/stocks` | NGX 30 screener — all stocks sorted by F&G score |
| `/stocks/:symbol` | Stock detail — gauge, signal breakdown, price history chart |

---

## Local Setup

### Prerequisites
- Node.js 20+
- Supabase CLI (`npm install -g supabase`)
- A Supabase project ([supabase.com](https://supabase.com))
- An NGX Pulse API key ([ngxpulse.ng](https://ngxpulse.ng))
- An EIA API key ([eia.gov](https://www.eia.gov/opendata/register.php)) — free registration

### 1. Clone and install

```bash
git clone https://github.com/your-username/sentient-ng.git
cd sentient-ng
npm install
```

### 2. Environment variables

Copy `.env.example` to `.env` and fill in your Supabase credentials:

```bash
cp .env.example .env
```

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### 3. Supabase setup

```bash
# Link to your Supabase project
supabase link --project-ref your-project-ref

# Run the database migration
supabase db push

# Set Edge Function secrets (server-side only — never in .env)
supabase secrets set NGX_PULSE_API_KEY=your-ngxpulse-key
supabase secrets set EIA_API_KEY=your-eia-key
```

### 4. Deploy Edge Functions

```bash
supabase functions deploy sync-market-data
supabase functions deploy compute-fear-greed
```

### 5. Trigger the initial backfill

On first deployment, run the sync function manually to backfill historical data. This will use approximately 38 of your 100 daily API calls:

```bash
supabase functions invoke sync-market-data
```

Wait 2–3 minutes, then run the compute function to generate the first set of scores:

```bash
supabase functions invoke compute-fear-greed
```

After this, both functions run automatically every weekday via the configured cron schedule.

### 6. Start the frontend

```bash
npm run dev
```

Visit `http://localhost:5173`

---

## Cron Schedule

Both Edge Functions run on weekdays only (Mon–Fri):

| Function | Time (UTC) | Time (WAT) | Purpose |
|---|---|---|---|
| `sync-market-data` | 17:00 | 18:00 | Fetch & store raw market data |
| `compute-fear-greed` | 17:30 | 18:30 | Compute & store F&G scores |

The 30-minute gap ensures sync always completes before compute begins. The compute function also checks `sync_log` for a successful sync entry before proceeding, as an explicit guard.

---

## Known Constraints & Graceful Degradation

**API rate limit:** The NGX Pulse free tier allows 100 requests/day. Ongoing daily sync uses ~9 calls. The one-time historical backfill uses ~38 calls. Both fit within the limit.

**Market breadth baseline:** The advance/decline breadth signal cannot be backfilled from historical data — the NGX Pulse API only returns today's breadth. For the first 252 trading days, the breadth signal uses min-max normalization over the available window instead of z-score. A baseline progress indicator is shown on the market overview page.

**Partial sync failure:** If an individual data source fails (e.g. T-bill rates endpoint), the affected signal uses the most recent available value marked as stale. The compute function proceeds as long as at least 5 of 7 market signals have values.

**Limited stock history:** Stocks with fewer than 30 days of history are excluded from scoring. Stocks with 30 – 251 days show a "Limited history" badge and use neutral scores (50) for signals requiring more data than is available.

**Telecom sector:** AIRTELAFRI and MTNN are the only NGX 30 stocks in Telecom and there is no dedicated NGX Telecom sector index. Telecom is included in sector scoring with available signals only; momentum and RSI signals are marked unavailable.

**NGX 30 reconstitution:** When a stock is added to or removed from the NGX 30, update the `ngx30_stocks` table directly in Supabase (`is_active` flag, `removed_date`). The sync and compute functions filter on `is_active = true` automatically.

---

## Deployment

The frontend deploys to Vercel or Netlify with no additional configuration. Point the build command to `npm run build` and the output directory to `dist/`.

The backend (Supabase Edge Functions + database) is fully managed by Supabase. No separate server is needed.

---

## Relationship to PulseNG

SentientNG is a standalone project. It shares the same underlying data source (NGX Pulse API) as PulseNG but serves a different purpose — where PulseNG shows you what the market is doing, SentientNG tells you how the market is feeling.

---

## License

MIT
