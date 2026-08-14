// network-persistence.do
//
// Builds a network tie-PERSISTENCE (stability) measure -- the "carryover"
// operationalization -- and tests it against the cognitive trajectory.
//
// MEASURE (carryover): of a respondent's CURRENT confidants (section-A
// roster, lineno 1-5), the proportion that were also on an earlier
// roster, using NSHAP's own cross-wave flag roster_w1:
//   prop_carryover_w2 = share of W2 confidants that were on the W1 roster
//   prop_carryover_w3 = share of W3 confidants that were on the W1 AND/OR
//                       W2 roster
//   (+ counts n_carryover_w2 / _w3)
//   roster_w1 is coded 1=yes, 0=no, with .a/.b/.c missing; mean() gives
//   the proportion among alters with a valid yes/no.
//
//   NOTE the reference differs by wave: W2's flag is "on W1 roster"; W3's
//   is "on W1 and/or W2 roster". Not perfectly parallel -- documented.
//
// *** TEMPORALITY CAVEAT -- VERIFY AT MEETING ***
//   Unlike alters_base and the composition measures (all baseline W1
//   quantities), persistence is inherently a BETWEEN-WAVE quantity: it is
//   measured OVER the W1->W2 (or W1->W3) interval -- the same window as
//   the cognitive change being modeled. So entering it as if it were a
//   baseline predictor is provisional. The temporally cleaner framing is
//   "W1->W2 retention predicts SUBSEQUENT (W2->W3) cognitive change,"
//   which is a different model structure. This build is a FIRST LOOK to
//   take to the advisor; the operationalization may change.
//   (Also considered: W1-anchored RETENTION via nshap_w2_network_update
//   .dta -- "of your baseline confidants, how many persisted" -- which is
//   more faithful but a bigger build. Deferred pending the meeting.)

version 14
capture log close
log using "network-persistence.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//========================================================================
// PART 1: build the carryover measures from the W2 and W3 rosters
//========================================================================

//---- Wave 2: carryover from W1 ----
use su_id lineno roster_w1 using "$datadir/nshap_w2_network.dta", clear
keep if inrange(lineno, 1, 5)                 // section-A confidants
assert inlist(roster_w1, 0, 1, .a, .b, .c)
collapse (mean) prop_carryover_w2=roster_w1 ///
         (sum)  n_carryover_w2=roster_w1, by(su_id)
label variable prop_carryover_w2 "W2: proportion of confidants carried over from W1"
label variable n_carryover_w2    "W2: no. of confidants carried over from W1"
tempfile carry_w2
save "`carry_w2'"

//---- Wave 3: carryover from W1 and/or W2 ----
use su_id lineno roster_w1 using "$datadir/nshap_w3_network.dta", clear
keep if inrange(lineno, 1, 5)
assert inlist(roster_w1, 0, 1, .a, .b, .c)
collapse (mean) prop_carryover_w3=roster_w1 ///
         (sum)  n_carryover_w3=roster_w1, by(su_id)
label variable prop_carryover_w3 "W3: proportion of confidants carried over from W1/W2"
label variable n_carryover_w3    "W3: no. of confidants carried over from W1/W2"
tempfile carry_w3
save "`carry_w3'"

//---- Save a persistent person-level persistence file ----
// so other do-files (e.g. covariate-moderator.do) can merge these
// measures without rebuilding them.
use "`carry_w2'", clear
merge 1:1 su_id using "`carry_w3'", nogen
save "$datadir/network_persistence.dta", replace

//========================================================================
// PART 2: attach to the analytic long dataset and take a first look
//========================================================================
use "$datadir/growth_long.dta", clear   // built by growth-model.do
xtset id years

merge m:1 su_id using "`carry_w2'", keep(match master) nogen
merge m:1 su_id using "`carry_w3'", keep(match master) nogen

// sanity check: distributions, and how much is missing in this sample
// (roster_w1 == .c "not applicable" should be rare for our returning
// complete-case respondents, but confirm)
summarize prop_carryover_w2 n_carryover_w2 prop_carryover_w3 n_carryover_w3
count if missing(prop_carryover_w2)
count if missing(prop_carryover_w3)

//------------------------------------------------------------------------
// PROVISIONAL model (see TEMPORALITY CAVEAT above): treat W1->W2 carryover
// as a person-level predictor of the cognitive trajectory, parallel to
// the composition measures. Interpret cautiously and revisit after the
// meeting -- this is a first look, not a settled specification.
//------------------------------------------------------------------------
display as text _newline "=== PROVISIONAL: cognition trajectory ~ W1->W2 carryover ==="
mixed cogz c.years##c.prop_carryover_w2 || id: years, cov(unstructured)

log close
