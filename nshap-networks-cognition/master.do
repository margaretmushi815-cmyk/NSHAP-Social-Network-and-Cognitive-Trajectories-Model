// master.do
//
// Runs the full NSHAP "social networks & cognitive trajectories" pipeline
// in dependency order. Set the two paths below ONCE and run this file;
// every sub-do-file inherits them (each sub-file only sets its own path if
// one isn't already defined, so master's values win).
//
// PIPELINE OVERVIEW (what each step produces / needs):
//   three-wave-overlap        -> three_wave_flags.dta   (analytic sample)
//   participant-flow          exclusion cascade numbers
//   table1                    Table 1 (analytic vs excluded)
//   cognition-network-regr.   cross-sectional per-wave regressions
//   growth-model              -> growth_long.dta        (+ mixed models, plots)
//   network-persistence       -> network_persistence.dta
//   network-composition       composition exposures (loop)
//   covariate-moderator       needs growth_long + network_persistence
//   gender/kin/density/        focused composition & exposure models
//     community/loneliness
//
// NOT run here (by design):
//   moca-sa.do    - helper, called internally by the models
//   alters.do     - reference snippet
//   data-checks.do- ad-hoc scratchpad

version 14
clear all
set more off
capture log close _all        // clear any log stranded by a previous failed run

// ===== SET PATHS ONCE (edit both to your machine) =====
// projdir = folder holding these .do files (i.e. this cloned repo)
global projdir "/path/to/this/repo/nshap-networks-cognition"
// datadir = folder holding the NSHAP .dta files (restricted-access data,
//           obtained separately from NACDA/ICPSR -- see README)
global datadir "/path/to/your/nshap/data"
// codedir = folder holding moca-sa.do (same as projdir here)
global codedir "$projdir"

cd "$projdir"

// ===== FOUNDATION: build the shared analytic dataset =====
do "three-wave-overlap.do"            // -> three_wave_flags.dta

// ===== DESCRIPTIVES =====
do "participant-flow.do"
do "table1.do"

// ===== CROSS-SECTIONAL (per-wave) =====
do "cognition-network-regression.do"

// ===== LONGITUDINAL: build growth_long.dta, then the mixed models =====
do "growth-model.do"                  // -> growth_long.dta

// ===== NETWORK EXPOSURES / MODERATORS (all need growth_long.dta) =====
do "network-persistence.do"           // -> network_persistence.dta (before covariate-moderator)
do "network-composition.do"
do "covariate-moderator.do"           // needs growth_long + network_persistence
do "gender-composition-model.do"
do "kin-composition-model.do"
do "network-density-model.do"
do "density-stratified-model.do"
do "community-involvement-model.do"
do "community-stratified-model.do"
do "loneliness-stratified-model.do"
do "loneliness-interaction-model.do"

display as text _newline "=== master.do complete ==="
