# Install dependencies for the ctmGP paper reproduction package.

cran_pkgs <- c(
  "Rcpp",
  "RcppArmadillo",
  "ggplot2",
  "patchwork",
  "lhs"
)

repos <- getOption("repos")
if (is.null(repos) || identical(unname(repos["CRAN"]), "@CRAN@")) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

missing <- cran_pkgs[!vapply(cran_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, repos = repos)
}

script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE) else NULL
}

this <- script_path()
repo_root <- if (!is.null(this)) normalizePath(file.path(dirname(this), ".."), mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
source(file.path(repo_root, "packages", "install_local_packages.R"))
