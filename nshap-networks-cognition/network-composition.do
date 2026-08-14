// network-composition.do
//
// Builds BASELINE (Wave 1) network-composition measures from the W1
// network roster and tests each as a predictor of the cognitive
// trajectory, parallel to how alters_base is used in growth-model.do.
//
// Composition is computed over the SECTION-A confidant roster (lineno
// 1-5) -- the same alters that define alters_base -- so network size and
// composition describe the same network. (Sections b/c/d -- spouse-if-
// not-already-named, other household members -- are excluded.)
//
// Baseline only: W1 uses relat (18 categories); W2/W3 use relat2 (19
// categories), so building from W1 alone avoids that cross-wave
// harmonization issue (same reasoning as alters_base).
//
// MEASURES (all person-level, from alter-level roster via collapse):
//   prop_female       - proportion of alters who are female (node_gender)
//   n_coresident      - number of alters living in the household
//                       (livewith==1)
//   prop_kin          - proportion of alters who are family/kin
//                       (relat 1-10; non-kin = 11-18)
//   reltype_diversity - number of DISTINCT relationship types among the
//                       alters (operationalizes network "diversity/
//                       complexity")
//
// FRAMING: these are additional network EXPOSURES (like alters_base), not
// confounders/moderators. Each is entered as a baseline value with a
// main effect AND an interaction with time (does composition predict the
// TRAJECTORY?).

version 14
capture log close
log using "network-composition.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//========================================================================
// PART 1: build the baseline composition measures from the W1 roster
//========================================================================
use su_id lineno node_gender livewith relat ///
    using "$datadir/nshap_w1_network.dta", clear

// keep the section-A confidant roster only (lineno 1-5 == section a),
// matching the alters_base definition
keep if inrange(lineno, 1, 5)

// verify coding is as documented before aggregating
assert inlist(node_gender, 1, 2)
assert inlist(livewith, 0, 1, 2, .a)
assert inrange(relat, 1, 18)

// alter-level 0/1 indicators to be averaged/summed within respondent
gen byte female = (node_gender==2)
gen byte cores  = (livewith==1)          // lives in same household
gen byte kin    = inrange(relat, 1, 10)  // family vs non-family (11-18)

// tag one row per (respondent, distinct relationship type) so summing the
// tag counts the number of DISTINCT relat categories per respondent
egen byte tag_relat = tag(su_id relat)

// collapse alter-level -> person-level
collapse (mean) prop_female=female prop_kin=kin ///
         (sum)  n_coresident=cores reltype_diversity=tag_relat, ///
         by(su_id)

label variable prop_female       "Baseline network: proportion female"
label variable n_coresident      "Baseline network: no. co-resident alters"
label variable prop_kin          "Baseline network: proportion kin"
label variable reltype_diversity "Baseline network: no. distinct relationship types"

tempfile composition
save "`composition'"

//========================================================================
// PART 2: attach to the analytic long dataset and model each measure
//========================================================================
use "$datadir/growth_long.dta", clear   // built by growth-model.do
xtset id years

merge m:1 su_id using "`composition'", keep(match master) nogen

// Respondents who named no section-A alters (alters_base==0) are absent
// from the roster file -> missing after merge. Counts are truly 0 for
// them; proportions are undefined (0/0) and stay missing.
replace n_coresident      = 0 if missing(n_coresident)      & alters_base==0
replace reltype_diversity = 0 if missing(reltype_diversity) & alters_base==0

// sanity check the constructed measures before modeling
summarize prop_female n_coresident prop_kin reltype_diversity

//------------------------------------------------------------------------
// One growth model per composition measure: main effect + interaction
// with time. The measure#years term asks whether that composition feature
// predicts the cognitive TRAJECTORY. (Same interpretation caveat as the
// growth model: cogz is within-wave z-scored, so these composition terms
// ARE interpretable, but the bare years effect is ~0 by construction.)
//------------------------------------------------------------------------
foreach m in prop_female n_coresident prop_kin reltype_diversity {
    display as text _newline "=== Growth model: `m' x time ==="
    mixed cogz c.years##c.`m' || id: years, cov(unstructured)
}

// NOTE: to test composition NET of network size, add alters_base, e.g.
//   mixed cogz c.years##c.prop_kin c.years##c.alters_base || id: years, ///
//       cov(unstructured)
// and to adjust for demographics, add age_base i.gender i.race i.educ.

log close
