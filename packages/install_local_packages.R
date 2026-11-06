# Install local ctGP-family packages for ctmGP paper reproduction.
#
# Run with:
#   Rscript packages/install_local_packages.R

script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE) else NULL
}

this <- script_path()
pkg_dir <- if (!is.null(this)) dirname(this) else getwd()

tarballs <- c(
  ctGP  = file.path(pkg_dir, "ctGP_0.1.16.1.tar.gz"),
  ctmGP = file.path(pkg_dir, "ctmGP_0.1.16.1.tar.gz")
)

target_versions <- c(
  ctGP  = "0.1.16.1",
  ctmGP = "0.1.16.1"
)

missing <- tarballs[!file.exists(tarballs)]
if (length(missing)) {
  stop("Missing package tarballs:\n", paste(missing, collapse = "\n"))
}

install_lib <- Sys.getenv("R_LIBS_USER")
if (!nzchar(install_lib)) {
  install_lib <- .libPaths()[1]
}
dir.create(install_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(install_lib, .libPaths())))

for (pkg in names(tarballs)) {
  installed_version <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
  if (identical(installed_version, target_versions[[pkg]])) {
    message(sprintf("Skipping %s %s; already installed in active library path.", pkg, installed_version))
    next
  }

  message(sprintf("Installing %s from %s", pkg, tarballs[[pkg]]))
  install.packages(tarballs[[pkg]], lib = install_lib, repos = NULL, type = "source")

  installed_version <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
  if (!identical(installed_version, target_versions[[pkg]])) {
    stop(sprintf(
      "Expected %s %s after install, found %s",
      pkg,
      target_versions[[pkg]],
      ifelse(is.na(installed_version), "missing", installed_version)
    ))
  }
}

message("Done. Verify with packageVersion('ctGP') and packageVersion('ctmGP').")
