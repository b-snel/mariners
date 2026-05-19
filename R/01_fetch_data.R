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

# Fetch primary position for each active roster member via the MLB Stats API.
# Returns a two-column tibble: player (name) + pos (abbreviation e.g. "CF").
fetch_positions <- function(team_id, season) {
  tryCatch({
    roster <- baseballr::mlb_rosters(
      team_id     = team_id,
      season      = season,
      roster_type = "active"
    )
    roster |>
      dplyr::select(
        player = person_full_name,
        pos    = position_abbreviation
      ) |>
      dplyr::distinct(player, .keep_all = TRUE)
  }, error = function(e) {
    message("  roster fetch failed (", conditionMessage(e), ") — positions will be UNK.")
    NULL
  })
}

try_fetch_batting <- function(season, team_abbr = "SEA") {
  tryCatch({
    # Dashboard stats (type=8): PA, AVG, OBP, SLG, wOBA, HR, BB, SO, etc.
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

    # Statcast stats (type=24): xwOBA, xBA, xSLG, etc.
    # Fetched separately because the dashboard preset doesn't include Statcast.
    statcast <- try_fetch_statcast(season)
    if (!is.null(statcast)) {
      name_col <- Find(function(x) x %in% names(statcast), c("Name", "PlayerName"))
      xwoba_col <- Find(function(x) x %in% names(statcast), c("xwOBA", "xwoba"))
      if (!is.null(name_col) && !is.null(xwoba_col)) {
        # Build a Statcast join table with xwOBA + hard-hit metrics
        sc <- data.frame(
          player_sc = statcast[[name_col]],
          xwoba_sc  = suppressWarnings(as.numeric(statcast[[xwoba_col]])),
          stringsAsFactors = FALSE
        )
        # Hard-hit metrics: try common FanGraphs Statcast column names
        for (metric in list(
          list(target = "hard_hit_pct", candidates = c("HardHit%", "Hard%", "HardHit")),
          list(target = "barrel_pct",   candidates = c("Barrel%", "Barrel")),
          list(target = "avg_ev",       candidates = c("EV", "maxEV", "AvgEV", "avg_hit_speed"))
        )) {
          src <- Find(function(x) x %in% names(statcast), metric$candidates)
          if (!is.null(src)) {
            sc[[metric$target]] <- suppressWarnings(as.numeric(statcast[[src]]))
          }
        }

        # Match by the same name column used in the dashboard data
        dash_name_col <- Find(function(x) x %in% names(df), c("Name", "PlayerName"))
        if (!is.null(dash_name_col)) {
          df <- dplyr::left_join(df, sc,
            by = stats::setNames("player_sc", dash_name_col))
          # Prefer Statcast xwOBA over any dashboard value
          if ("xwoba_sc" %in% names(df)) {
            xwoba_existing <- Find(function(x) x %in% names(df), c("xwOBA", "xwoba"))
            if (!is.null(xwoba_existing)) {
              df[[xwoba_existing]] <- dplyr::coalesce(df$xwoba_sc, df[[xwoba_existing]])
            } else {
              df$xwOBA <- df$xwoba_sc
            }
            df$xwoba_sc <- NULL
          }
        }
        message("  joined Statcast data for ", sum(!is.na(sc$xwoba_sc)), " players.")
      }
    }

    df
  }, error = function(e) {
    message("  baseballr fetch failed (", conditionMessage(e), ") — using synthetic data.")
    NULL
  })
}

