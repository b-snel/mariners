# renv activation bootstrap (minimal demo version).
#
# In a project initialised via `renv::init()`, this file is generated
# automatically and is ~1300 lines of self-contained bootstrap. For this
# demo it is intentionally short: it installs renv from CRAN if needed
# and activates the project library. Re-run `renv::init()` at any time
# to replace this file with the canonical bootstrap.
local({
  if (!requireNamespace("renv", quietly = TRUE)) {
    message("Bootstrapping renv from CRAN ...")
    install.packages("renv", repos = "https://cloud.r-project.org")
  }
  renv::activate()
})
