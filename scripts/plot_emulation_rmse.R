# Regenerate Figure 5 from the included synthetic emulation RMSE results.

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(grid)
})

script_path <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  i <- grep("^--file=", ca)
  if (length(i)) normalizePath(sub("^--file=", "", ca[i[1]]), mustWork = TRUE) else NULL
}

this <- script_path()
repo_root <- if (!is.null(this)) {
  normalizePath(file.path(dirname(this), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

csv_path <- file.path(repo_root, "data", "synthetic_emulation_rmse.csv")
out_pdf <- file.path(repo_root, "figures", "figure5_emulation_rmse.pdf")
dir.create(dirname(out_pdf), recursive = TRUE, showWarnings = FALSE)

res <- read.csv(csv_path, stringsAsFactors = FALSE)
res <- res[res$n_per == 20L, ]
if (!nrow(res)) {
  stop("No n_per=20 rows found in ", csv_path)
}

surr_levels <- c("ctmGP", "QQiGP", "QQmGP")
surr_map <- c(ctmgp = "ctmGP", qqigp = "QQiGP", qqmgp = "QQmGP")
problem_map <- c(VLMOP2 = "VLMOP2", highcorrVLMOP2 = "highcorr-VLMOP2")
model_colors <- c("ctmGP" = "blue", "QQiGP" = "red", "QQmGP" = "orange")

res$surrogate <- factor(surr_map[res$surrogate], levels = surr_levels)
res$problem <- factor(
  problem_map[res$problem],
  levels = c("VLMOP2", "highcorr-VLMOP2")
)

panel_for <- function(data, problem_name, tag) {
  sub <- data[data$problem == problem_name, ]
  ggplot(sub, aes(x = surrogate, y = rmse_agg, fill = surrogate)) +
    geom_boxplot(width = 0.55, alpha = 0.45, outlier.size = 0.7) +
    scale_fill_manual(name = "Model", values = model_colors) +
    scale_y_log10() +
    labs(x = NULL, y = NULL, title = problem_name, tag = tag) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.tag.location = "panel",
      plot.tag.position = c(0.5, -0.10),
      plot.tag = element_text(face = "bold", hjust = 0.5, vjust = 1, size = 12),
      plot.tag.background = element_rect(fill = "white", color = NA),
      plot.margin = margin(6, 16, 50, 16)
    )
}

ylab <- wrap_elements(full = textGrob(
  "RMSE on candidate grid (log scale)",
  rot = 90,
  gp = gpar(fontsize = 12, fontface = "bold")
))

combined <- ylab +
  panel_for(res, "VLMOP2", "(a)") +
  plot_spacer() +
  panel_for(res, "highcorr-VLMOP2", "(b)") +
  plot_layout(widths = c(0.06, 1, 0.10, 1), nrow = 1, guides = "collect") &
  theme(legend.position = "right")

ggsave(out_pdf, combined, width = 9, height = 4.4, device = cairo_pdf)
cat(sprintf("[plot] wrote %s\n", out_pdf))
