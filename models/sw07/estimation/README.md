# Estimation provenance (not re-run here)

The parameters in `../sw07_params.m` are the posterior mode of Dynare run **swX1**,
estimated on 2026-09-29 in `Desktop/ucur-dsge/sw07-extended` (working folder
`C:\dynare_work\sw_ext`) with **Dynare 4.6.1**. Nothing in this package re-estimates.

| setting | value |
|---|---|
| data | `sw_ext_1966_latest.csv` (= `../data/sw_ext_1966_latest.csv`), 1965Q1-2026Q2 |
| `first_obs`, `presample` | 1, 4 (likelihood sample 1966Q1-2026Q2, 242 quarters) |
| `lik_init` | 2 |
| `prefilter` | 0 |
| `mode_compute` | 4 (csminwel), started from `swR_mode` |
| `mh_replic` | 0 (mode and Hessian only, `cova_compute=1`) |
| log posterior at the mode | -1578.2488 |
| Laplace log data density | -1668.8829 |

Files (copies, do not edit):

| file | what |
|---|---|
| `swX1.mod` | equations, priors, estimation command |
| `swX1_mode.mat` | `xparam1`, `parameter_names`, `hh`, `fval` |
| `swX1.log` | Dynare console log |
| `mode_original_vs_extended.csv` | published SW07 vs replication (1966-2004) vs this mode (`ext_mode_1966_2026`) |
| `FINDINGS_estimates.md` | what moved between samples and why (ZLB, Covid, `constelab`) |

`sw07_params.m` was generated from `swX1_mode.mat` by name; it agrees with the
`ext_mode_1966_2026` column to 4.2e-15.
