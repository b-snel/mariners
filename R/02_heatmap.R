# 02_heatmap.R ------------------------------------------------------------
#
# Heatmap of z-scored batting features across the active roster.
#
# Bioinformatics analogy: this is the canonical "samples on columns,
# features on rows, scaled within row" expression heatmap. Players are
# samples; offensive rate stats are features. Clustering should pull
# the OBP-leaning skill set away from the power-leaning skill set.

source(here::here("R", "00_setup.R"))

batting <- readRDS(here("data", "batting_2026.rds"))

# Feature matrix: players (cols) x stats (rows), scaled within feature.
features <- c("ba", "obp", "slg", "woba", "xwoba", "hr", "bb", "k")

mat <- batting |>
  dplyr::select(player, dplyr::all_of(features)) |>
  tidyr::drop_na() |>                          # drop any player missing a stat
  tibble::column_to_rownames("player") |>
  as.matrix() |>
  scale(center = TRUE, scale = TRUE) |>        # z-score each stat (col) across players
  t()                                          # transpose to features × players for pheatmap

# Annotation track for player position — same idea as a "cell type" track.
# Omit the annotation entirely when position data is unavailable (e.g. live
# FanGraphs data, which doesn't expose a position-abbreviation column).
has_positions <- !all(batting$pos == "UNK")

if (has_positions) {
  annot_col <- batting |>
    dplyr::select(player, pos) |>
    tibble::column_to_rownames("player")
  annot_colors <- list(
    pos = c(
      C  = "#0C2C56", "1B" = "#005C5C", "2B" = "#1B998B",
      SS = "#3A86FF", "3B" = "#8338EC", LF = "#FB5607",
      CF = "#FFBE0B", RF = "#FF006E", DH = "#6A4C93", UT = "#7F7F7F",
      UNK = "#AAAAAA"
    )
  )
} else {
  annot_col    <- NA
  annot_colors <- NA
}

# Draw function so the same heatmap can be written to a PNG (for 05_export.R
# and standalone use) and also drawn inline on the active device by the Quarto
# notebook — which avoids any include_graphics() path resolution.
draw_heatmap <- function() {
  pheatmap::pheatmap(
    mat,
    color             = viridis::magma(100),
    annotation_col    = annot_col,
    annotation_colors = if (identical(annot_colors, NA)) NA else annot_colors,
    cluster_rows      = TRUE,
    cluster_cols      = TRUE,
    fontsize          = 11,
    main              = "Mariners 2026 — Z-scored batting features (player × stat)",
    border_color      = NA
  )
}

invisible({
  png(here("figures", "02_heatmap.png"),
      width = 1600, height = 1100, res = 180)
  tryCatch(draw_heatmap(), finally = dev.off())
})

message("Wrote figures/02_heatmap.png")
