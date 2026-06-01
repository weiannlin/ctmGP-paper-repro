# Core functions for the synthetic BO experiments reported in the manuscript.

suppressPackageStartupMessages({ library(ctmGP); library(parallel) })

# ---- objective functions ----------------------------------------------------

make_eval_fn <- function(test_fn = c("VLMOP2", "highcorrVLMOP2")) {
  test_fn <- match.arg(test_fn)
  if (test_fn == "VLMOP2") {
    function(df) {
      x1 <- df$x1; x2 <- df$x2; z <- as.character(df$z)
      sm <- (x1 - 1/sqrt(2))^2 + (x2 - 1/sqrt(2))^2
      sp <- (x1 + 1/sqrt(2))^2 + (x2 + 1/sqrt(2))^2
      cbind(y1 = ifelse(z == "c1", 1.00 - exp(-sm), 1.25 - exp(-sm)),
            y2 = ifelse(z == "c1", 1.00 - exp(-sp), 0.75 - exp(-sp)))
    }
  } else {
    function(df) {
      x1 <- df$x1; x2 <- df$x2; z <- as.character(df$z)
      sm <- (x1 - 1/sqrt(2))^2 + (x2 - 1/sqrt(2))^2
      sp <- (x1 + 1/sqrt(2))^2 + (x2 + 1/sqrt(2))^2
      cbind(y1 = ifelse(z == "c1", 1.00 - exp(-0.8*sm), 1.00 - exp(-0.5*sp)),
            y2 = ifelse(z == "c1", 1.25 - exp(-0.4*sm), 0.75 - exp(-0.7*sp)))
    }
  }
}

# ---- initial design ---------------------------------------------------------

make_init <- function(seed, ev, n_per = 5L, grid_n = 40L) {
  set.seed(seed)
  X <- lhs::maximinLHS(n_per, 2L)
  X[, 1L] <- X[, 1L] * 4 - 2
  X[, 2L] <- X[, 2L] * 4 - 2
  grid_axis <- seq(-2, 2, length.out = grid_n)
  snap <- function(v) grid_axis[apply(abs(outer(v, grid_axis, "-")), 1L, which.min)]
  X[, 1L] <- snap(X[, 1L])
  X[, 2L] <- snap(X[, 2L])
  X <- unique(X)
  df <- data.frame(x1 = rep(X[, 1L], 2L),
                   x2 = rep(X[, 2L], 2L),
                   z  = rep(c("c1", "c2"), each = nrow(X)),
                   stringsAsFactors = FALSE)
  Y <- ev(df)
  cbind(df, y1 = Y[, "y1"], y2 = Y[, "y2"])
}

# ---- IGD+ reference set -----------------------------------------------------

build_paper_pf <- function(test_fn, n_per_dim = 40L) {
  ev <- make_eval_fn(test_fn)
  u  <- seq(-2, 2, length.out = n_per_dim)
  g  <- expand.grid(x1 = u, x2 = u, z = c("c1", "c2"),
                    stringsAsFactors = FALSE)
  pareto_front(ev(g))
}

# ---- surrogate controls -----------------------------------------------------

make_surrogate_control <- function(surrogate, surr_config, optim_config, seed) {
  fi_rng <- c(surr_config$fi_lower, surr_config$fi_lower,
              surr_config$fi_upper, surr_config$fi_upper)
  theta_lo <- max(surr_config$theta_lo_pi * pi, 1e-6)
  theta_hi <- surr_config$theta_hi_pi  * pi - 1e-6
  theta_rng <- c(theta_lo, theta_hi)

  oc <- list(swarm_size = optim_config$pso_swarm_size,
             max_iter   = optim_config$pso_max_iter,
             seed       = as.integer(seed))

  if (surrogate == "ctmgp") {
    list(global_range      = fi_rng,
         pure_range        = fi_rng,
         mixed_fi_range    = fi_rng,
         mixed_theta_range = theta_rng,
         nugget            = optim_config$nugget,
         optimizer_control = oc,
         bcd_control       = list(max_iter = optim_config$bcd_max_iter),
         verbose           = FALSE,
         progress_mode     = "none")
  } else {
    list(fi_range          = fi_rng,
         theta_range       = theta_rng,
         nugget            = optim_config$nugget,
         optimizer_control = oc)
  }
}

# ---- one BO run, writes CSV + returns 1-row summary ------------------------

