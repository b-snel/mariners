# Mariners 2026 — a bioinformatics-flavoured demo

A small R project for showing bioinformaticians what working in a
**Coder** workspace via **Positron** feels like. It uses real Seattle
Mariners 2026 stats (live from FanGraphs via `baseballr`, with a
synthetic fallback for offline use) and applies the visualizations
you'd reach for in an RNA-seq or proteomics workflow:

| File | Bioinformatics analogue |
|---|---|
| `R/01_fetch_data.R` | load count matrix |
| `R/02_heatmap.R`    | z-scored heatmap with row/column clustering |
| `R/03_volcano.R`    | volcano plot (effect size vs significance) |
| `R/04_pca.R`        | PCA biplot of samples with feature loadings |
| `analysis.qmd`      | full narrative notebook |
| `app.R`             | interactive Shiny explorer (wOBA vs xwOBA trends) |
| `05_export.R`       | copy figures to `/box/coder-demo` and post top player to Slack |

## Live website & auto-refresh

The notebook is published as a Quarto **website** at
**[mariners.bsnel.com](https://mariners.bsnel.com)**, hosted on Vercel.

Vercel has no R runtime, so it never renders anything itself — it only serves the
static files in `_site/`. All rendering happens in GitHub Actions
([`.github/workflows/refresh.yml`](.github/workflows/refresh.yml)):

1. **Game guard** — each morning (UTC cron, after FanGraphs' ~5–6am ET stats load)
   it asks the MLB Stats API whether the Mariners finished a game the night before.
   Off-days are skipped.
2. **Render** — sets up R 4.5.2 + renv + Quarto, fetches the latest stats once, and
   runs `quarto render` → `_site/`.
3. **Data guard** — if the live fetch fell back to synthetic data, the deploy is
   skipped so the public site keeps its last good numbers.
4. **Deploy** — pushes `_site/` to Vercel via the CLI (`vercel deploy --prebuilt`).

Trigger a refresh by hand anytime from the repo's **Actions → Refresh Mariners
site → Run workflow** (tick `force` to deploy regardless of the guards), or:

```bash
gh workflow run "Refresh Mariners site" -f force=true
```

> **Why "morning after each game" and not real-time?** The stats come from
> FanGraphs *season leaderboards*, which only refresh overnight (~5–6am ET). A
> render fired at the final out would just republish stale aggregates. For true
> post-game updates the data source would need to move to MLB Stats API live
> boxscores.

### One-time setup (Vercel + domain)

See [`docs/DEPLOY.md`](docs/DEPLOY.md) for the exact steps: create the Vercel
project, add the `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` GitHub
secrets, add the `mariners.bsnel.com` domain in Vercel, and add the CNAME record at
GoDaddy. No domain transfer or nameserver change is needed.

## Quick start

1. Open this folder in **Positron** (`File → Open Folder…`).
2. In the R console, restore the package library (first time only):
   ```r
   renv::restore()
   ```
3. Fetch data and generate all figures:
   ```r
   source("R/01_fetch_data.R")
   source("R/02_heatmap.R")
   source("R/03_volcano.R")
   source("R/04_pca.R")
   ```
4. Render the narrative notebook:
   ```r
   quarto::quarto_render("analysis.qmd")
   ```

## Shiny app

An interactive wOBA vs xwOBA explorer. Players above the diagonal are
out-performing their batted-ball profile (expect regression); players
below have upside remaining. Dot size = plate appearances.

```r
shiny::runApp("app.R")
```

The app listens on **port 3838** bound to `0.0.0.0`. In your Coder
workspace, forward that port once:

```bash
coder port-forward <workspace-name> --tcp 3838:3838
```

or add a static rule for port 3838 in your Coder template so it is
always available at the same URL.
Go to https://3838--main--blue-scallop-95--bsnelgrove.coder.thebri.org/ for example to view in browser.
## Export and Slack notification

Copies all figures to `/box/coder-demo` and posts the most
over-performing player (largest wOBA − xwOBA gap) to Slack via `slackme`:

```r
source("05_export.R")
```

Example Slack output:
> Howdy! Randy Arozarena is the most over-performing Mariner: wOBA 0.38 vs xwOBA 0.332 (+0.048 over 180 PA) took 1ms to execute!

## Data source

`R/01_fetch_data.R` calls `baseballr::fg_batter_leaders()` and
`baseballr::fg_pitcher_leaders()` against FanGraphs for the 2026
season, filtered to the Mariners (`Team == "SEA"`). Player positions
are joined from `baseballr::mlb_rosters()` (MLB Stats API, team 136).

If any call fails — no network, rate limit, API hiccup — the script
falls back to a deterministic synthetic roster so the rest of the demo
always runs. The visualizations are the point, not the leaderboard.

## What to point at during the demo

- **renv** — the lockfile is the same idea as a Conda env file: every
  collaborator gets the same package versions regardless of which Coder
  workspace they spin up.
- **Positron** — RStudio-shaped IDE built on VS Code; R and Python
  panes coexist, matching mixed-language analysis work.
- **Coder** — the workspace is reproducible: open a fresh one and
  `renv::restore()` brings the project back to the same state. Port
  forwarding makes the Shiny app accessible from a stable URL.
- **Quarto** — one source file, one command, an HTML report you can
  hand to a PI.

## Project layout

```
.
├── .Rprofile               # sources renv/activate.R on session start
├── mariners-2026.Rproj     # project file (Positron / RStudio)
├── renv/                   # renv bootstrap + settings
├── R/
│   ├── 00_setup.R          # packages, constants, theme
│   ├── 01_fetch_data.R     # FanGraphs fetch + synthetic fallback
│   ├── 02_heatmap.R        # z-scored batting heatmap
│   ├── 03_volcano.R        # wOBA vs xwOBA volcano
│   └── 04_pca.R            # PCA biplot
├── app.R                   # Shiny app (port 3838)
├── 05_export.R             # figure export + Slack notification
├── data/                   # generated .rds files (gitignored)
├── figures/                # generated .png plots (gitignored)
├── analysis.qmd            # narrative notebook
└── README.md
```

## Caveats

- xwOBA is sourced from FanGraphs where available. Early in the season,
  Statcast publication lags a few days; missing values are imputed as
  wOBA ± 4% so downstream plots always render.
- Stat calculations (wOBA linear weights, the volcano significance test)
  are illustrative simplifications, not the official FanGraphs formulas.
- `05_export.R` lives at the project root intentionally — Shiny
  auto-sources everything in `R/` on startup, so run-once scripts belong
  outside that directory.
