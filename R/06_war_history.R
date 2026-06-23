# 06_war_history.R --------------------------------------------------------
#
# Builds a tidy daily *cumulative* WAR time series for every Mariners hitter
# and pitcher, so the Trends page (trends.qmd) can show how value has piled
# up over the season and let the reader zoom to the last N days.
#
# Output: data/war_history.rds  — long format: player, type, date, war
#         data/war_source.txt   — "live" | "synthetic" | "unavailable"
#
# Sources, in order of preference:
#   live        — FanGraphs date-range leaderboards sampled at weekly cutoffs.
#                 WAR is cumulative, so [season start, cutoff] gives each
#                 player's season-to-date WAR as of that cutoff.
#   synthetic   — a deterministic per-player daily path (offline / demo).
#   unavailable — the public feed was live but no leaderboard history could be
#                 fetched. We deliberately do NOT invent a daily path for real
#                 players, so the page says "warming up" instead of charting
#                 fabricated trends.

source(here::here("R", "00_setup.R"))

# MLB regular seasons open in the last week of March.
SEASON_START <- as.Date(paste0(SEASON, "-03-26"))

# ---- Live: cumulative WAR from FanGraphs date-range leaderboards ---------
#
# FanGraphs game logs do NOT carry per-game WAR, but the leaderboards do, and
# they accept a custom date range (startdate/enddate, with month="1000" to
# switch FanGraphs into date-range mode). Because WAR is cumulative, the
# leaderboard for [season start, cutoff] is each player's season-to-date WAR
# as of that cutoff. So we sample weekly cutoffs and stack them — one pair of
# calls per cutoff (not per player), joined by name like the Statcast join in
# 01_fetch_data.R. Returns long data (player, date, war, type) or NULL.
try_fetch_war_history <- function(team_abbr = MARINERS_ABBR) {
  last <- Sys.Date()
  cutoffs <- if (last <= SEASON_START + 6) {
    last
  } else {
    seq(SEASON_START + 6, last, by = "7 days")
  }
  if (utils::tail(cutoffs, 1) != last) cutoffs <- c(cutoffs, last)

  fetch_one <- function(cutoff, kind) {
    leaders <- if (kind == "batting") {
      baseballr::fg_batter_leaders
    } else {
      baseballr::fg_pitcher_leaders
    }
    df <- tryCatch(
      leaders(
        startseason = as.character(SEASON),
        endseason   = as.character(SEASON),
        startdate   = format(SEASON_START, "%Y-%m-%d"),
        enddate     = format(cutoff, "%Y-%m-%d"),
        month       = "1000",          # FanGraphs code for a custom date range
        qual        = "0",
        ind         = "0"
      ),
      error = function(e) {
        message("  WAR ", kind, " @ ", cutoff, " failed: ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    team_col <- Find(function(x) x %in% names(df), c("Team", "team_name", "team", "Tm"))
    name_col <- Find(function(x) x %in% names(df), c("Name", "PlayerName"))
    war_col  <- Find(function(x) x %in% names(df), c("WAR", "war"))
    if (is.null(team_col) || is.null(name_col) || is.null(war_col)) {
      message("  WAR ", kind, " @ ", cutoff, ": missing team/name/WAR column")
      return(NULL)
    }

    df <- df[toupper(as.character(df[[team_col]])) == toupper(team_abbr), , drop = FALSE]
    if (nrow(df) == 0) return(NULL)
    data.frame(
      player = as.character(df[[name_col]]),
      date   = cutoff,
      war    = suppressWarnings(as.numeric(df[[war_col]])),
      type   = if (kind == "batting") "Hitter" else "Pitcher",
      stringsAsFactors = FALSE
    )
  }

  out <- list()
  for (i in seq_along(cutoffs)) {        # index keeps Date class (a for-loop over a Date vector drops it)
    out[[length(out) + 1]] <- fetch_one(cutoffs[i], "batting")
    out[[length(out) + 1]] <- fetch_one(cutoffs[i], "pitching")
    Sys.sleep(0.4)                       # be gentle with the FanGraphs API
  }

  res <- do.call(rbind, out)
  if (is.null(res) || nrow(res) == 0) return(NULL)
  res <- res[!is.na(res$war), , drop = FALSE]
  if (nrow(res) == 0) return(NULL)
  message("  built WAR history: ", nrow(res), " rows over ", length(cutoffs),
          " cutoffs, ", length(unique(res$player)), " players.")
  res
}

# ---- Synthetic: a plausible daily path to each player's season WAR -------
#
# Walks from opening day to today, accumulating small daily WAR increments
# (which can dip — a rough day on defense costs value), then rescales so the
# final value lands on the player's season-WAR endpoint. Deterministic.
synth_war_path <- function(players, type_label, seed0) {
  today <- Sys.Date()
  dates <- seq(SEASON_START, today, by = "day")
  n     <- length(dates)

  out <- lapply(seq_len(nrow(players)), function(i) {
    set.seed(seed0 + i)
    total <- players$war[i]
    if (is.na(total)) total <- 0

    inc <- stats::rnorm(n, mean = total / n, sd = (abs(total) / n) * 2 + 0.003)
    cw  <- cumsum(inc)
    cw  <- if (abs(cw[n]) > 1e-9) cw / cw[n] * total else seq(0, total, length.out = n)

    data.frame(
      player = players$player[i],
      date   = dates,
      war    = round(cw, 3),
      type   = type_label,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

# ---- Build --------------------------------------------------------------

# The leaderboard pull must have run first (01_fetch_data.R writes these).
if (!file.exists(here("data", "batting_2026.rds"))) {
  source(here::here("R", "01_fetch_data.R"))
}
batting  <- readRDS(here("data", "batting_2026.rds"))
pitching <- readRDS(here("data", "pitching_2026.rds"))
src <- tryCatch(readLines(here("data", "data_source.txt"), n = 1),
                error = function(e) "unknown")

# Guard against older data files written before `war` existed.
if (!"war" %in% names(batting))  batting$war  <- NA_real_
if (!"war" %in% names(pitching)) pitching$war <- NA_real_

history    <- NULL
war_source <- "synthetic"

if (identical(src, "live")) {
  # Live leaderboards — reconstruct cumulative WAR by date from date-range
  # leaderboard snapshots.
  history <- try_fetch_war_history(MARINERS_ABBR)
  war_source <- if (!is.null(history) && nrow(history) > 0) "live" else "unavailable"
}

if (is.null(history) || nrow(history) == 0) {
  if (identical(src, "live")) {
    # Live data, but no game-log history — emit an empty frame + marker so the
    # page can explain rather than chart invented numbers.
    history <- data.frame(
      player = character(), date = as.Date(character()),
      war = numeric(), type = character(), stringsAsFactors = FALSE
    )
    war_source <- "unavailable"
  } else {
    history <- rbind(
      synth_war_path(batting,  "Hitter",  100L),
      synth_war_path(pitching, "Pitcher", 200L)
    )
    war_source <- "synthetic"
  }
}

history <- tibble::as_tibble(history)
saveRDS(history, here("data", "war_history.rds"))
writeLines(war_source, here("data", "war_source.txt"))
message("Wrote ", nrow(history), " WAR-history rows (source: ", war_source, ").")
