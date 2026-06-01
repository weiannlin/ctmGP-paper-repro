# Default settings for the synthetic BO experiments reported in the manuscript.
# All numeric ranges follow R conventions: lower bound first, upper bound second.

default_optim_config <- list(
  pso_swarm_size = 64L,
  pso_max_iter   = 10L,
  bcd_max_iter   = 3L,
  nugget         = sqrt(.Machine$double.eps),
  ehvi_mc_samples = 5000L
)

default_ctmgp_config <- list(
  fi_lower    = 0,
  fi_upper    = 6,
  theta_lo_pi = 0.2,
  theta_hi_pi = 0.8
)

default_qqigp_config <- list(
  fi_lower    = -6,
  fi_upper    = 6,
  theta_lo_pi = 0,
  theta_hi_pi = 1
)

default_qqmgp_config <- list(
  fi_lower    = -6,
  fi_upper    = 6,
  theta_lo_pi = 0,
  theta_hi_pi = 1
)

default_sweep_config <- list(
  n_reps        = 100L,
  budget        = 30L,
  cont_grid_n   = 40L,
  n_per_init    = 5L,
  n_workers     = 5L,
  omp_per_worker = 4L,
  out_dir       = file.path("outputs", "synthetic_bo_traces"),
  test_fns      = c("VLMOP2", "highcorrVLMOP2"),
  acquisitions  = c("ehvi", "eim"),
  strategies    = c("single_config", "categorical_batch"),
  surrogates    = c("qqigp", "ctmgp", "qqmgp")
)
