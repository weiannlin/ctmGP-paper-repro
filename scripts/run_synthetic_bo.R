# Rerun the full synthetic BO study reported in the manuscript.

script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE) else NULL
}

this <- script_path()
repo_root <- if (!is.null(this)) {
  normalizePath(file.path(dirname(this), ".."), mustWork = TRUE)
} else {
  normalizePath(".", mustWork = TRUE)
}
setwd(repo_root)

source(file.path(repo_root, "R", "synthetic_bo_config.R"))
source(file.path(repo_root, "R", "synthetic_bo_core.R"))

run_synthetic_bo(
  sweep_config = default_sweep_config,
  ctmgp_config = default_ctmgp_config,
  qqigp_config = default_qqigp_config,
  qqmgp_config = default_qqmgp_config,
  optim_config = default_optim_config,
  overwrite = FALSE
)
