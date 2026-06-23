// Palette & theme tokens ----------------------------------------------------
//
// Anchored on the Mariners' navy/teal but pushed brighter and more luminous so
// the colors read as emissive in a dark WebGL scene. These hex values are the
// single source of truth shared by the 3D materials and the CSS (the CSS mirror
// lives in app/globals.css as custom properties).

export const THEME = {
  bg: "#04070d",
  panel: "#0a1018",
  ink: "#e9f3f7",
  muted: "#7d93a3",
  navy: "#0C2C56",
  teal: "#2dd4bf",
  cyan: "#22d3ee",
  electric: "#38bdf8",
  magenta: "#f0529c",
  amber: "#ffb020",
  green: "#34d399",
  red: "#fb5e6e",
  grid: "#16324a",
} as const;

// Fielding-position colors for the batting scatters. Bright, distinct, and
// tuned to glow against the near-black background.
export const POS_COLORS: Record<string, string> = {
  C: "#38bdf8",
  "1B": "#2dd4bf",
  "2B": "#34d399",
  SS: "#a78bfa",
  "3B": "#c084fc",
  LF: "#fb923c",
  CF: "#facc15",
  RF: "#f0529c",
  DH: "#f472b6",
  UT: "#94a3b8",
  UNK: "#64748b",
};

export function posColor(pos: string): string {
  return POS_COLORS[pos] ?? POS_COLORS.UNK;
}

export const ROLE_COLORS: Record<string, string> = {
  SP: "#38bdf8",
  RP: "#2dd4bf",
};
