# 05_export.R -----------------------------------------------------------------
#
# Finale script:
#   1. Copy all generated figures to /box/coder-demo
#   2. Find the most over-performing Mariner (largest wOBA − xwOBA gap)
#   3. Announce them via Slack using `slackme`

source(here::here("R", "00_setup.R"))

# ---- 1. Copy figures --------------------------------------------------------

dest_dir <- "/box/coder-demo"
dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

figures <- list.files(here("figures"), pattern = "\\.png$", full.names = TRUE)

if (length(figures) == 0) stop("No figures found — run 02/03/04 scripts first.")

copied <- file.copy(figures, file.path(dest_dir, basename(figures)), overwrite = TRUE)
message(sprintf("Copied %d/%d figures to %s", sum(copied), length(figures), dest_dir))

# ---- 2. Find the most over-performing player --------------------------------

batting <- readRDS(here("data", "batting_2026.rds"))

top_player <- batting |>
  dplyr::filter(!is.na(woba), !is.na(xwoba)) |>
  dplyr::mutate(diff = woba - xwoba) |>
  dplyr::slice_max(diff, n = 1)

name <- top_player$player
diff <- round(top_player$diff, 3)
pa   <- top_player$pa
woba <- top_player$woba
xwoba <- top_player$xwoba

message(sprintf("Top over-performer: %s (wOBA %s, xwOBA %s, +%s over %d PA)",
                name, woba, xwoba, diff, pa))

# ---- 3. Send Slack message via slackme --------------------------------------

msg <- sprintf(
  "%s is the most over-performing Mariner: wOBA %s vs xwOBA %s (+%s over %d PA)",
  name, woba, xwoba, diff, pa
)

# slackme formats its Slack message as "Howdy! {command} took {time}ms to execute!"
# so we make the command name *be* the message by writing a named script to /tmp/.
script_name <- gsub("/", "-", msg)   # / is the only char forbidden in Linux filenames
script_path <- file.path("/tmp", script_name)
writeLines(c("#!/bin/bash", "exit 0"), script_path)
Sys.chmod(script_path, "0755")

# Add /tmp to PATH so slackme finds the script by name — no ./ prefix in the message
exit_code <- system(sprintf("PATH=/tmp:$PATH slackme %s", shQuote(script_name)))
unlink(script_path)

if (exit_code == 0) {
  message("Slack message sent.")
} else {
  warning("slackme exited with code ", exit_code, " — message may not have sent.")
}