run_single_bo <- function(args, ctx) {
  tryCatch({
    test_fn   <- args$test_fn
    surrogate <- args$surrogate
    acq_v     <- args$acq
    strat_v   <- args$strategy
    seed      <- args$seed

    ev   <- ctx$evals[[test_fn]]
    Z_PF <- ctx$pfs  [[test_fn]]
    surr_config <- ctx$surr_configs[[surrogate]]
    sc   <- make_surrogate_control(surrogate, surr_config, ctx$optim_config, seed)

    csv_path <- file.path(ctx$out_dir,
      sprintf("%s_%s_%s_%s_seed%02d.csv",
              test_fn, surrogate, acq_v, strat_v, seed))
    t0 <- Sys.time()
    res <- bo_loop(
      objective_fn = ev,
      init_data    = make_init(seed, ev,
                               n_per  = ctx$sweep_config$n_per_init,
                               grid_n = ctx$sweep_config$cont_grid_n),
      x_cols       = c("x1", "x2"),
      w_cols       = "z",
      y_cols       = c("y1", "y2"),
      x_bounds     = list(x1 = c(-2, 2), x2 = c(-2, 2)),
      w_levels     = list(z = c("c1", "c2")),
      surrogate    = surrogate,
      acquisition  = acq_v,
      strategy     = strat_v,
      budget       = ctx$sweep_config$budget,
      cont_grid_n  = ctx$sweep_config$cont_grid_n,
      surrogate_control = sc,
      ehvi_control = list(mc_samples = ctx$optim_config$ehvi_mc_samples,
                          seed       = seed),
      true_pf      = Z_PF,
      output_csv   = csv_path,
      verbose      = FALSE,
      seed         = seed
    )
    dt  <- as.numeric(Sys.time() - t0, units = "secs")
    igd <- tail(res$history$igd_plus_after, 1L)
    hv  <- tail(res$history$hv_after,        1L)
    data.frame(test_fn = test_fn, surrogate = surrogate,
               acq = acq_v, strategy = strat_v, seed = seed,
               igd_last = igd, hv_last = hv, dt = dt, err = "",
               stringsAsFactors = FALSE)
  }, error = function(e) data.frame(
    test_fn = args$test_fn, surrogate = args$surrogate,
    acq = args$acq, strategy = args$strategy, seed = args$seed,
    igd_last = NA_real_, hv_last = NA_real_, dt = NA_real_,
    err = conditionMessage(e), stringsAsFactors = FALSE))
}

# ---- top-level sweep dispatcher --------------------------------------------

