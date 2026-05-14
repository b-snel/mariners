# 01_fetch_data.R ---------------------------------------------------------
#
# Pulls 2026 Seattle Mariners player-level batting and pitching stats from
# the MLB Stats API via {baseballr}. If the API call fails (offline demo,
# rate limit, etc.) we fall back to a deterministic synthetic dataset so
# downstream scripts always have something to work with.
#
# Bioinformatics analogy: this is the "load count matrix from disk" step.

source(here::here("R", "00_setup.R"))

# ---- Helpers ------------------------------------------------------------

try_fetch_batting <- function(season, team_abbr = "SEA") {
  tryCatch({
    df <- baseballr::fg_batter_leaders(
      startseason = as.character(season),
      endseason   = as.character(season),
      lg          = "all",
      qual        = "30",
      ind         = "0"
    )
    if (is.null(df) || nrow(df) == 0) stop("empty response")
    team_col <- Find(function(x) x %in% names(df), c("Team", "team_name", "team", "Tm"))
    if (is.null(team_col)) stop(paste("no team column found; available:", paste(names(df), collapse = ", ")))
    df <- df[toupper(df[[team_col]]) == toupper(team_abbr), ]
    if (nrow(df) == 0) stop(paste("no rows for", team_abbr, "— unique values in", team_col, ":", paste(unique(df[[team_col]])[1:5], collapse = ", ")))
    df
  }, error = function(e) {
    message("  baseballr fetch failed (", conditionMessage(e), ") — using synthetic data.")
    NULL
  })
}

try_fetch_pitching <- function(season, team_abbr = "SEA") {
  tryCatch({
    df <- baseballr::fg_pitcher_leaders(
      startseason = as.character(season),
      endseason   = as.character(season),
      lg          = "all",
      qual        = "10",
      ind         = "0"
    )
    if (is.null(df) || nrow(df) == 0) stop("empty response")
    team_col <- Find(function(x) x %in% names(df), c("Team", "team_name", "team", "Tm"))
    if (is.null(team_col)) stop(paste("no team column found; available:", paste(names(df), collapse = ", ")))
    df <- df[toupper(df[[team_col]]) == toupper(team_abbr), ]
    if (nrow(df) == 0) stop(paste("no rows for", team_abbr, "— unique values in", team_col, ":", paste(unique(df[[team_col]])[1:5], collapse = ", ")))
    df
  }, error = function(e) {
    message("  baseballr fetch failed (", conditionMessage(e), ") — using synthetic data.")
    NULL
  })
}

# ---- API response normalizer --------------------------------------------
#
# The MLB Stats API uses verbose snake_case column names and stores rate
# stats as character strings.  Map them to the tidy schema used everywhere
# else in the notebook and derive wOBA / xwOBA from available columns.

normalize_batting <- function(df) {
  # FanGraphs column aliases -> target names used throughout the notebook
  aliases <- list(
    player = c("Name", "PlayerName"),
    pos    = c("Pos", "Position"),
    pa     = c("PA"),
    hr     = c("HR"),
    bb     = c("BB"),
    k      = c("SO", "K"),
    ba     = c("AVG", "BA"),
    obp    = c("OBP"),
    slg    = c("SLG"),
    woba   = c("wOBA"),
    xwoba  = c("xwOBA", "xwoba")
  )

  for (target in names(aliases)) {
    if (target %in% names(df)) next
    for (src in aliases[[target]]) {
      if (src %in% names(df)) { df[[target]] <- df[[src]]; break }
    }
  }

  for (col in c("pa", "hr", "bb", "k", "ba", "obp", "slg", "woba", "xwoba")) {
    if (col %in% names(df)) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }

  df <- df[!is.na(df$pa) & df$pa > 10, ]

  # xwOBA may be absent early in the season before Statcast publishes it;
  # fall back to a small jitter on wOBA so downstream plots still render
  if (!"xwoba" %in% names(df) || all(is.na(df$xwoba))) {
    set.seed(2026)
    df$xwoba <- round(df$woba * (1 + stats::runif(nrow(df), -0.04, 0.04)), 3)
  }

  df$diff <- round(df$woba - df$xwoba, 3)

  keep <- intersect(
    c("player", "pos", "pa", "hr", "bb", "k", "ba", "obp", "slg", "woba", "xwoba", "diff"),
    names(df)
  )
  df[, keep, drop = FALSE]
}

normalize_pitching <- function(df) {
  aliases <- list(
    player = c("Name", "PlayerName"),
    ip     = c("IP"),
    k      = c("SO", "K"),
    bb     = c("BB"),
    hr     = c("HR"),
    era    = c("ERA"),
    fip    = c("FIP"),
    xera   = c("xERA", "xFIP")
  )

  for (target in names(aliases)) {
    if (target %in% names(df)) next
    for (src in aliases[[target]]) {
      if (src %in% names(df)) { df[[target]] <- df[[src]]; break }
    }
  }

  for (col in c("ip", "k", "bb", "hr", "era", "fip", "xera")) {
    if (col %in% names(df)) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }

  df <- df[!is.na(df$ip) & df$ip > 0, ]

  # Classify as starter (SP) or reliever (RP) by innings pitched threshold
  if (!"role" %in% names(df)) {
    df$role <- ifelse(!is.na(df$ip) & df$ip >= 20, "SP", "RP")
  }

  if (!"fip" %in% names(df) || all(is.na(df$fip))) {
    df$fip <- round(((13 * df$hr + 3 * df$bb - 2 * df$k) / df$ip) + 3.20, 3)
  }
  if (!"xera" %in% names(df) || all(is.na(df$xera))) {
    set.seed(2027)
    df$xera <- round(df$era * (1 + stats::runif(nrow(df), -0.05, 0.05)), 3)
  }

  df$era_minus_xera <- round(df$era - df$xera, 3)
  df$k_per_9        <- round(df$k / df$ip * 9, 2)
  df$bb_per_9       <- round(df$bb / df$ip * 9, 2)

  keep <- intersect(
    c("player", "role", "ip", "k", "bb", "hr", "era", "fip", "xera",
      "era_minus_xera", "k_per_9", "bb_per_9"),
    names(df)
  )
  df[, keep, drop = FALSE]
}

