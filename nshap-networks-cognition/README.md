# Social networks and cognitive trajectories in older adults (NSHAP)

Stata code to reproduce the analyses of whether baseline social-network
characteristics predict 10-year cognitive trajectories in the National
Social Life, Health and Aging Project (NSHAP), a longitudinal cohort of
community-dwelling older US adults (Waves 1–3; baseline, 5-year, and
10-year follow-ups).

> **This repository contains code only.** The NSHAP data are
> restricted-access and are **not** included here.

## Data access

The analyses use the NSHAP Wave 1, 2, and 3 core and network files. NSHAP
data are distributed through NACDA/ICPSR and are not redistributable, so
they are not in this repo. Obtain them from:

- NACDA / ICPSR (search "NSHAP"): https://www.icpsr.umich.edu/

The code expects these Stata files in a single data folder:

```
nshap_w1_core.dta      nshap_w1_network.dta
nshap_w2_core.dta      nshap_w2_network.dta
nshap_w3_core.dta      nshap_w3_network.dta
```

## Software

- **Stata** (developed/run under StataMP; scripts set `version 14`, so they
  run under Stata 14 or later). No user-written packages are required —
  all commands (`mixed`, `margins`, `marginsplot`, `putexcel`,
  `estat recovariance`, etc.) are built in.

## How to run

1. Clone this repo.
2. Open `master.do` and set the two paths at the top:
   - `projdir` = the folder holding these `.do` files (this repo).
   - `datadir` = the folder holding the six NSHAP `.dta` files.
3. Run `master.do`. It executes every step in dependency order and writes
   the intermediate datasets, logs, figures, and result tables into the
   working directory.

Each `.do` file can also be run standalone (set its `$datadir` at the top);
files that need `growth_long.dta` or `three_wave_flags.dta` require the
upstream steps (see order below) to have been run first.

## File inventory and run order

| Order | File | Produces / role |
|------:|------|-----------------|
| —  | `master.do` | runs the whole pipeline in order; set paths here |
| —  | `moca-sa.do` | MoCA-SA scoring routine (NSHAP algorithm); **called internally** by the models |
| 1  | `three-wave-overlap.do` | builds `three_wave_flags.dta` (defines the 3-wave analytic sample) |
| 2  | `participant-flow.do` | exclusion-cascade counts for the participant-flow diagram |
| 3  | `table1.do` | Table 1 (analytic sample vs. excluded) |
| 4  | `cognition-network-regression.do` | cross-sectional, per-wave regressions |
| 5  | `growth-model.do` | builds `growth_long.dta`; nested growth models; spaghetti + margins plots; exports `growth_final_model.xlsx` |
| 6  | `network-persistence.do` | builds `network_persistence.dta`; tie-persistence models |
| 7  | `network-composition.do` | network-composition exposures |
| 8  | `covariate-moderator.do` | covariate-vs-moderator framework (needs `growth_long` + `network_persistence`) |
| 9  | `gender-composition-model.do` | gender make-up of network |
| 10 | `kin-composition-model.do` | kin/non-kin composition |
| 11 | `network-density-model.do` | network density |
| 12 | `density-stratified-model.do` | growth model stratified by density |
| 13 | `community-involvement-model.do` | community-involvement exposure |
| 14 | `community-stratified-model.do` | growth model stratified by community involvement |
| 15 | `loneliness-stratified-model.do` | growth model stratified by loneliness; 4-sheet Excel export |
| 16 | `loneliness-interaction-model.do` | loneliness × network-size × time interaction |
| —  | `data-checks.do` | ad-hoc scratchpad (not part of the pipeline) |
| —  | `alters.do` | reference snippet (superseded by the reconstruction inside the models) |

## Key methods notes (see each file's header for detail)

- **Analytic sample:** complete-case — respondents with cognition and
  network data in all three waves.
- **Cognition outcome:** SPMSQ (Wave 1) and MoCA-SA (Waves 2–3), two
  different instruments, standardized **within wave** to z-scores to place
  them on a common metric. Consequence: the model describes *relative*
  cognitive standing/change; absolute mean change is not recoverable, and
  the bare `years` effect is ~0 by construction.
- **Network exposures** (size, composition, density, persistence) are
  **baseline (Wave 1)** values, entered with a `× time` interaction to test
  prediction of the cognitive *trajectory*.
- **Models:** linear mixed-effects (growth) models with random intercept
  and random slope for time (unstructured covariance).
- **No imputation** was performed for the analysis variables, except the
  standard MoCA-SA scoring algorithm (`moca-sa.do`), which imputes a few
  hard-to-administer items via logistic regression (reaches the 13-item
  score used here only via the fluency item).
- **Cross-wave coding differences** exist for network size (0–6 in W1 vs
  0–5 in W2/W3) and loneliness (1–3 in W1 vs 0–3 in W2/W3); baseline-only
  exposures are used to avoid these.

## Outputs (generated on run; not tracked in git)

`*.log` (run logs), `*.png` (figures), `*.xlsx` / `*.rtf` (result tables),
and intermediate `*.dta` (`three_wave_flags.dta`, `growth_long.dta`,
`network_persistence.dta`). These are `.gitignore`d.

## Citation / contact

<!-- Add your paper citation, author name, and contact/ORCID here. -->
