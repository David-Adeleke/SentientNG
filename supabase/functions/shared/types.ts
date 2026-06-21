// supabase/functions/_shared/types.ts
//
// Canonical shared types for SentientNG Edge Functions.
// Both sync-market-data and compute-fear-greed import from here
// to keep signal shapes consistent end-to-end.

/** The five Fear & Greed labels, mapped from a 0-100 score. */
export type FearGreedLabel =
  | "Extreme Fear"
  | "Fear"
  | "Neutral"
  | "Greed"
  | "Extreme Greed";

/** Which level of the hierarchy a Fear & Greed score belongs to. */
export type FearGreedLevel = "market" | "sector" | "stock";

/** NGX sectors with a dedicated sector index (5) plus Telecom (no index). */
export type Sector =
  | "Banking"
  | "Consumer Goods"
  | "Oil & Gas"
  | "Industrial"
  | "Insurance"
  | "Telecom";

/**
 * The result of computing one signal for one entity (market, sector, or stock)
 * on one date. This is the atomic unit that gets stored inside the `signals`
 * JSONB column on market_fear_greed / sector_fear_greed / stock_fear_greed.
 */
export interface SignalResult {
  /** Human-readable signal name, e.g. "Market Momentum", "RSI" */
  name: string;

  /** The raw, un-normalized value used to compute this signal (e.g. ASI/MA ratio, RSI value) */
  raw_value: number | null;

  /** Z-score relative to the entity's own 252-day history. Null if insufficient history. */
  z_score: number | null;

  /** Final 0-100 sub-score after mapping the (possibly inverted) z-score. Null if unavailable. */
  sub_score: number | null;

  /** True if this signal is inverted before scoring (high raw value = fear) */
  is_inverted: boolean;

  /** Data source this signal was derived from */
  source: "ngx_pulse" | "currency_api" | "eia" | "derived";

  /** True if this signal's value is stale (carried forward from a previous successful fetch) */
  is_stale: boolean;

  /** True if this signal is structurally unavailable for this entity (e.g. Telecom momentum/RSI) */
  is_unavailable: boolean;
}

/** Full computed Fear & Greed result for one entity on one date, before DB insert. */
export interface FearGreedResult {
  level: FearGreedLevel;
  /** Sector name (sector level) or stock symbol (stock level). Null at market level. */
  entity_id: string | null;
  date: string; // ISO date, e.g. "2026-06-19"
  score: number;
  label: FearGreedLabel;
  signals: SignalResult[];
  /** Stock level only: true if entity has 30-251 days of history (uses neutral defaults for some signals) */
  limited_history?: boolean;
}

/** Row shape for the sync_log audit table. */
export interface SyncLogEntry {
  function_name: "sync-market-data" | "compute-fear-greed";
  run_date: string; // ISO date
  status: "success" | "partial" | "failed";
  signals_ok: number | null;
  signals_total: number | null;
  error_detail: string | null;
}

/**
 * Maps a 0-100 score to its Fear & Greed label per the fixed bands:
 * 0-20 Extreme Fear, 21-40 Fear, 41-60 Neutral, 61-80 Greed, 81-100 Extreme Greed.
 */
export function scoreToLabel(score: number): FearGreedLabel {
  if (score <= 20) return "Extreme Fear";
  if (score <= 40) return "Fear";
  if (score <= 60) return "Neutral";
  if (score <= 80) return "Greed";
  return "Extreme Greed";
}