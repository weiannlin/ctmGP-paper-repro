# Regenerate the synthetic BO trajectory figures from the included traces.

suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(grid); library(ctmGP)
})

.this <- (function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) return(normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE))
  NULL
})()
WORKSPACE    <- if (!is.null(.this)) normalizePath(file.path(dirname(.this), ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = FALSE)
OUT_PLOT_DIR <- file.path(WORKSPACE, "figures")
dir.create(OUT_PLOT_DIR, recursive = TRUE, showWarnings = FALSE)

source(file.path(WORKSPACE, "R", "synthetic_bo_core.R"))

args <- commandArgs(trailingOnly = TRUE)
target_dir <- if (length(args) >= 1L && nzchar(args[1])) {
  normalizePath(args[1], mustWork = TRUE)
} else {
  file.path(WORKSPACE, "data", "synthetic_bo_traces")
}
cat(sprintf("[plot] dir: %s\n", target_dir))

problems       <- c("VLMOP2", "highcorrVLMOP2")
problem_labels <- c(VLMOP2 = "VLMOP2", highcorrVLMOP2 = "highcorr-VLMOP2")
surrs          <- c("ctmgp", "qqigp", "qqmgp")
surr_labels    <- c(ctmgp = "ctmGP", qqigp = "QQiGP", qqmgp = "QQmGP")
color_mapping  <- c("ctmGP" = "blue", "QQiGP" = "red", "QQmGP" = "orange")

N_PER_INIT <- 5L
GRID_N     <- 40L
REF_MARGIN <- 0.1   # ref = grid worst y + margin (per objective)

# cache eval / true-PF / fixed ref per problem
.eval_cache <- new.env(parent = emptyenv())
.pf_cache   <- new.env(parent = emptyenv())
.ref_cache  <- new.env(parent = emptyenv())
get_eval <- function(p) {
  if (is.null(.eval_cache[[p]])) .eval_cache[[p]] <- make_eval_fn(p)
  .eval_cache[[p]]
}
get_pf <- function(p) {
  if (is.null(.pf_cache[[p]])) .pf_cache[[p]] <- build_paper_pf(p, n_per_dim = GRID_N)
  .pf_cache[[p]]
}
get_ref <- function(p) {
  if (is.null(.ref_cache[[p]])) {
    ev <- get_eval(p)
    u  <- seq(-2, 2, length.out = GRID_N)
    g  <- expand.grid(x1 = u, x2 = u, z = c("c1", "c2"),
                      stringsAsFactors = FALSE)
    Y  <- ev(g)
    .ref_cache[[p]] <- apply(Y, 2, max) + REF_MARGIN
  }
  .ref_cache[[p]]
}

# ---- per-(seed) trajectory: iter 0..N, recomputed PF / IGD+ / HV -----------
# Cumulative observations = init design + all CSV rows with iter <= t.
# IGD+ uses true PF (40-pt grid); HV uses fixed per-problem ref.
seed_trace <- function(problem, surr, acq, strategy, seed) {
  ev    <- get_eval(problem)
  Z_PF  <- get_pf(problem)
  ref_pt<- get_ref(problem)
  init  <- make_init(seed, ev, n_per = N_PER_INIT, grid_n = GRID_N)
  init_y<- as.matrix(init[, c("y1", "y2")])

  fp <- file.path(target_dir,
                  sprintf("%s_%s_%s_%s_seed%02d.csv",
                          problem, surr, acq, strategy, seed))
  d  <- read.csv(fp, stringsAsFactors = FALSE)
  d  <- d[!is.na(d$iter), c("iter", "y1", "y2")]
  max_iter <- max(d$iter)

  iters <- 0L:as.integer(max_iter)
  out <- data.frame(iter = iters,
                    igd_plus_after = NA_real_,
                    hv_after       = NA_real_)
  for (k in seq_along(iters)) {
    it <- iters[k]
    Y  <- if (it == 0L) init_y
          else rbind(init_y, as.matrix(d[d$iter <= it, c("y1", "y2")]))
    pf <- pareto_front(Y)
    out$igd_plus_after[k] <- igd_plus(pf, Z_PF)
    out$hv_after[k]       <- hypervolume(pf, ref_pt)
  }
  out
}

# ---- aggregate trajectories across reps ------------------------------------
collect_band <- function(problem, surr, acq, strategy) {
  pat <- sprintf("^%s_%s_%s_%s_seed[0-9]+\\.csv$",
                  problem, surr, acq, strategy)
  fps <- list.files(target_dir, pattern = pat, full.names = TRUE)
  if (!length(fps)) stop(sprintf("no files for %s/%s/%s/%s", problem, surr, acq, strategy))
  seeds <- as.integer(sub(".*_seed([0-9]+)\\.csv$", "\\1", basename(fps)))

  long <- do.call(rbind, lapply(seeds, function(s)
    seed_trace(problem, surr, acq, strategy, s)))

  agg_q <- function(v) c(mid = median(v, na.rm = TRUE),
                          lo  = quantile(v, 0.025, na.rm = TRUE, names = FALSE),
                          hi  = quantile(v, 0.975, na.rm = TRUE, names = FALSE))
  out <- do.call(rbind, lapply(sort(unique(long$iter)), function(it) {
    sub <- long[long$iter == it, ]
    iv  <- agg_q(sub$igd_plus_after)
    hv  <- agg_q(sub$hv_after)
    data.frame(iteration = it,
                igd_mid = iv[1], igd_lo = iv[2], igd_hi = iv[3],
                hv_mid  = hv[1], hv_lo  = hv[2], hv_hi  = hv[3])
  }))
  out$model <- surr_labels[[surr]]
  out
}

build_long <- function(problem, acq, strategy) {
  do.call(rbind, lapply(surrs, function(s) {
    collect_band(problem, s, acq, strategy)
  }))
}

# ---- panel builder ----------------------------------------------------------
panel_band <- function(df, yvar_mid, yvar_lo, yvar_hi) {
  ggplot(df, aes(x = iteration)) +
    geom_ribbon(aes(ymin = .data[[yvar_lo]], ymax = .data[[yvar_hi]],
                     fill = model), alpha = 0.1) +
    geom_line(aes(y = .data[[yvar_hi]], color = model),
              linetype = "solid", linewidth = 0.5, show.legend = FALSE) +
    geom_line(aes(y = .data[[yvar_lo]], color = model),
              linetype = "solid", linewidth = 0.5, show.legend = FALSE) +
    geom_line(aes(y = .data[[yvar_mid]], color = model),
              linetype = "dashed", linewidth = 0.6) +
    scale_color_manual(values = color_mapping) +
    scale_fill_manual( values = color_mapping) +
    scale_x_continuous(expand = c(0, 0)) +
    labs(x = NULL, y = NULL, color = "Model", fill = "Model") +
    theme_minimal() +
    theme(plot.margin = margin(4, 6, 14, 6))
}

panel_tag <- function(p, tag) {
  p + labs(tag = tag) +
    theme(plot.tag.location = "panel",
          plot.tag.position = c(0.5, -0.20),
          plot.tag = element_text(face = "bold", hjust = 0.5, vjust = 1, size = 12),
          plot.tag.background = element_rect(fill = "white", color = NA))
}

col_strip <- function(label) {
  wrap_elements(full = textGrob(label,
                                 gp = gpar(fontsize = 12, fontface = "bold")))
}
row_strip <- function(label) {
  wrap_elements(full = textGrob(label, rot = 90,
                                 gp = gpar(fontsize = 12, fontface = "bold")))
}

# ---- compose 2x2 figure for a metric x strategy ----------------------------
make_figure <- function(metric, strategy, file_suffix) {
  cat(sprintf("[plot] metric=%s strategy=%s\n", metric, strategy))

  df_v_eim  <- build_long("VLMOP2",         "eim",  strategy)
  df_v_ehvi <- build_long("VLMOP2",         "ehvi", strategy)
  df_h_eim  <- build_long("highcorrVLMOP2", "eim",  strategy)
  df_h_ehvi <- build_long("highcorrVLMOP2", "ehvi", strategy)

  if (metric == "igd") {
    yvars <- c("igd_mid", "igd_lo", "igd_hi"); ylab_text <- "iGD+"
    ylim_v_top <- max(c(df_v_eim$igd_hi, df_v_ehvi$igd_hi), na.rm = TRUE)
    ylim_h_top <- max(c(df_h_eim$igd_hi, df_h_ehvi$igd_hi), na.rm = TRUE)
    ylim_v <- c(0, ylim_v_top * 1.05)
    ylim_h <- c(0, ylim_h_top * 1.05)
  } else {
    yvars <- c("hv_mid", "hv_lo", "hv_hi"); ylab_text <- "HV"
    ylim_v <- range(c(df_v_eim$hv_lo, df_v_eim$hv_hi,
                       df_v_ehvi$hv_lo, df_v_ehvi$hv_hi), na.rm = TRUE)
    ylim_h <- range(c(df_h_eim$hv_lo, df_h_eim$hv_hi,
                       df_h_ehvi$hv_lo, df_h_ehvi$hv_hi), na.rm = TRUE)
    ylim_v <- ylim_v + c(-1, 1) * 0.02 * diff(ylim_v)
    ylim_h <- ylim_h + c(-1, 1) * 0.02 * diff(ylim_h)
  }

  p_a <- panel_band(df_v_eim,  yvars[1], yvars[2], yvars[3]) + ylim(ylim_v)
  p_b <- panel_band(df_h_eim,  yvars[1], yvars[2], yvars[3]) + ylim(ylim_h)
  p_c <- panel_band(df_v_ehvi, yvars[1], yvars[2], yvars[3]) + ylim(ylim_v)
  p_d <- panel_band(df_h_ehvi, yvars[1], yvars[2], yvars[3]) + ylim(ylim_h)

  p_a <- panel_tag(p_a, "(a)")
  p_b <- panel_tag(p_b, "(b)")
  p_c <- panel_tag(p_c, "(c)")
  p_d <- panel_tag(p_d, "(d)")

  # Vertical legend on right
  legend_src <- panel_band(df_v_eim, yvars[1], yvars[2], yvars[3]) +
    theme(legend.position = "right", legend.direction = "vertical",
           legend.key.height = unit(0.55, "cm"))
  glegend     <- ggplotGrob(legend_src)
  glegend     <- glegend$grobs[[which(sapply(glegend$grobs, function(g)
                   inherits(g, "gtable") && grepl("guide-box", g$name)))]]
  legend_wrap <- wrap_elements(full = glegend)

  drop_legend <- theme(legend.position = "none")
  p_a <- p_a + drop_legend; p_b <- p_b + drop_legend
  p_c <- p_c + drop_legend; p_d <- p_d + drop_legend

  ylab       <- wrap_elements(full = textGrob(ylab_text, rot = 90,
                                                gp = gpar(fontsize = 12, fontface = "bold")))
  xlab_iter  <- col_strip("Iteration")
  strip_v    <- col_strip(problem_labels[["VLMOP2"]])
  strip_h    <- col_strip(problem_labels[["highcorrVLMOP2"]])
  strip_eim  <- row_strip("EIM")
  strip_ehvi <- row_strip("EHVI")

  sp <- plot_spacer()

  # Layout: 5 rows x 5 cols
  # cols: [1 ylab] [2 rowstrip] [3 VLMOP2] [4 highcorr-VLMOP2] [5 legend]
  # rows: [1 colstrips] [2 EIM] [3 gap] [4 EHVI] [5 xlab spans cols 3-4]
  design <- c(
    area(1, 3, 1, 3), area(1, 4, 1, 4),
    area(2, 1, 4, 1),
    area(2, 2, 2, 2), area(2, 3, 2, 3), area(2, 4, 2, 4),
    area(3, 2, 3, 4),
    area(4, 2, 4, 2), area(4, 3, 4, 3), area(4, 4, 4, 4),
    area(2, 5, 4, 5),
    area(5, 1, 5, 2), area(5, 3, 5, 4)
  )

  combined <- wrap_plots(
    strip_v, strip_h,
    ylab,
    strip_eim, p_a, p_b,
    sp,
    strip_ehvi, p_c, p_d,
    legend_wrap,
    sp, xlab_iter,
    design = design
  ) +
    plot_layout(widths  = c(0.06, 0.16, 1, 1, 0.22),
                 heights = c(0.12, 1, 0.10, 1, 0.20))

  name <- switch(
    paste(metric, file_suffix, sep = "_"),
    igd_single = "figure6_igd_single_configuration.pdf",
    igd_addall = "figure7_igd_categorical_batch.pdf",
    hv_single = "figure8_hv_single_configuration.pdf",
    hv_addall = "figure9_hv_categorical_batch.pdf"
  )
  out_pdf <- file.path(OUT_PLOT_DIR, name)
  ggsave(out_pdf, combined, width = 10, height = 4.5, device = cairo_pdf)
  cat(sprintf("[plot] wrote %s\n", out_pdf))
  invisible(combined)
}

for (strategy in c("single_config", "categorical_batch")) {
  suffix <- if (strategy == "single_config") "single" else "addall"
  make_figure("igd", strategy, suffix)
  make_figure("hv",  strategy, suffix)
}
cat("\n[done]\n")
