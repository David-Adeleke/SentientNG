-- =====================================================================
-- SentientNG — Initial Schema
-- Fear & Greed Index for the Nigerian Stock Exchange (NGX)
-- =====================================================================
-- All tables: RLS enabled, public read via anon key, writes via
-- service role only (Edge Functions). No authenticated user writes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ngx30_stocks — Canonical NGX 30 constituent list
-- ---------------------------------------------------------------------
create table ngx30_stocks (
  symbol        text primary key,
  name          text not null,
  sector        text not null check (
    sector in ('Banking', 'Consumer Goods', 'Oil & Gas', 'Industrial', 'Insurance', 'Telecom', 'Other')
  ),
  is_active     boolean not null default true,
  added_date    date not null default current_date,
  removed_date  date,
  created_at    timestamptz not null default now()
);

comment on table ngx30_stocks is 'Canonical NGX 30 constituent list. Update is_active/removed_date manually on reconstitution.';

-- ---------------------------------------------------------------------
-- 2. market_breadth — Daily advance/decline + ASI snapshot
-- ---------------------------------------------------------------------
create table market_breadth (
  id              bigint generated always as identity primary key,
  date            date not null,
  asi_value       numeric not null,
  advances        integer not null,
  declines        integer not null,
  unchanged       integer not null,
  fifty_two_wk_highs  integer not null default 0,
  fifty_two_wk_lows   integer not null default 0,
  created_at      timestamptz not null default now(),
  unique (date)
);

-- ---------------------------------------------------------------------
-- 3. sector_index_history — Daily closing value per sector index
-- ---------------------------------------------------------------------
create table sector_index_history (
  id          bigint generated always as identity primary key,
  sector      text not null check (
    sector in ('Banking', 'Consumer Goods', 'Oil & Gas', 'Industrial', 'Insurance')
  ),
  date        date not null,
  close_value numeric not null,
  created_at  timestamptz not null default now(),
  unique (sector, date)
);

comment on table sector_index_history is 'Telecom excluded — no dedicated NGX sector index exists.';

-- ---------------------------------------------------------------------
-- 4. stock_price_history — Daily close, change %, volume per stock
-- ---------------------------------------------------------------------
create table stock_price_history (
  id          bigint generated always as identity primary key,
  symbol      text not null references ngx30_stocks (symbol) on delete cascade,
  date        date not null,
  close_price numeric not null,
  change_pct  numeric not null,
  volume      bigint not null default 0,
  created_at  timestamptz not null default now(),
  unique (symbol, date)
);

-- ---------------------------------------------------------------------
-- 5. stock_metadata — Latest P/E ratio and market cap per stock
-- ---------------------------------------------------------------------
create table stock_metadata (
  symbol        text primary key references ngx30_stocks (symbol) on delete cascade,
  pe_ratio      numeric,
  market_cap    numeric,
  sector_pe_avg numeric,
  updated_at    timestamptz not null default now()
);

comment on table stock_metadata is 'Latest-only snapshot, overwritten in place by sync — no history kept.';

-- ---------------------------------------------------------------------
-- 6. tbill_rates — T-bill auction stop rates
-- ---------------------------------------------------------------------
create table tbill_rates (
  id          bigint generated always as identity primary key,
  date        date not null,
  tenor_days  integer not null,
  stop_rate   numeric not null,
  created_at  timestamptz not null default now(),
  unique (date, tenor_days)
);

-- ---------------------------------------------------------------------
-- 7. fx_rates — Daily USD/NGN exchange rate
-- ---------------------------------------------------------------------
create table fx_rates (
  id          bigint generated always as identity primary key,
  date        date not null,
  usd_ngn     numeric not null,
  created_at  timestamptz not null default now(),
  unique (date)
);

-- ---------------------------------------------------------------------
-- 8. oil_prices — Daily Brent crude price
-- ---------------------------------------------------------------------
create table oil_prices (
  id            bigint generated always as identity primary key,
  date          date not null,
  brent_usd_bbl numeric not null,
  created_at    timestamptz not null default now(),
  unique (date)
);

-- ---------------------------------------------------------------------
-- 9. market_fear_greed — Computed daily F&G score for whole market
-- ---------------------------------------------------------------------
create table market_fear_greed (
  id          bigint generated always as identity primary key,
  date        date not null,
  score       numeric not null check (score >= 0 and score <= 100),
  label       text not null check (
    label in ('Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed')
  ),
  signals     jsonb not null,  -- per-signal raw value, z-score, and 0-100 sub-score
  created_at  timestamptz not null default now(),
  unique (date)
);

