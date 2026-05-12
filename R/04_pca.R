# 04_pca.R ----------------------------------------------------------------
#
# PCA over the player x feature matrix.
#
# Bioinformatics analogy: this is the "PC1 vs PC2 of samples colored by
# condition" plot. Each player is one sample; we expect catchers/sluggers
# to separate from contact/speed profiles along the first PC.

source(here::here("R", "00_setup.R"))

batting <- readRDS(here("data", "batting_2026.rds"))

features <- c("ba", "obp", "slg", "woba", "xwoba", "hr", "bb", "k")

X <- batting |>
  dplyr::select(player, dplyr::all_of(features)) |>
  tibble::column_to_rownames("player") |>
  as.matrix()

pca <- prcomp(X, center = TRUE, scale. = TRUE)

var_explained <- summary(pca)$importance["Proportion of Variance", ]

scores <- as.data.frame(pca$x) |>
  tibble::rownames_to_column("player") |>
  dplyr::left_join(batting |> dplyr::select(player, pos, pa), by = "player")

loadings <- as.data.frame(pca$rotation) |>
  tibble::rownames_to_column("feature")

scale_factor <- max(abs(scores$PC1), abs(scores$PC2)) /
                max(abs(loadings$PC1), abs(loadings$PC2)) * 0.7

p <- ggplot(scores, aes(PC1, PC2)) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dotted", color = "grey60") +
  geom_point(aes(color = pos, size = pa), alpha = 0.9) +
  ggrepel::geom_text_repel(aes(label = player), size = 3.4,
                           max.overlaps = 20, seed = 2) +
  geom_segment(
    data = loadings,
    aes(x = 0, y = 0,
        xend = PC1 * scale_factor,
        yend = PC2 * scale_factor),
    arrow = arrow(length = unit(0.18, "cm")),
    color = "grey40", alpha = 0.6, inherit.aes = FALSE
  ) +
  geom_text(
    data = loadings,
    aes(x = PC1 * scale_factor * 1.07,
        y = PC2 * scale_factor * 1.07,
        label = feature),
    color = "grey25", fontface = "italic", size = 3.4,
    inherit.aes = FALSE
  ) +
  scale_size_continuous(range = c(2, 7), name = "PA") +
  labs(
    title    = "Mariners 2026 — PCA of player batting profiles",
    subtitle = sprintf("PC1 %.0f%% variance · PC2 %.0f%% variance",
                       100 * var_explained[1], 100 * var_explained[2]),
    x = sprintf("PC1 (%.0f%%)", 100 * var_explained[1]),
    y = sprintf("PC2 (%.0f%%)", 100 * var_explained[2]),
    color = "Position"
  )

ggsave(here("figures", "04_pca.png"), p,
       width = 9, height = 6.5, dpi = 200)

message("Wrote figures/04_pca.png")
