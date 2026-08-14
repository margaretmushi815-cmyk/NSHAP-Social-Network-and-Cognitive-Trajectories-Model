// network-density-model.do
//
// Linear mixed (growth) model: does baseline NETWORK DENSITY -- how
// interconnected a respondent's confidants are with each OTHER -- predict
// the cognitive trajectory?
//
//   Density is built from the alter-to-alter contact items talkfreq1..
//   talkfreq5 in the W1 network file: for each confidant (roster row),
//   "how frequently do [this alter] and [the alter on line k] talk to each
//   other?", coded 0 = have never spoken .. 8 = most frequent. Self-cells
//   (lineno==k) and empty slots are SKIPPED in the questionnaire -> stored
//   as missing, so they drop out of the aggregation automatically.
//
//   Two operationalizations (both built; density_prop modeled as primary):
//     density_prop = proportion of alter-pair reports with ANY contact
//                    (talkfreq > 0). 0-1. The textbook ego-network
//                    "density" (share of possible ties that exist).
//     density_mean = mean contact frequency across alter-pair reports
//                    (0-8 scale). Tie-STRENGTH version.
//   Computed over SECTION-A confidants (lineno 1-5), matching alters_base.
//   Undefined (missing) for respondents with < 2 confidants (no pairs).
//
//   *** CONSTRUCTION CAVEAT: density here averages over DIRECTED dyad
//   reports (each pair contributes i->j and j->i, which can disagree).
//   This is a defensible operationalization but network density has an
//   established NSHAP definition (cf. Cornwell et al. 2008) -- worth
//   confirming the exact construction with the statistician. ***
//
//   Outcome: cogz (within-wave z-scored cognition) over years (0/5/10).
//   Standardization caveat carries over (density terms interpretable;
//   bare years effect ~0 by construction). Requires growth_long.dta.

version 14
capture log close
log using "network-density-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline network density from the W1 roster (alter-alter ties)
//------------------------------------------------------------------------
use su_id lineno talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5 ///
    using "$datadir/nshap_w1_network.dta", clear
keep if inrange(lineno, 1, 5)             // section-A confidants (match alters_base)

// non-missing tie values are on the 0-8 scale
foreach v of varlist talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5 {
    assert inrange(`v', 0, 8) if !missing(`v')
}

// per alter row: sum of tie strengths, count of valid (non-missing) dyad
// reports, and count of reports showing ANY contact (talkfreq 1-8)
egen tie_sum = rowtotal(talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5)
egen tie_n   = rownonmiss(talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5)
egen tie_pos = anycount(talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5), ///
    values(1 2 3 4 5 6 7 8)

// aggregate to the respondent
collapse (sum) tie_sum tie_n tie_pos, by(su_id)

gen density_prop = tie_pos / tie_n if tie_n > 0     // share of pairs with any contact (0-1)
gen density_mean = tie_sum / tie_n if tie_n > 0     // mean contact frequency (0-8)
label variable density_prop "Baseline network density (proportion of pairs connected, 0-1)"
label variable density_mean "Baseline network density (mean contact frequency, 0-8)"
keep su_id density_prop density_mean
tempfile dens
save "`dens'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear     // cogz years id alters_base age_base gender race educ
xtset id years
merge m:1 su_id using "`dens'", keep(match master) nogen

summarize density_prop density_mean

//========================================================================
// Model A (unadjusted): cognition trajectory ~ baseline network density
//   c.years##c.density_prop -> years, density_prop, years#density_prop.
//   years#density_prop is the key term: does a denser (more
//   interconnected) baseline network predict the cognitive TRAJECTORY?
//========================================================================
display as text _newline "=== Model A: cogz ~ years x density_prop (unadjusted) ==="
mixed cogz c.years##c.density_prop || id: years, cov(unstructured)

margins, at(years=(0 5 10) density_prop=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network density") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Density (prop. connected)"))
graph export "density_margins.png", replace width(1600)

//========================================================================
// Model B (adjusted): + baseline demographics and network SIZE
//   Density is mechanically tied to size (denser small networks vs sparser
//   large ones), so alters_base is included to show density NET of size.
//   Demographics (age, sex, race, education) added as main effects.
//========================================================================
display as text _newline "=== Model B: + demographics + network size ==="
mixed cogz c.years##c.density_prop age_base i.gender i.race i.educ c.alters_base ///
    || id: years, cov(unstructured)

margins, at(years=(0 5 10) density_prop=(0 0.5 1))
marginsplot, ///
    title("Cognitive trajectory by baseline network density") ///
    note("Adjusted for age, sex, race, education, network size") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Density (prop. connected)"))
graph export "density_margins_adj.png", replace width(1600)

log close