run_synthetic_bo <- function(sweep_config = default_sweep_config,
                            ctmgp_config = default_ctmgp_config,
                            qqigp_config = default_qqigp_config,
                            qqmgp_config = default_qqmgp_config,
                            optim_config = default_optim_config,
                            overwrite    = FALSE) {
  surr_configs <- list(ctmgp = ctmgp_config,
                       qqigp = qqigp_config,
                       qqmgp = qqmgp_config)

  out_dir <- sweep_config$out_dir
  if (dir.exists(out_dir) && !overwrite) {
    stop(sprintf("Output directory already exists: %s", out_dir))
  }
  if (dir.exists(out_dir)) {
    unlink(out_dir, recursive = TRUE)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  cat("=== synthetic BO sweep ===\n")
  cat(sprintf("  out_dir   : %s\n", out_dir))
  cat(sprintf("  init      : %d LHS pts/cat, snapped to %d-pt grid (init = candidate set)\n",
              sweep_config$n_per_init, sweep_config$cont_grid_n))
  cat(sprintf("  test_fns  : %s\n", paste(sweep_config$test_fns, collapse = ", ")))
  cat(sprintf("  surrogates: %s\n", paste(sweep_config$surrogates, collapse = ", ")))
  cat(sprintf("  cells     : %d acq x %d strat x %d surr x %d test_fn = %d\n",
              length(sweep_config$acquisitions),
              length(sweep_config$strategies),
              length(sweep_config$surrogates),
              length(sweep_config$test_fns),
              length(sweep_config$acquisitions) *
              length(sweep_config$strategies)   *
              length(sweep_config$surrogates)   *
              length(sweep_config$test_fns)))
  cat(sprintf("  reps      : %d  ->  total runs = %d\n",
              sweep_config$n_reps,
              length(sweep_config$acquisitions) *
              length(sweep_config$strategies)   *
              length(sweep_config$surrogates)   *
              length(sweep_config$test_fns)     *
              sweep_config$n_reps))
  cat(sprintf("  parallel  : %d workers x %d OMP\n",
              sweep_config$n_workers, sweep_config$omp_per_worker))
  cat(sprintf("  Per-surrogate hyper:\n"))
  for (s in names(surr_configs)) {
    cc <- surr_configs[[s]]
    cat(sprintf("    %-6s  fi=[%g,%g]  theta=(%g*pi, %g*pi)\n",
                s, cc$fi_lower, cc$fi_upper, cc$theta_lo_pi, cc$theta_hi_pi))
  }
  cat("\n")

  # Pre-build per-test_fn evaluators + reference Z's
  evals <- setNames(lapply(sweep_config$test_fns, make_eval_fn),
                    sweep_config$test_fns)
  pfs   <- setNames(lapply(sweep_config$test_fns, function(t)
                           build_paper_pf(t, n_per_dim = sweep_config$cont_grid_n)),
                    sweep_config$test_fns)
  for (t in sweep_config$test_fns)
    cat(sprintf("  Z (%s, %d-pt grid PF): %d pts\n",
                t, sweep_config$cont_grid_n, nrow(pfs[[t]])))
  cat("\n")

  # Build work list (test_fn x surrogate x acq x strategy x seed)
  work <- expand.grid(
    test_fn   = sweep_config$test_fns,
    surrogate = sweep_config$surrogates,
    acq       = sweep_config$acquisitions,
    strategy  = sweep_config$strategies,
    seed      = seq_len(sweep_config$n_reps),
    stringsAsFactors = FALSE
  )

  # Dispatch order: rounds by seed, with larger computational jobs first
  # within each seed.
  cost <- function(s, a, st) {
    surr_w <- switch(s, ctmgp = 30, qqmgp = 50, qqigp = 1)
    acq_w  <- if (a == "ehvi") 4 else 1
    strat_w <- if (st == "categorical_batch") 3 else 1
    surr_w * acq_w * strat_w
  }
  work$priority <- mapply(cost, work$surrogate, work$acq, work$strategy)
  work <- work[order(work$seed, -work$priority), ]
  rownames(work) <- NULL
  work$priority <- NULL

  cat(sprintf("Total work items: %d\n", nrow(work)))

  # Worker context (passed to each parLapply task)
  ctx <- list(out_dir      = out_dir,
              evals        = evals,
              pfs          = pfs,
              surr_configs = surr_configs,
              optim_config = optim_config,
              sweep_config = sweep_config)

  # PSOCK cluster (cross-platform, beats Unix-only mclapply)
  cl <- parallel::makePSOCKcluster(sweep_config$n_workers)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterExport(cl, varlist = c("run_single_bo",
                                           "make_init",
                                           "make_surrogate_control"),
                           envir = environment())
  invisible(parallel::clusterEvalQ(cl, {
    suppressPackageStartupMessages(library(ctmGP))
    NULL
  }))
  # Set BLAS thread pin per worker
  parallel::clusterCall(cl, function(omp) {
    Sys.setenv(OMP_NUM_THREADS        = as.character(omp),
               OPENBLAS_NUM_THREADS   = as.character(omp),
               MKL_NUM_THREADS        = as.character(omp),
               VECLIB_MAXIMUM_THREADS = as.character(omp))
  }, omp = sweep_config$omp_per_worker)

  args_list <- lapply(seq_len(nrow(work)), function(i) as.list(work[i, ]))

  t_start <- Sys.time()
  results <- parallel::parLapplyLB(cl, args_list, run_single_bo, ctx = ctx)
  parallel::stopCluster(cl)
  df <- do.call(rbind, results)
  t_total <- as.numeric(Sys.time() - t_start, units = "secs")

  # Save aggregate summary
  summary_csv <- file.path(out_dir, "summary.csv")
  write.csv(df, summary_csv, row.names = FALSE)

  cat(sprintf("\n[synthetic_bo] DONE  wall=%.1fs (%.1f h)\n",
              t_total, t_total / 3600))
  cat(sprintf("                    summary -> %s\n", summary_csv))
  cat(sprintf("                    per-run CSVs -> %s\n", out_dir))

  invisible(list(out_dir = out_dir, summary = df, wall_sec = t_total))
}