# Fetch Statcast data (type=24) from FanGraphs for xwOBA.
try_fetch_statcast <- function(season) {
  tryCatch({
    df <- baseballr::fg_batter_leaders(
      startseason = as.character(season),
      endseason   = as.character(season),
      lg          = "all",
      qual        = "30",
      ind         = "0",
      type        = "24"
    )
    if (is.null(df) || nrow(df) == 0) stop("empty Statcast response")
    df
  }, error = function(e) {
    message("  Statcast fetch failed (", conditionMessage(e), ") — xwOBA will be approximate.")
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

normalize_batting <- function(df, positions = NULL) {
  # FanGraphs column aliases -> target names used throughout the notebook
  # NOTE: "Pos" in FanGraphs is a numeric positional-adjustment value (WAR
  # component), not a position abbreviation — we intentionally skip it and
  # fall back to "UNK" so downstream annotation code doesn't break.
  aliases <- list(
    player = c("Name", "PlayerName"),
    pa     = c("PA"),
    hr     = c("HR"),
    bb     = c("BB"),
    k      = c("SO", "K"),
    ba     = c("AVG", "BA"),
    obp    = c("OBP"),
    slg    = c("SLG"),
    woba   = c("wOBA"),
    xwoba  = c("xwOBA", "xwoba"),
    babip  = c("BABIP")
  )

  for (target in names(aliases)) {
    if (target %in% names(df)) next
    for (src in aliases[[target]]) {
      if (src %in% names(df)) { df[[target]] <- df[[src]]; break }
    }
  }

  # FanGraphs does not expose a position-abbreviation column in batter leaders.
  # Join from the separately-fetched roster if available; fall back to "UNK".
  if (!is.null(positions) && nrow(positions) > 0) {
    df <- dplyr::left_join(df, positions, by = "player")
    if ("pos.y" %in% names(df)) {               # resolve collision if pos already existed
      df$pos <- dplyr::coalesce(df$pos.y, df$pos.x)
      df$pos.x <- NULL; df$pos.y <- NULL
    }
  }
  if (!"pos" %in% names(df) || is.numeric(df$pos)) df$pos <- NA_character_
  df$pos[is.na(df$pos)] <- "UNK"

  for (col in c("pa", "hr", "bb", "k", "ba", "obp", "slg", "woba", "xwoba", "babip")) {
    if (col %in% names(df)) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }

  df <- df[!is.na(df$pa) & df$pa > 10, ]

  # xwOBA may be absent early in the season before Statcast publishes it,
  # or have partial NAs; impute any missing values with a small wOBA jitter
  if (!"xwoba" %in% names(df) || anyNA(df$xwoba)) {
    set.seed(2026)
    missing <- is.na(df$xwoba)
    df$xwoba[missing] <- round(
      df$woba[missing] * (1 + stats::runif(sum(missing), -0.04, 0.04)), 3
    )
  }

  df$diff <- round(df$woba - df$xwoba, 3)

  # Coerce Statcast hard-hit metrics to numeric if they came through
  for (col in c("hard_hit_pct", "barrel_pct", "avg_ev")) {
    if (col %in% names(df)) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }

  keep <- intersect(
    c("player", "pos", "pa", "hr", "bb", "k", "ba", "obp", "slg",
      "woba", "xwoba", "diff", "babip", "hard_hit_pct", "barrel_pct", "avg_ev"),
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
    woba         = round((0.69 * bb + 0.89 * (ba * pa) + 0.5 * hr) / pa, 3),
    diff         = round(woba - xwoba, 3),
    babip        = round(0.280 + ba * 0.1 + stats::rnorm(dplyr::n(), 0, 0.025), 3),
    hard_hit_pct = round(30 + slg * 30 + stats::rnorm(dplyr::n(), 0, 3), 1),
    barrel_pct   = round(3 + hr / pa * 200 + stats::rnorm(dplyr::n(), 0, 1.5), 1),
    avg_ev       = round(85 + slg * 10 + stats::rnorm(dplyr::n(), 0, 1), 1)
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

message("Fetching 2026 Mariners roster positions ...")
positions <- fetch_positions(MARINERS_TEAM_ID, SEASON)

message("Fetching 2026 Mariners batting ...")
batting_raw <- try_fetch_batting(SEASON, MARINERS_ABBR)
batting     <- if (is.null(batting_raw)) synth_batting() else normalize_batting(batting_raw, positions)

message("Fetching 2026 Mariners pitching ...")
pitching_raw <- try_fetch_pitching(SEASON, MARINERS_ABBR)
pitching     <- if (is.null(pitching_raw)) synth_pitching() else normalize_pitching(pitching_raw)

saveRDS(batting,  here("data", "batting_2026.rds"))
saveRDS(pitching, here("data", "pitching_2026.rds"))

message("Wrote ", nrow(batting), " batter rows and ",
        nrow(pitching), " pitcher rows to data/.")
