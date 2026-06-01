# Rerun the synthetic emulation RMSE study reported in Figure 5.

suppressPackageStartupMessages({ library(ctmGP); library(parallel) })

script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE) else NULL
}

arg_val <- function(flag, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  i <- which(args == flag)
  if (length(i) && (i + 1L) <= length(args)) args[i + 1L] else default
}

this <- script_path()
repo_root <- if (!is.null(this)) {
  normalizePath(file.path(dirname(this), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "synthetic_bo_config.R"))
source(file.path(repo_root, "R", "synthetic_bo_core.R"))

out_csv <- file.path(repo_root, "data", "synthetic_emulation_rmse.csv")
out_fig <- file.path(repo_root, "figures", "figure5_emulation_rmse.pdf")
progress_log <- file.path(repo_root, "outputs", "emulation_rmse_progress.log")
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(out_fig), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(progress_log), recursive = TRUE, showWarnings = FALSE)

n_workers <- as.integer(arg_val("--n_workers", "5"))
omp_per_worker <- as.integer(arg_val("--omp_per_worker", "4"))

N_PER <- 20L
N_REPS <- 100L
GRID_N <- default_sweep_config$cont_grid_n
problems <- c("VLMOP2", "highcorrVLMOP2")
surrogates <- c("ctmgp", "qqigp", "qqmgp")
optim_config <- default_optim_config
surr_configs <- list(
  ctmgp = default_ctmgp_config,
  qqigp = default_qqigp_config,
  qqmgp = default_qqmgp_config
)

build_grid <- function() {
  u <- seq(-2, 2, length.out = GRID_N)
  expand.grid(x1 = u, x2 = u, z = c("c1", "c2"), stringsAsFactors = FALSE)
}

cand_grid <- build_grid()
true_y_v <- make_eval_fn("VLMOP2")(cand_grid)
true_y_h <- make_eval_fn("highcorrVLMOP2")(cand_grid)

predict_mu <- function(surrogate, fit, grid) {
  pr <- switch(surrogate,
    ctmgp = predict_ctmgp(fit, newdata = grid, joint = FALSE),
    qqigp = predict_qqigp(fit, newdata = grid, joint = FALSE),
    qqmgp = predict_qqmgp(fit, newdata = grid, joint = FALSE)
  )
  t(as.matrix(pr$mu))
}

fit_one <- function(args) {
  problem <- args$problem
  surrogate <- args$surrogate
  seed <- args$seed
  ev <- make_eval_fn(problem)
  train <- make_init(seed, ev, n_per = N_PER, grid_n = GRID_N)
  control <- make_surrogate_control(
    surrogate,
    surr_configs[[surrogate]],
    optim_config,
    seed
  )

  fit <- switch(surrogate,
    ctmgp = do.call(fit_ctmgp, c(list(
      data = train,
      x_cols = c("x1", "x2"),
      w_cols = "z",
      y_cols = c("y1", "y2")
    ), control)),
    qqigp = do.call(fit_qqigp, c(list(
      data = train,
      x_cols = c("x1", "x2"),
      w_cols = "z",
      y_cols = c("y1", "y2")
    ), control)),
    qqmgp = do.call(fit_qqmgp, c(list(
      data = train,
      x_cols = c("x1", "x2"),
      w_cols = "z",
      y_cols = c("y1", "y2")
    ), control))
  )

  mu <- predict_mu(surrogate, fit, cand_grid)
  true_y <- if (problem == "VLMOP2") true_y_v else true_y_h
  err <- mu - true_y
  out <- data.frame(
    n_per = N_PER,
    problem = problem,
    surrogate = surrogate,
    seed = seed,
    rmse_y1 = sqrt(mean(err[, 1]^2)),
    rmse_y2 = sqrt(mean(err[, 2]^2)),
    rmse_agg = sqrt(mean(err^2)),
    n_train = nrow(train),
    stringsAsFactors = FALSE
  )
  cat(sprintf(
    "[done] %s/%s/seed=%03d rmse_agg=%.4f\n",
    problem, surrogate, seed, out$rmse_agg
  ), file = progress_log, append = TRUE)
  out
}

work <- expand.grid(
  problem = problems,
  surrogate = surrogates,
  seed = seq_len(N_REPS),
  stringsAsFactors = FALSE
)
work$priority <- c(ctmgp = 3L, qqmgp = 2L, qqigp = 1L)[work$surrogate]
work <- work[order(-work$priority, work$seed, work$problem), ]
work$priority <- NULL
rownames(work) <- NULL

cat(sprintf(
  "[work] %d fits, n_per=%d, %d workers x %d OMP\n",
  nrow(work), N_PER, n_workers, omp_per_worker
))
cat(sprintf("# started %s total=%d\n", Sys.time(), nrow(work)), file = progress_log)

t0 <- Sys.time()
cl <- makePSOCKcluster(n_workers)
on.exit(stopCluster(cl), add = TRUE)
clusterEvalQ(cl, suppressPackageStartupMessages(library(ctmGP)))
clusterCall(cl, function(omp) {
  Sys.setenv(OMP_NUM_THREADS = as.character(omp),
             OPENBLAS_NUM_THREADS = as.character(omp),
             MKL_NUM_THREADS = as.character(omp),
             VECLIB_MAXIMUM_THREADS = as.character(omp))
}, omp = omp_per_worker)
clusterExport(cl, c(
  "repo_root", "cand_grid", "true_y_v", "true_y_h", "GRID_N", "N_PER",
  "surr_configs", "optim_config", "progress_log", "fit_one", "predict_mu",
  "make_eval_fn", "make_init", "make_surrogate_control"
), envir = environment())
clusterEvalQ(cl, source(file.path(repo_root, "R", "synthetic_bo_config.R")))
clusterEvalQ(cl, source(file.path(repo_root, "R", "synthetic_bo_core.R")))
clusterExport(cl, c(
  "default_optim_config", "default_ctmgp_config", "default_qqigp_config",
  "default_qqmgp_config", "default_sweep_config"
), envir = environment())

res <- do.call(rbind, parLapplyLB(cl, split(work, seq_len(nrow(work))), fit_one))
write.csv(res, out_csv, row.names = FALSE)
cat(sprintf("[done] wrote %s\n", out_csv))

source(file.path(repo_root, "scripts", "plot_emulation_rmse.R"))
cat(sprintf("[done] wrote %s\n", out_fig))
cat(sprintf("# done wall=%.1fs rows=%d\n",
            as.numeric(Sys.time() - t0, units = "secs"), nrow(res)),
    file = progress_log, append = TRUE)
