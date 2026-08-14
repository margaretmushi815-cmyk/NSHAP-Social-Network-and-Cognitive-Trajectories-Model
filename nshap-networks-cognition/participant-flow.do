// participant-flow.do
//
// Computes the participant flow / exclusion cascade from the NSHAP Wave 1
// baseline cohort down to the 3-wave complete-case analytic sample, and
// prints the N excluded and N retained at each step. Use the printed
// numbers to build the STROBE-style participant flow diagram.
//
// Structure: SEQUENTIAL BY WAVE, and at each FOLLOW-UP wave the exclusion
// is split into two reasons:
//   (a) NOT re-interviewed that wave   (attrition: death / non-response)
//   (b) re-interviewed but MISSING cognition and/or network data
//
//   Baseline (W1) -> lose those without W1 cognition+network
//                 -> W2: (a) not re-interviewed, then
//                        (b) re-interviewed but missing data
//                 -> W3: (a) not re-interviewed, then
//                        (b) re-interviewed but missing data
//                 = analytic sample
//
// "Re-interviewed at wave X" is defined as having a record in that wave's
// core file (nshap_wX_core.dta). Because the cognition/network items come
// FROM the core file, has_cog/has_net can only be 1 for someone who was
// re-interviewed -- so reasons (a) and (b) are mutually exclusive and sum
// to that wave's total exclusion.
//
// Requires three_wave_flags.dta (from three-wave-overlap.do), which holds
// the per-wave flags has_cog_w#/has_net_w# used below.

version 14
capture log close
log using "participant-flow.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "/path/to/your/nshap/data"

//------------------------------------------------------------------------
// Build participation flags: was the respondent re-interviewed at W2/W3?
// (i.e. do they have a record in that wave's core file)
//------------------------------------------------------------------------
use su_id using "$datadir/nshap_w2_core.dta", clear
gen byte in_w2 = 1
tempfile part_w2
save "`part_w2'"

use su_id using "$datadir/nshap_w3_core.dta", clear
gen byte in_w3 = 1
tempfile part_w3
save "`part_w3'"

//------------------------------------------------------------------------
// Step 0: NSHAP Wave 1 baseline cohort (denominator)
//------------------------------------------------------------------------
use su_id using "$datadir/nshap_w1_core.dta", clear

merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(has_cog_w1 has_net_w1 has_cog_w2 has_net_w2 has_cog_w3 has_net_w3) ///
    keep(match master) nogen
merge 1:1 su_id using "`part_w2'", keep(match master) nogen
merge 1:1 su_id using "`part_w3'", keep(match master) nogen

// A W1 respondent absent from a using-file gets 0 for that flag, not missing.
foreach v of varlist has_cog_w1 has_net_w1 has_cog_w2 has_net_w2 ///
        has_cog_w3 has_net_w3 in_w2 in_w3 {
    replace `v' = 0 if missing(`v')
}

count
scalar n0 = r(N)
display as text _newline "Step 0 -- NSHAP Wave 1 baseline cohort: " as result n0

//------------------------------------------------------------------------
// Step 1: require cognition AND network data at Wave 1
//------------------------------------------------------------------------
drop if !(has_cog_w1==1 & has_net_w1==1)
count
scalar n1 = r(N)
display as text "Excluded at Wave 1 (missing cognition and/or network): " ///
    as result n0 - n1
display as text "Remaining after Wave 1: " as result n1

//------------------------------------------------------------------------
// Step 2: Wave 2 (5-yr follow-up) -- split into (a) attrition, (b) missing
//------------------------------------------------------------------------
// (a) not re-interviewed at Wave 2
drop if in_w2==0
count
scalar n2a = r(N)
display as text "Excluded at Wave 2a (not re-interviewed): " as result n1 - n2a

// (b) re-interviewed but missing cognition and/or network
drop if !(has_cog_w2==1 & has_net_w2==1)
count
scalar n2b = r(N)
display as text "Excluded at Wave 2b (re-interviewed, missing cognition/network): " ///
    as result n2a - n2b
display as text "Remaining after Wave 2: " as result n2b

//------------------------------------------------------------------------
// Step 3: Wave 3 (10-yr follow-up) -- split into (a) attrition, (b) missing
//------------------------------------------------------------------------
// (a) not re-interviewed at Wave 3
drop if in_w3==0
count
scalar n3a = r(N)
display as text "Excluded at Wave 3a (not re-interviewed): " as result n2b - n3a

// (b) re-interviewed but missing cognition and/or network
drop if !(has_cog_w3==1 & has_net_w3==1)
count
scalar n3b = r(N)
display as text "Excluded at Wave 3b (re-interviewed, missing cognition/network): " ///
    as result n3a - n3b
display as text _newline "FINAL analytic sample " ///
    "(cognition + network in all 3 waves): " as result n3b

// Cross-check: n3b should equal the complete_both==1 count reported by
// three-wave-overlap.do (expected 1,552).

log close
