# web/ — animated WebGL front end

The public-facing site: a **Next.js + TypeScript** app that renders the 2026
Mariners stats as animated, 3D **react-three-fiber** charts. It is fully static
— all data is prebuilt JSON, so there is no server runtime.

## How data gets here

The R pipeline at the repo root writes JSON into [`public/data/`](public/data):

```
R/01_fetch_data.R   ── FanGraphs fetch (+ synthetic fallback)  ─┐
R/06_war_history.R  ── cumulative WAR time series              ─┤→ data/*.rds
R/07_export_json.R  ── serialize the .rds frames to JSON       ─┘→ web/public/data/*.json
```

Regenerate it anytime (needs the R toolchain — see the repo root README):

```bash
cd ..
Rscript -e 'source("R/01_fetch_data.R"); source("R/06_war_history.R"); source("R/07_export_json.R")'
```

`public/data/` files: `batting.json`, `pitching.json`, `war_history.json`,
`meta.json`. PCA is **not** precomputed — it is run client-side from the batting
features by [`lib/pca.ts`](lib/pca.ts) (via `ml-pca`), so it always matches the
shipped data.

## Develop

```bash
npm install
npm run dev          # http://localhost:3000
```

> **In a devcontainer / WSL:** file watching needs polling. Run
> `WATCHPACK_POLLING=true npm run dev` so edits hot-reload.

## Build (static export)

```bash
npm run build        # → web/out/  (static HTML/JS, what Vercel serves)
```

## Layout

| Path | What |
|---|---|
| `app/` | Next App Router: `layout.tsx` (fonts, backdrop), `page.tsx` (dashboard), `globals.css` (sci-fi design tokens) |
| `lib/data.ts` | JSON types + loaders |
| `lib/pca.ts` | client-side PCA (ml-pca) |
| `lib/palette.ts` / `lib/scale.ts` / `lib/stats.ts` | color tokens, axis scales, pnorm |
| `components/three/` | shared WebGL: `Scene` (bloom/lights/orbit), `Scatter3D`, `Axes3D` |
| `components/charts/` | `PcaChart`, `VolcanoChart`, `HardHitChart` (3D); `Bars2D`, `TrendChart` (animated 2D) |
| `components/ui/` | `ChartCard`, `LazyMount` (caps live WebGL contexts) |

## Charts: when 3D, when 2D

3D is used only where there is a genuine third axis (PCA components, PA on the
volcano, launch angle on contact quality). Value-comparison charts (ERA−xERA,
BABIP) stay 2D — a 3D bar chart distorts the lengths you are meant to compare —
but animate in for life.

## Deploy

CI builds this app and deploys the static output to Vercel as a prebuilt bundle;
see [`../.github/workflows/refresh.yml`](../.github/workflows/refresh.yml) and
[`../docs/DEPLOY.md`](../docs/DEPLOY.md). No Vercel dashboard build/framework
config is needed — it serves the prebuilt files.
