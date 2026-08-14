// gender-composition-model.do
//
// Linear mixed (growth) model: does the GENDER MAKE-UP of a respondent's
// baseline confidant network predict their cognitive trajectory?
//
//   Exposure: prop_female = proportion of W1 section-A confidants who are
//     female (0-1). Baseline, time-invariant. (Same measure as in
//     network-composition.do; built here directly so this file is
//     self-contained.)
//   Outcome:  cogz (within-wave z-scored cognition) over years (0/5/10).
//
// Standardization caveat carries over: cogz is within-wave z-scored, so
// the prop_female terms are interpretable (relative standing) but the bare
// years effect is ~0 by construction.
//
// Requires growth_long.dta (from growth-model.do). Run that first.

version 14
capture log close
log using "gender-composition-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline gender make-up (prop_female) from the W1 roster
//------------------------------------------------------------------------
use su_id lineno node_gender using "$datadir/nshap_w1_network.dta", clear
keep if inrange(lineno, 1, 5)             // section-A confidants (match alters_base)
assert inlist(node_gender, 1, 2)          // 1=male, 2=female, no missing
gen byte female = (node_gender==2)
collapse (mean) prop_female=female, by(su_id)
label variable prop_female "Baseline network: proportion female"
tempfile gcomp
save "`gcomp'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear     // has cogz years id alters_base age_base gender race educ
xtset id years
merge m:1 su_id using "`gcomp'", keep(match master) nogen

// people who named no section-A alters aren't in the roster -> prop_female
// is undefined (0/0) for them and stays missing (they drop from the model)
summarize prop_female

//========================================================================
// Model A (unadjusted): cognition trajectory ~ baseline gender make-up
//   c.years##c.prop_female -> years, prop_female, years#prop_female.
//   years#prop_female is the key term: does a more female baseline network
//   predict the cognitive TRAJECTORY?
//========================================================================
display as text _newline "=== Model A: cogz ~ years x prop_female (unadjusted) ==="
mixed cogz c.years##c.prop_female || id: years, cov(unstructured)

// predicted trajectories at all-male / half / all-female networks
margins, at(years=(0 5 10) prop_female=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network gender make-up") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Proportion female"))
graph export "gender_comp_margins.png", replace width(1600)

//========================================================================
// Model B (adjusted): + RESPONDENT'S OWN gender + baseline demographics
//   Respondent's own sex is a likely CONFOUNDER -- women tend to have
//   more female-heavy networks and differ in cognition -- so adjusting for
//   i.gender is important here. Also add baseline age, race, education.
//   (These covariates already live in growth_long.dta.)
//========================================================================
display as text _newline "=== Model B: + respondent gender + demographics ==="
mixed cogz c.years##c.prop_female i.gender age_base i.race i.educ ///
    || id: years, cov(unstructured)

// adjusted predicted trajectories (covariates averaged over the sample)
margins, at(years=(0 5 10) prop_female=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network gender make-up") ///
    note("Adjusted for respondent sex, baseline age, race, education") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Proportion female"))
graph export "gender_comp_margins_adj.png", replace width(1600)

log close
