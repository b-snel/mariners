# 07_export_json.R --------------------------------------------------------
#
# Bridges the R data pipeline to the TypeScript front end. Reads the tidy
# .rds files produced by 01_fetch_data.R and 06_war_history.R and writes
# plain JSON into the Next.js app (web/public/data/), which renders the
# animated WebGL charts on Vercel.
#
# Vercel runs no R — this script runs in CI (or locally) and the JSON it
# emits is what the site ships. PCA is computed client-side from the batting
# features (see web/), so this script only serializes the data frames.

source(here::here("R", "00_setup.R"))
library(jsonlite)

out_dir <- here("web", "public", "data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# The fetch + war-history scripts must have run first.
if (!file.exists(here("data", "batting_2026.rds"))) {
  source(here::here("R", "01_fetch_data.R"))
}
if (!file.exists(here("data", "war_history.rds"))) {
  source(here::here("R", "06_war_history.R"))
}

batting  <- tibble::as_tibble(readRDS(here("data", "batting_2026.rds")))
pitching <- tibble::as_tibble(readRDS(here("data", "pitching_2026.rds")))
history  <- tibble::as_tibble(readRDS(here("data", "war_history.rds")))

read_marker <- function(file, default = "unknown") {
  tryCatch(readLines(here("data", file), n = 1), error = function(e) default)
}
data_source <- read_marker("data_source.txt")
war_source  <- read_marker("war_source.txt")

# Attach a Baseball Savant deep link per player for the hover cards. The
# helper returns NA when the id is missing, which becomes JSON null.
if ("mlbam_id" %in% names(batting)) {
  batting$savant <- savant_url(batting$player, batting$mlbam_id, "hitting")
}
if ("mlbam_id" %in% names(pitching)) {
  pitching$savant <- savant_url(pitching$player, pitching$mlbam_id, "pitching")
}

write_json_pretty <- function(x, file) {
  jsonlite::write_json(
    x, file.path(out_dir, file),
    dataframe = "rows", auto_unbox = TRUE, na = "null",
    digits = 6, pretty = TRUE
  )
  message("  wrote ", file, " (", if (is.data.frame(x)) nrow(x) else length(x), " rows)")
}

write_json_pretty(batting,  "batting.json")
write_json_pretty(pitching, "pitching.json")
write_json_pretty(history,  "war_history.json")

meta <- list(
  season      = SEASON,
  dataSource  = data_source,         # "live" | "synthetic" | "unknown"
  warSource   = war_source,          # "live" | "synthetic" | "unavailable"
  generatedAt = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
  players     = nrow(batting),
  pitchers    = nrow(pitching)
)
jsonlite::write_json(meta, file.path(out_dir, "meta.json"),
                     auto_unbox = TRUE, pretty = TRUE)
message("  wrote meta.json (source: ", data_source, ", war: ", war_source, ")")

message("Exported JSON to ", out_dir)
