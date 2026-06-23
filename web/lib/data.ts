// Data layer ---------------------------------------------------------------
//
// Types + loaders for the JSON the R pipeline writes into public/data/
// (see R/07_export_json.R). Everything here is plain fetch against static
// assets, so it works in the static export with no server runtime.

export interface Batter {
  player: string;
  pos: string;
  mlbam_id?: number | null;
  fg_id?: number | string | null;
  pa: number;
  hr: number;
  bb: number;
  k: number;
  ba: number;
  obp: number;
  slg: number;
  woba: number;
  xwoba: number;
  diff: number;
  babip?: number | null;
  hard_hit_pct?: number | null;
  barrel_pct?: number | null;
  avg_ev?: number | null;
  avg_la?: number | null;
  war?: number | null;
  savant?: string | null;
}

export interface Pitcher {
  player: string;
  role: "SP" | "RP";
  fg_id?: number | string | null;
  mlbam_id?: number | null;
  ip: number;
  k: number;
  bb: number;
  hr: number;
  era: number;
  fip: number;
  xera: number;
  era_minus_xera: number;
  k_per_9: number;
  bb_per_9: number;
  war?: number | null;
  savant?: string | null;
}

export interface WarPoint {
  player: string;
  type: "Hitter" | "Pitcher";
  date: string; // YYYY-MM-DD
  war: number;
}

export interface Meta {
  season: number;
  dataSource: "live" | "synthetic" | "unknown";
  warSource: "live" | "synthetic" | "unavailable";
  generatedAt: string;
  players: number;
  pitchers: number;
}

export interface Dataset {
  batting: Batter[];
  pitching: Pitcher[];
  warHistory: WarPoint[];
  meta: Meta;
}

async function getJSON<T>(path: string): Promise<T> {
  const res = await fetch(path, { cache: "no-store" });
  if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`);
  return (await res.json()) as T;
}

// Load the whole dataset in parallel. Called from a client component on mount.
export async function loadDataset(): Promise<Dataset> {
  const [batting, pitching, warHistory, meta] = await Promise.all([
    getJSON<Batter[]>("data/batting.json"),
    getJSON<Pitcher[]>("data/pitching.json"),
    getJSON<WarPoint[]>("data/war_history.json"),
    getJSON<Meta>("data/meta.json"),
  ]);
  return { batting, pitching, warHistory, meta };
}
