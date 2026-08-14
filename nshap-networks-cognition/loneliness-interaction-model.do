// loneliness-interaction-model.do
//
// Same question as loneliness-stratified-model.do (does baseline
// loneliness modify the network / cognitive-trajectory relationship?) but
// keeping loneliness CONTINUOUS and testing it via interaction in a single
// model -- statistically preferable to a median split (more power, no
// arbitrary cutpoint).
//
//   Loneliness = W1 UCLA 3-item scale (Hughes et al. 2004): companion +
//     leftout + isolated, coded 1-3 (composite 3-9, higher = lonelier).
//     Summed here (no pre-built composite). Baseline (W1) measure.
//
//   *** CROSS-WAVE NOTE: W1 items (1-3) are NOT comparable to W2/W3
//   (companion2 etc., 0-3). Fine here -- baseline measure only. ***
//
// Model: cogz ~ years##alters_base##loneliness + baseline demographics,
//   random intercept + slope. The THREE-WAY years#alters_base#loneliness
//   is the key term: does loneliness change how baseline network size
//   affects the cognitive TRAJECTORY? Requires growth_long.dta.

version 14
capture log close
log using "loneliness-interaction-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline UCLA loneliness composite (continuous)
//------------------------------------------------------------------------
use su_id companion leftout isolated using "$datadir/nshap_w1_core.dta", clear
assert inlist(companion,1,2,3) if !missing(companion)
assert inlist(leftout,1,2,3)   if !missing(leftout)
assert inlist(isolated,1,2,3)  if !missing(isolated)
gen loneliness = companion + leftout + isolated   // missing unless all 3 present
label variable loneliness "W1 UCLA loneliness (sum of 3 items, 3-9)"
summarize loneliness, detail
keep su_id loneliness
tempfile lon
save "`lon'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear
xtset id years
merge m:1 su_id using "`lon'", keep(match master) nogen

//========================================================================
// Model 4 + continuous loneliness, fully interacted with the network-by-
// time term. c.years##c.alters_base##c.loneliness expands to all main
// effects, all two-way interactions, and the three-way. Demographics
// added as main-effect adjustments.
//========================================================================
display as text _newline "=== Model 4 + loneliness x (years x alters_base) ==="
mixed cogz c.years##c.alters_base##c.loneliness ///
    i.gender age_base i.race i.educ ///
    || id: years, cov(unstructured)

// formal moderation test: does loneliness change the network-by-time
// effect on the trajectory?
testparm c.years#c.alters_base#c.loneliness

// visualise: predicted trajectories by baseline network size (1 vs 5),
// at a lower- vs higher-loneliness value (3 = not lonely, 6 = lonelier).
// If the network gap widens differently across the loneliness panels,
// that is the three-way interaction made visible.
margins, at(years=(0 5 10) alters_base=(1 5) loneliness=(3 6))
marginsplot, ///
    title("Cognitive trajectory by network size and loneliness") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline")
graph export "lonely_interaction_margins.png", replace width(1600)

log close
