# ctmGP paper reproduction package

This repository contains the public reproduction material for Lin, Sung, Cheng, and Chen (2026), **Multi-Objective Bayesian Optimization of CPU Cooling Design with Mixed Variables Using a Category Tree Multivariate Gaussian Process**.

The repository covers only the fixed manuscript version. It is not the development repository for `ctGP` or `ctmGP`.

Repository: <https://github.com/weiannlin/ctmGP-repro>

A reproducibility statement is provided in [`docs/ctmGP_reproducibility_statement.pdf`](docs/ctmGP_reproducibility_statement.pdf).

## Scope

The synthetic studies of the manuscript are reported in its Supplementary Material (Section S1, Figures S3-S5). This repository provides the source code and data for those studies.

Included:

- Fixed source tarballs for `ctGP` and `ctmGP`, both version `0.1.16.1`.
- Synthetic emulation scripts and the RMSE results of Figure S3 for the 20-point-per-category training design.
- Synthetic BO scripts and the complete trace archive behind Figures S4 and S5: 24 configurations, 100 replications, and 30 BO iterations.
- The synthetic figures of the Supplementary Material, reproduced by the scripts.

Not included:

- The CPU cooling case studies of Section 4 of the manuscript. Their data were generated using commercial engineering software under confidentiality and licensing restrictions, so neither the data nor the scripts of the two case studies are redistributed.
- Internal RDS files, package-library caches, and development history.

## Layout

| Path | Contents |
|---|---|
| `packages/` | Fixed `ctGP` and `ctmGP` source tarballs and local installer |
| `R/` | Shared synthetic experiment functions and final paper settings |
| `scripts/` | Synthetic rerun and plotting scripts |
| `data/synthetic_emulation_rmse.csv` | Figure S3 RMSE results |
| `data/synthetic_bo_traces/` | Full synthetic BO per-run CSV traces |
| `data/synthetic_bo_summary.csv` | Per-run synthetic BO summary |
| `data/synthetic_bo_config_summary.csv` | Configuration-level synthetic BO summary |
| `figures/` | Synthetic figures of the Supplementary Material (Figures S3-S5) reproduced by the scripts |
| `docs/` | Reproducibility statement in LaTeX and PDF formats |

## Requirements

- R and a platform-appropriate C/C++ toolchain for installing source packages. On Windows, this normally means Rtools.
- Internet access during installation for the CRAN dependencies `Rcpp`, `RcppArmadillo`, `ggplot2`, `patchwork`, and `lhs`.
- The fixed `ctGP` and `ctmGP` source tarballs included under `packages/`.

Python and `globpso` are not required.

## Installation

From the repository root:

```sh
Rscript scripts/install_dependencies.R
```

This installs the CRAN packages needed by the reproduction scripts and then installs the local `ctGP` and `ctmGP` source tarballs. The reproduction does not require `globpso`.

## Quick Verification from Included Results

After installation, the following commands regenerate the synthetic figures of the Supplementary Material (Figures S3-S5) from the included results, without rerunning the simulation studies:

```sh
Rscript scripts/plot_emulation_rmse.R
Rscript scripts/plot_synthetic_bo.R
```

The expected outputs are:

| Script | Output |
|---|---|
| `plot_emulation_rmse.R` | `figures/figureS3_emulation_rmse.pdf` (Figure S3) |
| `plot_synthetic_bo.R` | `figures/figureS4_igd_single_configuration.pdf` (Figure S4) and `figures/figureS5_igd_categorical_batch.pdf` (Figure S5) |

`plot_synthetic_timing.R` separately generates `figures/supplementary_synthetic_acquisition_timing.pdf`, an additional timing diagnostic of the synthetic BO runs that does not appear in the manuscript or its Supplementary Material.

## Reproduce Figure S3

To regenerate the synthetic emulation RMSE figure from the included RMSE results:

```sh
Rscript scripts/plot_emulation_rmse.R
```

To rerun the Figure S3 RMSE study from scratch:

```sh
Rscript scripts/run_emulation_rmse.R --n_workers 5 --omp_per_worker 4
```

The script uses the final manuscript setting of 20 LHD training points per categorical level and 100 replications.

## Reproduce Figures S4 and S5

To regenerate the synthetic IGD+ trajectory figures from the included BO traces:

```sh
Rscript scripts/plot_synthetic_bo.R
```

To regenerate the additional synthetic acquisition-time diagnostic:

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

## Data Availability for Section 4

The case-study data in Section 4 of the manuscript were generated using commercial engineering software under confidentiality and licensing restrictions. Following these restrictions, this public reproduction repository does not include the data or scripts of the two case studies.

## Reproduction Boundaries

- Figures S3-S5 can be regenerated from the included synthetic RMSE results and trace archive.
- The synthetic emulation and BO studies can be rerun from scratch with the included scripts and package tarballs.
- Recreating the case-study response data or rerunning the licensed engineering simulations is outside the public package. No case-study data, geometry, or simulation input is included.

## Citation and Contact

When using these materials, cite the accompanying manuscript under the title given above. The redistribution terms are given in [`LICENSE`](LICENSE). Questions about the reproduction package may be submitted through the repository's GitHub issue tracker.
