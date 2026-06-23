# 03_volcano.R ------------------------------------------------------------
#
# A volcano plot of "performance vs. expectation".
#
# Bioinformatics analogy:
#   x-axis: effect size  — observed wOBA minus Statcast xwOBA
#                          (positive => over-performing the batted-ball
#                           profile; negative => under-performing)
#   y-axis: -log10(p)    — significance, from a two-sided test of
#                          observed wOBA against xwOBA given PA
#                          (sample-size-aware, just like a count-based
#                           differential expression test)
#
# Players above the dashed thresholds are the season's "differentially
# expressed" hitters — over- or under-performing their underlying
# batted-ball profile to a degree unlikely under chance alone.

# The plot itself lives in R/charts.R (chart_volcano) so the landing page and
# the notebook share one definition. This script just saves the PNG copy used
# by 05_export.R and standalone runs.
source(here::here("R", "charts.R"))

batting <- readRDS(here("data", "batting_2026.rds"))

p <- chart_volcano(batting)

ggsave(here("figures", "03_volcano.png"), p,
       width = 9, height = 6, dpi = 200)

message("Wrote figures/03_volcano.png")
