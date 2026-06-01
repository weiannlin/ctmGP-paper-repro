# Regenerate the synthetic acquisition timing figure from the included traces.

suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(grid)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

.this <- (function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) return(normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE))
  NULL
})()
WORKSPACE    <- if (!is.null(.this)) normalizePath(file.path(dirname(.this), ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = FALSE)
OUT_PLOT_DIR <- file.path(WORKSPACE, "figures")
dir.create(OUT_PLOT_DIR, recursive = TRUE, showWarnings = FALSE)

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
acqs           <- c("eim", "ehvi")
acq_labels     <- c(eim = "EIM", ehvi = "EHVI")
stages         <- c("acq_wall_sec")
stage_labels   <- c(acq_wall_sec = "acq")

# ---- per-cell timing: median over seeds of mean-per-iter -------------------
collect_timing <- function(problem, surr, acq) {
  pat <- sprintf("^%s_%s_%s_single_config_seed[0-9]+\\.csv$",
                 problem, surr, acq)
  fps <- list.files(target_dir, pattern = pat, full.names = TRUE)
  if (!length(fps)) stop(sprintf("no files: %s/%s/%s", problem, surr, acq))
  per_seed_list <- lapply(fps, function(fp) {
    d <- read.csv(fp, stringsAsFactors = FALSE)
    d <- d[!is.na(d$iter), ]
    setNames(vapply(stages, function(s) mean(d[[s]], na.rm = TRUE),
                    numeric(1)), stages)
  })
  per_seed <- do.call(rbind, per_seed_list)
  apply(per_seed, 2, median)
}

# ---- assemble long dataframe -----------------------------------------------
rows <- list()
for (p in problems) for (s in surrs) for (a in acqs) {
  v <- collect_timing(p, s, a)
  for (st in stages) {
    rows[[length(rows) + 1L]] <- data.frame(
      problem    = problem_labels[[p]],
      surrogate  = surr_labels[[s]],
      acq        = acq_labels[[a]],
      stage      = stage_labels[[st]],
      wall_sec   = unname(v[[st]]),
      stringsAsFactors = FALSE
    )
  }
}
df <- do.call(rbind, rows)
df$surrogate <- factor(df$surrogate, levels = c("ctmGP", "QQiGP", "QQmGP"))
df$acq       <- factor(df$acq,       levels = c("EIM", "EHVI"))
df$problem   <- factor(df$problem,
                       levels = c("VLMOP2", "highcorr-VLMOP2"))

problem_colors <- c("VLMOP2" = "#3E7CB1", "highcorr-VLMOP2" = "#E89A6B")

panel_for <- function(acq_name, tag) {
  d <- df[df$acq == acq_name, ]
  ggplot(d, aes(x = surrogate, y = wall_sec, fill = problem)) +
    geom_col(position = position_dodge(width = 0.75), width = 0.6) +
    geom_text(aes(label = sprintf("%.3f", wall_sec)),
              position = position_dodge(width = 0.75),
              vjust = -0.3, size = 3) +
    scale_fill_manual(name = "Problem", values = problem_colors) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(x = NULL, y = NULL, title = acq_name, tag = tag) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.minor   = element_blank(),
          plot.title         = element_text(face = "bold", hjust = 0.5),
          plot.tag.location  = "panel",
          plot.tag.position  = c(0.5, -0.10),
          plot.tag           = element_text(face = "bold", hjust = 0.5,
                                            vjust = 1, size = 12),
          plot.tag.background= element_rect(fill = "white", color = NA),
          plot.margin        = margin(6, 16, 50, 16))
}

p_eim  <- panel_for("EIM",  "(a)")
p_ehvi <- panel_for("EHVI", "(b)")

ylab_grob <- wrap_elements(full = textGrob("Acquisition wall time per iteration (s)",
                                            rot = 90,
                                            gp = gpar(fontsize = 12, fontface = "bold")))
gap <- plot_spacer()

p_main <- ylab_grob + p_eim + gap + p_ehvi +
  plot_layout(widths = c(0.06, 1, 0.10, 1), nrow = 1, guides = "collect") &
  theme(legend.position = "right")

out_pdf <- file.path(OUT_PLOT_DIR, "figure10_acquisition_timing.pdf")
ggsave(out_pdf, p_main, width = 9, height = 4.4, device = cairo_pdf)
cat(sprintf("[plot] wrote %s\n", out_pdf))

cat("\n[summary] median acq sec/iter by (problem, acq, surrogate):\n")
print(df[order(df$problem, df$acq, df$surrogate),
         c("problem", "acq", "surrogate", "wall_sec")], row.names = FALSE)
cat("\n[done]\n")
