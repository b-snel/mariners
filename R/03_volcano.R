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

source(here::here("R", "00_setup.R"))

batting <- readRDS(here("data", "batting_2026.rds"))

# Per-player z-test of wOBA vs xwOBA, treating xwOBA as the null mean and
# using a binomial-ish variance approximation scaled by PA.
volcano_df <- batting |>
  dplyr::mutate(
    effect   = woba - xwoba,
    se       = sqrt(xwoba * (1 - xwoba) / pa),
    z        = effect / se,
    p_value  = 2 * pnorm(-abs(z)),
    neg_log10_p = -log10(p_value),
    # Color by effect size alone — six weeks of PAs (~180) can't reliably
    # reach p < 0.05 on a z-test for realistic wOBA gaps. The y-axis still
    # shows significance so the viewer can see who has the most evidence.
    direction = dplyr::case_when(
      effect >  0.020 ~ "Over-performing",
      effect < -0.020 ~ "Under-performing",
      TRUE            ~ "n.s."
    )
  )

p <- ggplot(volcano_df, aes(x = effect, y = neg_log10_p, color = direction)) +
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
    y        = expression(-log[10]~"(p)"),
    color    = NULL
  ) +
  theme(legend.position = "right")

ggsave(here("figures", "03_volcano.png"), p,
       width = 9, height = 6, dpi = 200)

message("Wrote figures/03_volcano.png")
