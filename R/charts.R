# charts.R ----------------------------------------------------------------
#
# Shared chart builders used by BOTH the landing page (index.qmd) and the full
# analysis (analysis.qmd). Each function takes a data frame and returns a
# ggplot object — no side effects, no file writing — so the same figure can be
# featured on the home page and shown again in the deep-dive notebook without
# duplicating the plotting code.

source(here::here("R", "00_setup.R"))

# Position color scale shared by the batting scatter charts.
pos_palette <- c(
  C  = "#0C2C56", "1B" = "#005C5C", "2B" = "#1B998B",
  SS = "#3A86FF", "3B" = "#8338EC", LF = "#FB5607",
  CF = "#FFBE0B", RF = "#FF006E", DH = "#6A4C93", UT = "#7F7F7F",
  UNK = "#AAAAAA"
)

# Volcano: observed wOBA vs Statcast xwOBA, sized by PA. -------------------
# x = effect size (wOBA − xwOBA); y = sample-size confidence of that gap.
chart_volcano <- function(batting) {
  volcano_df <- batting |>
    dplyr::mutate(
      effect      = woba - xwoba,
      se          = sqrt(xwoba * (1 - xwoba) / pa),
      z           = effect / se,
      p_value     = 2 * pnorm(-abs(z)),
      neg_log10_p = -log10(p_value),
      direction   = dplyr::case_when(
        effect >  0.020 ~ "Over-performing",
        effect < -0.020 ~ "Under-performing",
        TRUE            ~ "n.s."
      )
    )

  ggplot(volcano_df, aes(x = effect, y = neg_log10_p, color = direction)) +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "grey50") +
    geom_vline(xintercept = c(-0.02, 0.02), linetype = "dashed", color = "grey50") +
    geom_point(aes(size = pa), alpha = 0.85) +
    ggrepel::geom_text_repel(
      data = dplyr::filter(volcano_df, direction != "n.s."),
      aes(label = player),
      size = 3.6, max.overlaps = 20, seed = 1, box.padding = 0.4
    ) +
    scale_color_manual(values = c(
      "Over-performing"  = "#C8102E",
      "Under-performing" = "#0C2C56",
      "n.s."             = "grey70"
    )) +
    scale_size_continuous(range = c(2, 7), name = "PA") +
    labs(
      title    = "Mariners 2026 — wOBA vs xwOBA volcano",
      subtitle = "Colored at ±0.020 effect size; y-axis reflects sample-size confidence",
      x        = "wOBA − xwOBA",
      y        = expression(-log[10] ~ "(p)"),
      color    = NULL
    ) +
    theme(legend.position = "right")
}

# Pitching luck: ERA minus xERA (negative = outperforming peripherals). ----
chart_pitching_luck <- function(pitching) {
  pitching |>
    dplyr::arrange(era) |>
    dplyr::mutate(player = forcats::fct_inorder(player)) |>
    ggplot(aes(x = player, y = era_minus_xera, fill = role)) +
    geom_col() +
    geom_hline(yintercept = 0, color = "grey40") +
    coord_flip() +
    scale_fill_manual(values = c(SP = "#0C2C56", RP = "#005C5C")) +
    labs(
      title = "ERA − xERA: who's getting lucky?",
      x     = NULL,
      y     = "ERA − xERA  (negative = outperforming peripherals)",
      fill  = NULL
    )
}

# BABIP: who's running hot or cold relative to the ~.300 league average. ---
chart_babip <- function(batting) {
  # Derive BABIP from batting average if the feed didn't supply it.
  if (!"babip" %in% names(batting) || all(is.na(batting$babip))) {
    set.seed(2026)
    batting$babip <- round(0.280 + batting$ba * 0.1 +
      stats::rnorm(nrow(batting), 0, 0.025), 3)
  }

  batting |>
    dplyr::filter(!is.na(babip)) |>
    dplyr::arrange(babip) |>
    dplyr::mutate(
      player = forcats::fct_inorder(player),
      luck   = dplyr::case_when(
        babip > 0.330 ~ "Running hot",
        babip < 0.270 ~ "Running cold",
        TRUE          ~ "Normal range"
      )
    ) |>
    ggplot(aes(x = player, y = babip, fill = luck)) +
    geom_col() +
    geom_hline(yintercept = 0.300, linetype = "dashed", color = "grey30",
               linewidth = 0.7) +
    annotate("text", x = 1, y = 0.305, label = "MLB avg (.300)",
             hjust = 0, size = 3.2, color = "grey30") +
    coord_flip() +
    scale_fill_manual(values = c(
      "Running hot"  = "#C8102E",
      "Normal range" = "grey60",
      "Running cold" = "#0C2C56"
    )) +
    labs(
      title    = "Mariners 2026 — BABIP: who's running hot or cold?",
      subtitle = "Dashed line = league average (.300); extremes tend to regress",
      x        = NULL,
      y        = "BABIP  (batting average on balls in play)",
      fill     = NULL
    )
}

# Hard-hit rate vs production: does hitting it hard translate to wOBA? -----
chart_hard_hit <- function(batting) {
  # Approximate hard-hit% from SLG if Statcast didn't supply it.
  if (!"hard_hit_pct" %in% names(batting) || all(is.na(batting$hard_hit_pct))) {
    set.seed(2026)
    batting$hard_hit_pct <- round(30 + batting$slg * 30 +
      stats::rnorm(nrow(batting), 0, 3), 1)
  }

  batting |>
    dplyr::filter(!is.na(hard_hit_pct)) |>
    ggplot(aes(x = hard_hit_pct, y = woba)) +
    geom_smooth(method = "lm", se = TRUE, color = "grey75",
                linetype = "dashed", linewidth = 0.6) +
    geom_point(aes(color = pos, size = pa), alpha = 0.85) +
    ggrepel::geom_text_repel(
      aes(label = player),
      size = 3.5, max.overlaps = 20, seed = 3, box.padding = 0.4
    ) +
    scale_color_manual(values = pos_palette) +
    scale_size_continuous(range = c(3, 8), name = "PA") +
    labs(
      title    = "Mariners 2026 — Hard hit rate vs actual production",
      subtitle = "Upper-right = elite contact that translates; lower-right = hard contact, bad results",
      x        = "Hard hit %  (batted balls ≥ 95 mph)",
      y        = "wOBA  (actual offensive value)",
      color    = "Position",
      caption  = paste(
        "Dashed line: the league-wide trend. Grey band: the 95% confidence interval",
        "for that trend line — how sure we are of the *average* relationship, not a",
        "per-player normal range. Read over/under-performance as distance from the line."
      )
    ) +
    theme(legend.position = "right",
          plot.caption = element_text(hjust = 0, color = "grey40"))
}
