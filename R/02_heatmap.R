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
  tibble::column_to_rownames("player") |>
  as.matrix() |>
  t() |>
  scale(center = TRUE, scale = TRUE) |>
  t()

# Annotation track for player position — same idea as a "cell type" track.
annot_col <- batting |>
  dplyr::select(player, pos) |>
  tibble::column_to_rownames("player")

annot_colors <- list(
  pos = c(
    C  = "#0C2C56", "1B" = "#005C5C", "2B" = "#1B998B",
    SS = "#3A86FF", "3B" = "#8338EC", LF = "#FB5607",
    CF = "#FFBE0B", RF = "#FF006E", DH = "#6A4C93", UT = "#7F7F7F"
  )
)

png(here("figures", "02_heatmap.png"),
    width = 1600, height = 1100, res = 180)
pheatmap::pheatmap(
  mat,
  color             = viridis::magma(100),
  annotation_col    = annot_col,
  annotation_colors = annot_colors,
  cluster_rows      = TRUE,
  cluster_cols      = TRUE,
  fontsize          = 11,
  main              = "Mariners 2026 — Z-scored batting features (player × stat)",
  border_color      = NA
)
dev.off()

message("Wrote figures/02_heatmap.png")
