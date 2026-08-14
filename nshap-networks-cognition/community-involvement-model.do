// community-involvement-model.do
//
// Linear mixed (growth) model: does more COMMUNITY INVOLVEMENT at baseline
// predict the cognitive trajectory over the three NSHAP waves?
//
//   Exposure: comminv = baseline (W1) community-involvement scale, built
//     from the frequency in the past 12 months of three activities
//     (Kotwal et al., JGIM; Cronbach's alpha ~= 0.71):
//       1) attending religious services   -> atndserv  (0-6)
//       2) attending organized-group /
//          community meetings             -> attend    (0-6)
//       3) volunteering                   -> volunteer (0-6)
//     Each item runs 0 (never) .. 6 (several times a week); the three are
//     SUMMED into a 0-18 scale (0 = no participation, 18 = frequent
//     participation in all three). Baseline, time-invariant.
//
//     *** MISSINGNESS NOTE: `attend` and `volunteer` come from the W1
//     leave-behind questionnaire (~551/3005 not returned), so the scale is
//     missing for anyone who skipped the leave-behind; `atndserv` is from
//     the main interview. comminv is missing unless ALL THREE items are
//     present, so leave-behind non-returners drop from these models. ***
//
//   Outcome:  cogz (within-wave z-scored cognition) over years (0/5/10).
//
// Standardization caveat carries over from growth-model.do: cogz is
// within-wave z-scored, so the comminv terms ARE interpretable (relative
// cognitive standing / within-person change), but the bare `years` effect
// is ~0 by construction and is NOT average cognitive change.
//
// Requires growth_long.dta (from growth-model.do). Run that first.

version 14
capture log close
log using "community-involvement-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline community-involvement scale (comminv, 0-18)
//------------------------------------------------------------------------
use su_id atndserv attend volunteer using "$datadir/nshap_w1_core.dta", clear

// each item is a 0-6 frequency; verify before summing
foreach v of varlist atndserv attend volunteer {
    assert inrange(`v', 0, 6) if !missing(`v')
}

// internal consistency of the 3-item scale (literature reports alpha ~0.71)
alpha atndserv attend volunteer

// SUM to the 0-18 scale. missing unless all three items are present, so
// leave-behind non-returners (missing attend/volunteer) are excluded.
gen comminv = atndserv + attend + volunteer
label variable comminv "W1 community involvement (0-18: relig services + group meetings + volunteering)"
summarize comminv, detail

keep su_id comminv
tempfile ci
save "`ci'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear    // cogz years id alters_base age_base gender race educ
xtset id years
merge m:1 su_id using "`ci'", keep(match master) nogen

//========================================================================
// Model A (unadjusted): cognition trajectory ~ baseline community involvement
//   c.years##c.comminv expands to three fixed effects:
//     years          -- time slope when comminv = 0
//     comminv        -- association of baseline community involvement with
//                       cognitive STANDING at baseline (years = 0)
//     years#comminv  -- the KEY TERM: does more baseline community
//                       involvement predict the cognitive TRAJECTORY (do
//                       more-involved people change differently over time)?
//   Random intercept + random slope of time, unstructured covariance.
//========================================================================
display as text _newline "=== Model A: cogz ~ years x comminv (unadjusted) ==="
mixed cogz c.years##c.comminv || id: years, cov(unstructured)

// predicted trajectories at low / moderate / high involvement. The 0-18
// tails are sparse, so 3/9/15 are used as representative values (edit to
// taste, e.g. 0 9 18 for the full documented range).
margins, at(years=(0 5 10) comminv=(3 9 15))
marginsplot, ///
    title("Cognitive trajectory by baseline community involvement") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Community involvement (0-18)"))
graph export "comminv_margins.png", replace width(1600)

//========================================================================
// Model B (adjusted): + baseline demographics (age, sex, race, education)
//   Same set as growth-model.do Model 4. Entered as MAIN effects: they
//   adjust the cognitive level/standing, so this controls the comminv MAIN
//   effect for demographic confounding.
//   NOTE: to also protect the comminv#years INTERACTION (the trajectory
//   term of interest) from demographic confounding, the covariates would
//   need #years terms (e.g. c.years##c.age_base) -- say the word and I'll
//   add them. Baseline network SIZE (alters_base) is also available in
//   growth_long if you want community involvement NET of network size.
//========================================================================
display as text _newline "=== Model B: + baseline demographics ==="
mixed cogz c.years##c.comminv age_base i.gender i.race i.educ ///
    || id: years, cov(unstructured)

// adjusted predicted trajectories (demographics averaged over the sample)
margins, at(years=(0 5 10) comminv=(3 9 15))
marginsplot, ///
    title("Cognitive trajectory by baseline community involvement") ///
    note("Adjusted for baseline age, sex, race, education") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Community involvement (0-18)"))
graph export "comminv_margins_adj.png", replace width(1600)

log close
