// kin-composition-model.do
//
// Linear mixed (growth) model: does the KIN / NON-KIN make-up of a
// respondent's baseline confidant network predict their cognitive
// trajectory?
//
//   Exposure: prop_kin = proportion of W1 section-A confidants who are
//     family/kin. Kin = relat 1-10 (spouse, ex-spouse, romantic partner,
//     parent, parent-in-law, child, step-child, sibling, other relative,
//     other in-law); non-kin = 11-18 (friend, neighbor, co-worker, clergy,
//     counselor, caseworker, housekeeper, other). Baseline, time-invariant.
//     (Same measure/definition as network-composition.do; built here
//     directly so this file is self-contained.)
//   Outcome:  cogz (within-wave z-scored cognition) over years (0/5/10).
//
// Standardization caveat carries over: cogz is within-wave z-scored, so
// the prop_kin terms are interpretable (relative standing) but the bare
// years effect is ~0 by construction.
//
// Requires growth_long.dta (from growth-model.do). Run that first.

version 14
capture log close
log using "kin-composition-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline kin make-up (prop_kin) from the W1 roster
//------------------------------------------------------------------------
use su_id lineno relat using "$datadir/nshap_w1_network.dta", clear
keep if inrange(lineno, 1, 5)             // section-A confidants (match alters_base)
assert inrange(relat, 1, 18)              // relationship type, no missing
gen byte kin = inrange(relat, 1, 10)      // family vs non-family (11-18)
collapse (mean) prop_kin=kin, by(su_id)
label variable prop_kin "Baseline network: proportion kin"
tempfile kcomp
save "`kcomp'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear     // has cogz years id alters_base age_base gender race educ
xtset id years
merge m:1 su_id using "`kcomp'", keep(match master) nogen

// baseline marital status (a strong candidate confounder for kin share) is
// not in growth_long -> pull it from the W1 core file
merge m:1 su_id using "$datadir/nshap_w1_core.dta", ///
    keepusing(maritlst) keep(match master) nogen
label variable maritlst "Baseline marital status"

// people who named no section-A alters aren't in the roster -> prop_kin
// is undefined (0/0) for them and stays missing (they drop from the model)
summarize prop_kin

//========================================================================
// Model A (unadjusted): cognition trajectory ~ baseline kin make-up
//   c.years##c.prop_kin -> years, prop_kin, years#prop_kin.
//   years#prop_kin is the key term: does a more kin-based baseline network
//   predict the cognitive TRAJECTORY?
//========================================================================
display as text _newline "=== Model A: cogz ~ years x prop_kin (unadjusted) ==="
mixed cogz c.years##c.prop_kin || id: years, cov(unstructured)

// predicted trajectories at all-non-kin / mixed / all-kin networks
margins, at(years=(0 5 10) prop_kin=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network kin make-up") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Proportion kin"))
graph export "kin_comp_margins.png", replace width(1600)

//========================================================================
// Model B (fully adjusted): + baseline demographics, MARITAL STATUS, and
// network SIZE -- the two kin-specific confounders:
//   * marital status: married respondents necessarily have a spouse (and
//     often children) in the roster, inflating prop_kin.
//   * network size (alters_base): kin share correlates with size, so this
//     shows the kin effect NET of how large the network is.
//   Added as MAIN effects (adjusting the level), consistent with the other
//   adjusted models. NOTE: to also protect the prop_kin#years INTERACTION
//   (the trajectory term) from confounding, these would need #years terms
//   (e.g. c.years##c.alters_base) -- say the word and I'll add them.
//========================================================================
display as text _newline "=== Model B: + demographics, marital status, network size ==="
mixed cogz c.years##c.prop_kin i.gender age_base i.race i.educ ///
    i.maritlst c.alters_base ///
    || id: years, cov(unstructured)

// adjusted predicted trajectories (covariates averaged over the sample)
margins, at(years=(0 5 10) prop_kin=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network kin make-up") ///
    note("Adjusted for age, sex, race, education, marital status, network size") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Proportion kin"))
graph export "kin_comp_margins_adj.png", replace width(1600)

log close
