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
#   live        — FanGraphs game logs per player; real game-by-game WAR,
#                 cumulated by date. Requires the FanGraphs player id (fg_id)
#                 that 01_fetch_data.R carries through from the leaderboards.
#   synthetic   — a deterministic per-player daily path (offline / demo).
#   unavailable — the public feed was live but no game-log history could be
#                 fetched. We deliberately do NOT invent a daily path for real
#                 players, so the page says "warming up" instead of charting
#                 fabricated trends.

source(here::here("R", "00_setup.R"))

# MLB regular seasons open in the last week of March.
SEASON_START <- as.Date(paste0(SEASON, "-03-26"))

# ---- Live: cumulative WAR from FanGraphs game logs ----------------------
#
# Returns a long data frame (player, date, war [cumulative], type) or NULL if
# nothing usable came back. Every player fetch is isolated so one bad id can't
# sink the whole series.
try_fetch_war_history <- function(roster, kind = c("batting", "pitching")) {
  kind <- match.arg(kind)
  if (is.null(roster) || !nrow(roster) || !"fg_id" %in% names(roster)) return(NULL)

  game_logs <- if (kind == "batting") {
    baseballr::fg_batter_game_logs
  } else {
    baseballr::fg_pitcher_game_logs
  }
  type_label <- if (kind == "batting") "Hitter" else "Pitcher"

  rows <- list()
  for (i in seq_len(nrow(roster))) {
    id   <- roster$fg_id[i]
    name <- roster$player[i]
    if (is.na(id) || is.na(name)) next

    df <- tryCatch(
      game_logs(playerid = id, year = SEASON),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) next

    date_col <- Find(function(x) x %in% names(df),
                     c("Date", "date", "game_date", "gamedate"))
    war_col  <- Find(function(x) x %in% names(df), c("WAR", "war"))
    if (is.null(date_col) || is.null(war_col)) next

    d <- data.frame(
      player   = name,
      date     = as.Date(df[[date_col]]),
      war_game = suppressWarnings(as.numeric(df[[war_col]])),
      stringsAsFactors = FALSE
    )
    d <- d[!is.na(d$date), ]
    if (!nrow(d)) next
    d <- d[order(d$date), ]
    d$war_game[is.na(d$war_game)] <- 0
    d$war <- cumsum(d$war_game)

    rows[[length(rows) + 1]] <- d[, c("player", "date", "war")]
  }

  if (!length(rows)) return(NULL)
  out <- do.call(rbind, rows)
  out$type <- type_label
  out
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
  # Live leaderboards — try to reconstruct real game-by-game history.
  bh <- if ("fg_id" %in% names(batting)) {
    try_fetch_war_history(batting[, c("player", "fg_id")], "batting")
  }
  ph <- if ("fg_id" %in% names(pitching)) {
    try_fetch_war_history(pitching[, c("player", "fg_id")], "pitching")
  }
  history <- rbind(bh, ph)              # rbind(NULL, x) == x; both NULL -> NULL
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
