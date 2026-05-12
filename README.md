# Mariners 2026 — a bioinformatics-flavoured demo

A small R project for showing bioinformaticians what working in a
**Coder** workspace via **Positron** feels like. It uses real(ish) Seattle
Mariners stats and applies the visualizations you'd reach for in an
RNA-seq or proteomics workflow:

| File | Bioinformatics analogue |
|---|---|
| `R/01_fetch_data.R` | load count matrix |
| `R/02_heatmap.R`    | z-scored heatmap with row/column clustering |
| `R/03_volcano.R`    | volcano plot (effect size vs significance) |
| `R/04_pca.R`        | PCA biplot of samples with feature loadings |
| `analysis.qmd`      | the full narrative notebook |

## Quick start

1. Open this folder in **Positron** (`File → Open Folder…`).
2. In the R console:
   ```r
   renv::restore()        # first time only — installs pinned versions
   source("R/01_fetch_data.R")
   source("R/02_heatmap.R")
   source("R/03_volcano.R")
   source("R/04_pca.R")
   ```
3. Render the notebook:
   ```r
   quarto::quarto_render("analysis.qmd")
   ```

If you haven't generated a lockfile yet (fresh checkout, no `renv.lock`),
run this once to bootstrap it from the scripts' `library()` calls:

```r
renv::init()       # scans R/ and analysis.qmd, installs deps
renv::snapshot()   # writes renv.lock
```

## Data source

`R/01_fetch_data.R` calls `baseballr::mlb_team_stats()` against the MLB
Stats API for team_id 136 (Seattle), `season = 2026`. If the call fails
for any reason — no network, rate limit, API hiccup — it falls back to a
deterministic synthetic roster so the rest of the demo always runs. Treat
the synthetic numbers as plausible-but-fake; the visualizations are the
point, not the leaderboard.

## What to point at during the demo

- **renv** — the lockfile is the same idea as a Conda env file: every
  collaborator gets the same package versions, including transitive
  dependencies, regardless of which Coder workspace they spin up.
- **Positron** — RStudio-shaped IDE built on VS Code; the R and Python
  panes coexist, which matches mixed-language analysis work.
- **Coder** — the workspace itself is reproducible: open a fresh one and
  `renv::restore()` brings the project back to the same state.
- **Quarto** — one source file, one command, an HTML report you can hand
  to a PI.

## Project layout

```
.
├── .Rprofile               # sources renv/activate.R on session start
├── mariners-2026.Rproj     # project file (Positron / RStudio)
├── renv/                   # renv bootstrap + settings
│   ├── activate.R
│   └── settings.json
├── R/
│   ├── 00_setup.R
│   ├── 01_fetch_data.R
│   ├── 02_heatmap.R
│   ├── 03_volcano.R
│   └── 04_pca.R
├── data/                   # generated .rds files (gitignored)
├── figures/                # generated .png plots (gitignored)
├── analysis.qmd            # narrative notebook
└── README.md
```

## Caveats

- `renv/activate.R` here is a minimal bootstrap rather than the full
  ~1300-line file renv normally generates. Running `renv::init()` once
  will replace it with the canonical version.
- No `renv.lock` is checked in — generate one with `renv::snapshot()`
  after the first install so the next person gets exactly your versions.
- Stat calculations (wOBA, the volcano significance test) are
  illustrative simplifications, not the official Fangraphs formulas.