# ---- Synthetic fallback -------------------------------------------------
#
# Plausible-looking ~6-weeks-into-2026 stat lines for the Mariners core.
# Numbers are illustrative; the point is to exercise the visualizations.

synth_batting <- function() {
  set.seed(2026)
  players <- tibble::tribble(
    ~player,             ~pos,  ~pa,  ~hr, ~bb,  ~k,  ~ba,    ~obp,   ~slg,   ~xwoba,
    "Cal Raleigh",        "C",   168,  12,  21,  44,  0.252,  0.341,  0.531,  0.382,
    "Julio Rodriguez",    "CF",  172,   8,  18,  46,  0.279,  0.349,  0.476,  0.371,
    "Jorge Polanco",      "2B",  155,   7,  14,  35,  0.268,  0.336,  0.461,  0.354,
    "Randy Arozarena",    "LF",  161,   6,  19,  41,  0.234,  0.327,  0.402,  0.343,
    "J.P. Crawford",      "SS",  158,   3,  24,  29,  0.247,  0.358,  0.358,  0.326,
    "Luke Raley",         "RF",  142,   8,  12,  38,  0.261,  0.331,  0.498,  0.361,
    "Dominic Canzone",    "RF",  118,   5,   9,  31,  0.241,  0.305,  0.428,  0.318,
    "Mitch Garver",       "DH",  121,   6,  14,  33,  0.219,  0.314,  0.408,  0.339,
    "Dylan Moore",        "UT",  104,   4,  13,  29,  0.232,  0.327,  0.382,  0.305,
    "Victor Robles",      "CF",   89,   2,   8,  19,  0.281,  0.348,  0.397,  0.298,
    "Leo Rivas",          "SS",   72,   1,   9,  18,  0.225,  0.319,  0.295,  0.272,
    "Tyler Locklear",     "1B",   64,   3,   5,  21,  0.214,  0.281,  0.411,  0.331
  )
  players |> dplyr::mutate(
    woba   = round((0.69 * bb + 0.89 * (ba * pa) + 0.5 * hr) / pa, 3),
    diff   = round(woba - xwoba, 3)
  )
}

synth_pitching <- function() {
  set.seed(2026L + 1L)
  tibble::tribble(
    ~player,            ~role, ~ip,  ~k,   ~bb, ~hr,  ~era,  ~fip,  ~xera,
    "Logan Gilbert",      "SP", 48.1, 56,  10,  4,   2.79,  3.05,  3.21,
    "Luis Castillo",      "SP", 45.2, 49,  13,  6,   3.55,  3.71,  3.62,
    "George Kirby",       "SP", 47.0, 44,   6,  5,   3.07,  3.18,  3.04,
    "Bryce Miller",       "SP", 42.0, 41,  11,  7,   4.07,  4.21,  3.98,
    "Bryan Woo",          "SP", 39.1, 38,   8,  5,   3.43,  3.55,  3.40,
    "Andres Munoz",       "RP", 17.2, 23,   4,  1,   1.53,  1.84,  2.10,
    "Matt Brash",         "RP", 16.0, 21,   6,  2,   2.81,  3.07,  3.20,
    "Gabe Speier",        "RP", 15.1, 14,   5,  2,   3.52,  3.99,  3.61,
    "Collin Snider",      "RP", 14.0, 12,   4,  3,   4.50,  4.71,  4.32,
    "Trent Thornton",     "RP", 13.2, 13,   5,  2,   3.95,  4.18,  4.05,
    "Carlos Vargas",      "RP", 12.0, 11,   7,  1,   4.50,  5.02,  4.61,
    "Casey Lawrence",     "RP", 11.0,  8,   3,  3,   5.73,  5.41,  5.10
  ) |> dplyr::mutate(
    era_minus_xera = round(era - xera, 3),
    k_per_9 = round(k / ip * 9, 2),
    bb_per_9 = round(bb / ip * 9, 2)
  )
}

# ---- Run ----------------------------------------------------------------

message("Fetching 2026 Mariners batting ...")
batting_raw <- try_fetch_batting(SEASON, MARINERS_ABBR)
batting     <- if (is.null(batting_raw)) synth_batting() else normalize_batting(batting_raw)

message("Fetching 2026 Mariners pitching ...")
pitching_raw <- try_fetch_pitching(SEASON, MARINERS_ABBR)
pitching     <- if (is.null(pitching_raw)) synth_pitching() else normalize_pitching(pitching_raw)

saveRDS(batting,  here("data", "batting_2026.rds"))
saveRDS(pitching, here("data", "pitching_2026.rds"))

message("Wrote ", nrow(batting), " batter rows and ",
        nrow(pitching), " pitcher rows to data/.")
