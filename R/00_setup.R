# 00_setup.R --------------------------------------------------------------
#
# Loads packages and sets project-wide options. Sourced by every other
# script so individual files can be run standalone in Positron.
#
# Bioinformatics framing:
#   - Players are "samples"
#   - Stats (HR, OBP, K%, ...) are "features" (think genes / proteins)
#   - A season is one "experiment"; we will compute differential metrics,
#     a heatmap of z-scored features, a volcano plot of expected vs.
#     observed performance, and a PCA of player profiles.

suppressPackageStartupMessages({
  library(baseballr)   # MLB Stats API + Fangraphs scrapers
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(readr)
  library(ggplot2)
  library(ggrepel)
  library(scales)
  library(pheatmap)
  library(viridis)
  library(here)
})

theme_set(theme_minimal(base_size = 12))

# Paths
dir.create(here("data"),    showWarnings = FALSE)
dir.create(here("figures"), showWarnings = FALSE)

# Constants
MARINERS_TEAM_ID <- 136     # MLB Stats API team ID (kept for reference)
MARINERS_ABBR    <- "SEA"   # FanGraphs team abbreviation
SEASON           <- 2026

# A small palette that reads as "Mariners" without being garish.
mariners_palette <- c(
  navy   = "#0C2C56",
  teal   = "#005C5C",
  silver = "#C4CED4",
  cream  = "#EEF4F7"
)

# ---- Baseball Savant player links ---------------------------------------
#
# Savant player URLs look like
#   /savant-player/cal-raleigh-663728?stats=statcast-r-hitting-mlb
# The trailing MLBAM id is what actually resolves the page; the leading name
# slug is cosmetic, so an approximate slug still lands on the right player.

# Turn "Julio Rodríguez" -> "julio-rodriguez", "J.P. Crawford" -> "jp-crawford".
savant_slug <- function(name) {
  s <- iconv(name, to = "ASCII//TRANSLIT")        # strip accents
  s[is.na(s)] <- name[is.na(s)]                    # fall back if iconv failed
  s <- tolower(s)
  s <- gsub("[.'']", "", s)                        # drop periods / apostrophes
  s <- gsub("[^a-z0-9]+", "-", s)                  # everything else -> hyphen
  gsub("^-+|-+$", "", s)                           # trim stray hyphens
}

# Build a full Savant player URL. Returns NA when the id is missing so callers
# can skip players we can't link.
savant_url <- function(name, id, kind = c("hitting", "pitching")) {
  kind <- match.arg(kind)
  ifelse(
    is.na(id) | is.na(name),
    NA_character_,
    sprintf(
      "https://baseballsavant.mlb.com/savant-player/%s-%s?stats=statcast-r-%s-mlb",
      savant_slug(name), id, kind
    )
  )
}
