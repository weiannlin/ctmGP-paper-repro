# ctmGP paper reproduction package

This repository contains the public reproduction material for the synthetic experiments in Lin, Sung, Cheng, and Chen (2026), **Multi-Objective Bayesian Optimization of CPU Cooling Design with Mixed Variables using Category Tree Gaussian Process**.

The repository is intentionally limited to the fixed manuscript version. It is not the development repository for `ctGP` or `ctmGP`.

## Scope

Included:

- Fixed source tarballs for `ctGP` and `ctmGP`, both version `0.1.16.1`.
- Synthetic emulation scripts and the Figure 5 RMSE results for the 20-point-per-category training design.
- Synthetic BO scripts and the complete trace archive used for the manuscript: 24 configurations, 100 replications, and 30 BO iterations.
- The final synthetic figures reported in the manuscript.

Not included:

- Case-study data generated under commercial engineering software confidentiality restrictions.
- Scripts or data for rerunning the licensed engineering case study in Section 5.
- Internal RDS files, package-library caches, and development history.

## Layout

| Path | Contents |
|---|---|
| `packages/` | Fixed `ctGP` and `ctmGP` source tarballs and local installer |
| `R/` | Shared synthetic experiment functions and final paper settings |
| `scripts/` | Synthetic rerun and plotting scripts |
| `data/synthetic_emulation_rmse.csv` | Figure 5 RMSE results |
| `data/synthetic_bo_traces/` | Full synthetic BO per-run CSV traces |
| `data/synthetic_bo_summary.csv` | Per-run synthetic BO summary |
| `data/synthetic_bo_config_summary.csv` | Configuration-level synthetic BO summary |
| `figures/` | Final synthetic figures reproduced by the scripts |

## Installation

From the repository root:

```sh
Rscript scripts/install_dependencies.R
```

This installs the CRAN packages needed by the reproduction scripts and then installs the local `ctGP` and `ctmGP` source tarballs. The reproduction does not require `globpso`.

## Reproduce Figure 5

To regenerate the synthetic emulation/RMSE figure from the included RMSE results:

```sh
Rscript scripts/plot_emulation_rmse.R
```

To rerun the Figure 5 RMSE study from scratch:

```sh
Rscript scripts/run_emulation_rmse.R --n_workers 5 --omp_per_worker 4
```

The script uses the final manuscript setting of 20 LHD training points per categorical level.

## Reproduce Synthetic BO Figures

To regenerate the synthetic IGD+ and HV trajectory figures from the included BO traces:

```sh
Rscript scripts/plot_synthetic_bo.R
```

To regenerate the synthetic acquisition-time figure:

```sh
Rscript scripts/plot_synthetic_timing.R
```

Generated figures are written to `figures/`.

## Rerun Synthetic BO Study

The full synthetic BO sweep can be rerun with:

```sh
Rscript scripts/run_synthetic_bo.R
```

The final manuscript setting uses:

- 5 initial LHD points per categorical level.
- Two test functions: `VLMOP2` and `highcorrVLMOP2`.
- Three surrogates: `QQiGP`, `ctmGP`, and `QQmGP`.
- Two acquisition criteria: EIM and EHVI.
- Two update strategies: single-configuration and categorical-batch.
- 100 replications and 30 BO iterations.

The full rerun is computationally expensive. For ordinary checking, use the included trace archive and plotting scripts.

## Data Availability for Section 5

The data in Section 5 were generated using commercial engineering software under confidentiality and licensing restrictions. Following these restrictions, this public reproduction repository does not include the Section 5 case-study data or scripts for rerunning that case.
