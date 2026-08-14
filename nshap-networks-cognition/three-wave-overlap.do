// three-wave-overlap.do
//
// Counts how many NSHAP respondents have BOTH cognition data and social
// network module data in all three rounds:
//   Wave 1: SPMSQ  (variables spmsq_ans*)
//   Wave 2: moca_*  (same battery as Wave 3's MoCA-SA; the W2 codebook
//     text documents this battery under a "ccfm_" prefix, but the actual
//     Wave 2 data file uses "moca_" -- confirmed against the real file,
//     which overrides the codebook here)
//   Wave 3: moca_*  (MoCA-SA)
//
// Definitions used (confirmed with you before writing this):
//   - "has cognition data"  = answered at least one item of that wave's
//     cognition module (module attempted; does NOT require a complete,
//     scoreable set of items -- that's handled separately, e.g. moca-sa.do)
//   - "has network data"    = rosterintro is non-missing that wave. This
//     correctly counts respondents who validly said they have zero
//     confidants, and excludes only those who refused the roster question.
//     (Network roster detail itself lives in separate long-format files
//     -- nshap_w#_network.dta -- but rosterintro in each wave's core file
//     tells us whether the module was completed at all.)

version 14

// Plain-text log of every command and its output from this do-file.
// "replace" overwrites a prior log of the same name each time you rerun
// this file; switch to "append" if you'd rather keep a cumulative record.
log using "three-wave-overlap.log", replace text

// EDIT this to the folder holding your six NSHAP .dta files
if "$datadir"=="" global datadir "/path/to/your/nshap/data"

//----------------------------------------------------------------------
// Wave 1: SPMSQ items + rosterintro
//----------------------------------------------------------------------
local spmsq_w1 spmsq_ans1 spmsq_ans1a spmsq_ans1b spmsq_ans1c spmsq_ans2 ///
    spmsq_ans3 spmsq_ans4 spmsq_ans4a spmsq_ans5 spmsq_ans6 spmsq_ans6a ///
    spmsq_ans6b spmsq_ans6c spmsq_ans7 spmsq_ans8 spmsq_ans9 spmsq_ans10

use su_id rosterintro `spmsq_w1' using "$datadir/nshap_w1_core.dta", clear

egen byte nonmiss_cog_w1 = rownonmiss(`spmsq_w1')
gen byte has_cog_w1 = (nonmiss_cog_w1 > 0)
gen byte has_net_w1 = !missing(rosterintro)

keep su_id has_cog_w1 has_net_w1
tempfile flags_w1
save "`flags_w1'"

//----------------------------------------------------------------------
// Wave 2: moca_* items + rosterintro
//----------------------------------------------------------------------
local moca_w2 moca_month2 moca_date2 moca_rhino moca_contour moca_numbers ///
    moca_hands moca_trail2 moca_5numbers moca_3numbers moca_subcat ///
    moca_sentcat moca_word2 moca_alike2 moca_face moca_velvet moca_church ///
    moca_daisy moca_red

use su_id rosterintro `moca_w2' using "$datadir/nshap_w2_core.dta", clear

egen byte nonmiss_cog_w2 = rownonmiss(`moca_w2')
gen byte has_cog_w2 = (nonmiss_cog_w2 > 0)
gen byte has_net_w2 = !missing(rosterintro)

keep su_id has_cog_w2 has_net_w2
tempfile flags_w2
save "`flags_w2'"

//----------------------------------------------------------------------
// Wave 3: moca_* items + rosterintro
//----------------------------------------------------------------------
local moca_w3 moca_month2 moca_date2 moca_rhino moca_contour moca_numbers ///
    moca_hands moca_trail2 moca_5numbers moca_3numbers moca_subcat ///
    moca_sentcat moca_word2 moca_alike2 moca_face moca_velvet moca_church ///
    moca_daisy moca_red

use su_id rosterintro `moca_w3' using "$datadir/nshap_w3_core.dta", clear

egen byte nonmiss_cog_w3 = rownonmiss(`moca_w3')
gen byte has_cog_w3 = (nonmiss_cog_w3 > 0)
gen byte has_net_w3 = !missing(rosterintro)

keep su_id has_cog_w3 has_net_w3
tempfile flags_w3
save "`flags_w3'"

//----------------------------------------------------------------------
// Combine all three waves' flags by su_id and count the overlap
//----------------------------------------------------------------------
use "`flags_w1'", clear
merge 1:1 su_id using "`flags_w2'"
drop _merge
merge 1:1 su_id using "`flags_w3'"
drop _merge

// Respondents absent from a given wave's core file have no data that
// wave -- code their flags 0 (instead of leaving them system-missing) so
// the logical tests below give clean 0/1 results, not missing values.
foreach v of varlist has_cog_w1 has_net_w1 has_cog_w2 has_net_w2 has_cog_w3 has_net_w3 {
    replace `v' = 0 if missing(`v')
}

gen byte complete_cog  = has_cog_w1==1 & has_cog_w2==1 & has_cog_w3==1
gen byte complete_net  = has_net_w1==1 & has_net_w2==1 & has_net_w3==1
gen byte complete_both = complete_cog==1 & complete_net==1

count if complete_cog==1
display as text "Have cognition data (SPMSQ / MoCA-SA) in all 3 waves: " as result r(N)

count if complete_net==1
display as text "Have network-module data in all 3 waves: " as result r(N)

count if complete_both==1
display as text "Have BOTH cognition and network data in all 3 waves: " as result r(N)

save "$datadir/three_wave_flags.dta", replace

log close