comment on column market_fear_greed.signals is
  'Array of 7 signal breakdowns: {name, raw_value, z_score, sub_score, source, is_stale}';

-- ---------------------------------------------------------------------
-- 10. sector_fear_greed — Computed daily F&G score per sector
-- ---------------------------------------------------------------------
create table sector_fear_greed (
  id          bigint generated always as identity primary key,
  sector      text not null check (
    sector in ('Banking', 'Consumer Goods', 'Oil & Gas', 'Industrial', 'Insurance', 'Telecom')
  ),
  date        date not null,
  score       numeric not null check (score >= 0 and score <= 100),
  label       text not null check (
    label in ('Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed')
  ),
  signals     jsonb not null,  -- per-signal breakdown; Telecom marks momentum/RSI as unavailable
  created_at  timestamptz not null default now(),
  unique (sector, date)
);

-- ---------------------------------------------------------------------
-- 11. stock_fear_greed — Computed daily F&G score per NGX 30 stock
-- ---------------------------------------------------------------------
create table stock_fear_greed (
  id              bigint generated always as identity primary key,
  symbol          text not null references ngx30_stocks (symbol) on delete cascade,
  date            date not null,
  score           numeric not null check (score >= 0 and score <= 100),
  label           text not null check (
    label in ('Extreme Fear', 'Fear', 'Neutral', 'Greed', 'Extreme Greed')
  ),
  signals         jsonb not null,  -- per-signal breakdown (6 signals)
  limited_history boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (symbol, date)
);

comment on column stock_fear_greed.limited_history is
  'True when stock has 30-251 days of history; signals needing more data default to neutral (50).';

-- ---------------------------------------------------------------------
-- 12. sync_log — Audit trail of Edge Function runs
-- ---------------------------------------------------------------------
create table sync_log (
  id              bigint generated always as identity primary key,
  function_name   text not null check (
    function_name in ('sync-market-data', 'compute-fear-greed')
  ),
  run_date        date not null,
  status          text not null check (status in ('success', 'partial', 'failed')),
  signals_ok      integer,
  signals_total   integer,
  error_detail    text,
  started_at      timestamptz not null default now(),
  finished_at     timestamptz,
  unique (function_name, run_date)
);

comment on table sync_log is 'compute-fear-greed checks this table for a successful sync-market-data entry before proceeding.';

-- =====================================================================
-- Indexes for common query patterns (date-range lookups per entity)
-- =====================================================================
create index idx_stock_price_history_symbol_date on stock_price_history (symbol, date desc);
create index idx_sector_index_history_sector_date on sector_index_history (sector, date desc);
create index idx_stock_fear_greed_symbol_date on stock_fear_greed (symbol, date desc);
create index idx_sector_fear_greed_sector_date on sector_fear_greed (sector, date desc);
create index idx_market_fear_greed_date on market_fear_greed (date desc);
create index idx_ngx30_stocks_is_active on ngx30_stocks (is_active);

-- =====================================================================
-- Row Level Security — enable on every table
-- =====================================================================
alter table ngx30_stocks         enable row level security;
alter table market_breadth       enable row level security;
alter table sector_index_history enable row level security;
alter table stock_price_history  enable row level security;
alter table stock_metadata       enable row level security;
alter table tbill_rates          enable row level security;
alter table fx_rates              enable row level security;
alter table oil_prices            enable row level security;
alter table market_fear_greed     enable row level security;
alter table sector_fear_greed     enable row level security;
alter table stock_fear_greed      enable row level security;
alter table sync_log              enable row level security;

-- ---------------------------------------------------------------------
-- Public read policies (anon + authenticated) — one per table
-- ---------------------------------------------------------------------
create policy "Public read access" on ngx30_stocks         for select using (true);
create policy "Public read access" on market_breadth       for select using (true);
create policy "Public read access" on sector_index_history for select using (true);
create policy "Public read access" on stock_price_history  for select using (true);
create policy "Public read access" on stock_metadata       for select using (true);
create policy "Public read access" on tbill_rates          for select using (true);
create policy "Public read access" on fx_rates              for select using (true);
create policy "Public read access" on oil_prices            for select using (true);
create policy "Public read access" on market_fear_greed     for select using (true);
create policy "Public read access" on sector_fear_greed     for select using (true);
create policy "Public read access" on stock_fear_greed      for select using (true);
create policy "Public read access" on sync_log              for select using (true);

-- ---------------------------------------------------------------------
-- No insert/update/delete policies are defined for anon/authenticated.
-- With RLS enabled and no matching policy, all writes from those roles
-- are denied by default. The service role bypasses RLS entirely, so
-- Edge Functions (which use the service role key) can write freely.
-- ---------------------------------------------------------------------