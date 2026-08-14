// cognition-network-regression.do
//
// Wave-specific, unadjusted linear regressions of cognitive score on
// number of alters (network size):
//   Wave 1: spmsq_noadd ~ alters
//   Wave 2: moca_sa2    ~ alters_w2
//   Wave 3: moca_sa2    ~ alters_w3
//
// SAMPLE: all three regressions are restricted to the SAME people --
// the complete-case sample with cognition + network data in all 3 waves
// (complete_both==1 in three_wave_flags.dta, built by
// three-wave-overlap.do). This makes the three waves directly
// comparable as a within-person trajectory rather than three different
// subsamples. Run three-wave-overlap.do first so that file exists.
//
// Each wave prints sanity checks (count of missing outcome/predictor,
// then summarize) before the regression -- confirm the N, min/max, and
// means look right before interpreting any coefficient.
//
// Cognitive scores:
//   - spmsq_noadd: your SPMSQ scoring (excluding the address item, per
//     Martha), reproduced as given -- proportion correct among the 10
//     non-address items, rescaled to a 0-10 "number correct" metric.
//     Missing codes .c/.i (per your code) are excluded automatically by
//     rowmean.
//   - moca_sa2: the 13-item MoCA-SA score (excludes the clock-drawing
//     items) computed by moca-sa.do, called below for each wave.
//
// Network size ("alters"):
//   - Wave 1 already has a pre-built `alters` variable in the core file,
//     used as-is.
//   - Waves 2 and 3 do NOT have a pre-built version, so it is
//     reconstructed here from each wave's network file using the exact
//     formula documented for Wave 1's `alters` (NSHAP W1 codebook, note
//     under variable `alters`):
//       count roster entries with lineno 1-5 (the main up-to-5-person
//       name generator, i.e. roster "section a" -- NOT the
//       spouse-identification, other-household-member, or full
//       household-roster follow-ups that also live in the network
//       file); top-code to 6 ("more than 5") if the 5th person listed
//       still said there were more; missing (.a) if the respondent
//       refused the roster (rosterintro==.a); 0 if they validly named
//       no one (rosterintro==0).
//     Confirmed Waves 2 and 3's network files have the same
//     su_id/lineno/anymore structure needed to replicate this.

version 14

log using "cognition-network-regression.log", replace text

// EDIT these to match your setup
if "$datadir"=="" global datadir "/path/to/your/nshap/data"
if "$codedir"=="" global codedir "/path/to/folder/containing/moca-sa.do"

//------------------------------------------------------------------------
// DEMOGRAPHIC ADJUSTMENT (Model 2)
//
// Each wave is analysed twice:
//   Model 1 (m1): unadjusted           cognition ~ alters
//   Model 2 (m2): + demographics       cognition ~ alters + age
//                                         + i.gender + i.race + i.educ
// then estimates table shows the two side by side so you can watch the
// alters coefficient move once demographics are held constant.
//
// Age is WAVE-SPECIFIC (pulled from each wave's own core file, since it
// changes across the 5- and 10-year gaps). Sex, race, and education are
// treated as fixed BASELINE characteristics, taken from Wave 1 and
// merged into every wave -- built here once as a tempfile.
//
// i.gender / i.race / i.educ: the i. prefix enters these as categorical
// (a dummy per level) rather than as a linear slope. NOTE: respondents
// missing any covariate (e.g. race coded .a refused / .b don't know) are
// dropped by the i. terms, so m2's N may be slightly below m1's; watch
// the N row in the estimates table. If you want a strict nested
// comparison on identical rows, say so and I'll add a common-sample
// restriction.
//------------------------------------------------------------------------
use su_id gender race educ using "$datadir/nshap_w1_core.dta", clear
tempfile baseline_demog
save "`baseline_demog'"

//========================================================================
// Wave 1: spmsq_noadd ~ alters
//========================================================================
local spmsq_items spmsq_ans1 spmsq_ans2 spmsq_ans3 spmsq_ans4 spmsq_ans5 ///
    spmsq_ans6 spmsq_ans7 spmsq_ans8 spmsq_ans9 spmsq_ans10

// age/gender/race/educ come from the W1 core file directly (for W1,
// baseline demographics ARE this wave's demographics)
use su_id alters age gender race educ `spmsq_items' ///
    using "$datadir/nshap_w1_core.dta", clear

// SPMSQ (excluding address, per Martha)
// due to the way the individual items are coded, treating don't know and
// refused as missing
foreach v of varlist `spmsq_items' {
    assert inlist(`v', 0, 1, .c, .i)
}

egen spmsq_noadd = rowmean(`spmsq_items')
// rescale to # correct
replace spmsq_noadd = spmsq_noadd * 10
label var spmsq_noadd "SPMSQ score (excl. address), 0-10"

// Restrict to the complete-case sample (data in all 3 waves)
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

// -- sanity checks: how many are missing each variable, then distributions --
count if missing(spmsq_noadd)
count if missing(alters)
summarize spmsq_noadd alters

display as text _newline "=== Wave 1 Model 1 (unadjusted): spmsq_noadd ~ alters ==="
regress spmsq_noadd alters
estimates store m1_w1

// -- plot: fitted regression line + 95% CI band, jittered scatter on top.
//    jitter() spreads the discrete points so density is visible; the
//    lfitci band shows the same linear fit reported by regress above.
twoway (lfitci spmsq_noadd alters) ///
       (scatter spmsq_noadd alters, jitter(4) msize(vsmall) mcolor(navy%20)) ///
       , ytitle("SPMSQ score (0-10)") ///
         xtitle("Number of alters (roster section A)") ///
         title("Wave 1 (baseline): cognition vs. network size") ///
         subtitle("Complete-case sample") ///
         legend(off)
graph export "reg_w1_spmsq_alters.png", replace width(1600)

// -- linearity check: treat alters as CATEGORICAL (i.), get the
//    model-predicted mean cognition at each alters level with 95% CIs,
//    and plot. If the points fall ~on a straight line, the linear model
//    above is justified; if they bend, consider modeling alters as
//    categorical or adding a nonlinear term. Regress run quietly so the
//    linear model above stays the headline; the margins table still
//    prints the predicted means.
quietly regress spmsq_noadd i.alters
margins alters
marginsplot, ytitle("SPMSQ score (0-10)") ///
    xtitle("Number of alters (roster section A)") ///
    title("Wave 1: cognition by network size") ///
    subtitle("Complete-case sample; model-based means +/- 95% CI")
graph export "reg_w1_spmsq_alters_margins.png", replace width(1600)

// -- Model 2: adjust for demographics --
display as text _newline "=== Wave 1 Model 2 (adjusted): + age, sex, race, education ==="
regress spmsq_noadd alters age i.gender i.race i.educ
estimates store m2_w1

// side-by-side comparison: watch the alters coefficient (and its SE)
// move from the unadjusted model to the adjusted one
estimates table m1_w1 m2_w1, b(%9.3f) se stats(N r2_a) ///
    title("Wave 1: unadjusted (m1) vs demographic-adjusted (m2)")

//========================================================================
// Wave 2: moca_sa2 ~ alters_w2
//========================================================================

// -- reconstruct alters from the network file --
use su_id lineno anymore using "$datadir/nshap_w2_network.dta", clear
gen byte in_roster = inrange(lineno, 1, 5)
egen alters_w2 = total(in_roster), by(su_id)
egen byte mt5   = total(lineno==5 & anymore==1), by(su_id)
replace alters_w2 = 6 if mt5
collapse (first) alters_w2, by(su_id)
tempfile alters_w2f
save "`alters_w2f'"

// -- cognitive score --
local moca_items moca_month2 moca_date2 moca_rhino moca_contour moca_numbers ///
    moca_hands moca_trail2 moca_5numbers moca_3numbers moca_subcat ///
    moca_sentcat moca_word2 moca_alike2 moca_face moca_velvet moca_church ///
    moca_daisy moca_red

// age here is WAVE-SPECIFIC (respondent's age at Wave 2)
use su_id rosterintro moca_flag age `moca_items' ///
    using "$datadir/nshap_w2_core.dta", clear
do "$codedir/moca-sa.do" 2

// -- attach alters, filling in the 0/refused cases the network file can't represent --
merge 1:1 su_id using "`alters_w2f'", nogen keep(match master)
replace alters_w2 = 0  if missing(alters_w2) & rosterintro==0
replace alters_w2 = .a if rosterintro==.a

// -- attach baseline (Wave 1) sex/race/education for the adjusted model --
merge 1:1 su_id using "`baseline_demog'", nogen keep(match master)

// Restrict to the complete-case sample (data in all 3 waves)
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

// -- sanity checks: how many are missing each variable, then distributions --
count if missing(moca_sa2)
count if missing(alters_w2)
summarize moca_sa2 alters_w2

display as text _newline "=== Wave 2 Model 1 (unadjusted): moca_sa2 ~ alters_w2 ==="
regress moca_sa2 alters_w2
estimates store m1_w2

// -- plot (see Wave 1 note) --
twoway (lfitci moca_sa2 alters_w2) ///
       (scatter moca_sa2 alters_w2, jitter(4) msize(vsmall) mcolor(navy%20)) ///
       , ytitle("MoCA-SA score, 13-item (0-13)") ///
         xtitle("Number of alters (roster section A)") ///
         title("Wave 2 (5-yr follow-up): cognition vs. network size") ///
         subtitle("Complete-case sample") ///
         legend(off)
graph export "reg_w2_moca_alters.png", replace width(1600)

// -- linearity check (see Wave 1 note) --
quietly regress moca_sa2 i.alters_w2
margins alters_w2
marginsplot, ytitle("MoCA-SA score, 13-item (0-13)") ///
    xtitle("Number of alters (roster section A)") ///
    title("Wave 2: cognition by network size") ///
    subtitle("Complete-case sample; model-based means +/- 95% CI")
graph export "reg_w2_moca_alters_margins.png", replace width(1600)

// -- Model 2: adjust for demographics (wave-2 age; baseline sex/race/educ) --
display as text _newline "=== Wave 2 Model 2 (adjusted): + age, sex, race, education ==="
regress moca_sa2 alters_w2 age i.gender i.race i.educ
estimates store m2_w2

estimates table m1_w2 m2_w2, b(%9.3f) se stats(N r2_a) ///
    title("Wave 2: unadjusted (m1) vs demographic-adjusted (m2)")

//========================================================================
// Wave 3: moca_sa2 ~ alters_w3
//========================================================================

// -- reconstruct alters from the network file --
use su_id lineno anymore using "$datadir/nshap_w3_network.dta", clear
gen byte in_roster = inrange(lineno, 1, 5)
egen alters_w3 = total(in_roster), by(su_id)
egen byte mt5   = total(lineno==5 & anymore==1), by(su_id)
replace alters_w3 = 6 if mt5
collapse (first) alters_w3, by(su_id)
tempfile alters_w3f
save "`alters_w3f'"

// -- cognitive score --
// age here is WAVE-SPECIFIC (respondent's age at Wave 3)
use su_id rosterintro moca_flag age `moca_items' ///
    using "$datadir/nshap_w3_core.dta", clear
do "$codedir/moca-sa.do" 3

// -- attach alters, filling in the 0/refused cases the network file can't represent --
merge 1:1 su_id using "`alters_w3f'", nogen keep(match master)
replace alters_w3 = 0  if missing(alters_w3) & rosterintro==0
replace alters_w3 = .a if rosterintro==.a

// -- attach baseline (Wave 1) sex/race/education for the adjusted model --
merge 1:1 su_id using "`baseline_demog'", nogen keep(match master)

// Restrict to the complete-case sample (data in all 3 waves)
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

// -- sanity checks: how many are missing each variable, then distributions --
count if missing(moca_sa2)
count if missing(alters_w3)
summarize moca_sa2 alters_w3

display as text _newline "=== Wave 3 Model 1 (unadjusted): moca_sa2 ~ alters_w3 ==="
regress moca_sa2 alters_w3
estimates store m1_w3

// -- plot (see Wave 1 note) --
twoway (lfitci moca_sa2 alters_w3) ///
       (scatter moca_sa2 alters_w3, jitter(4) msize(vsmall) mcolor(navy%20)) ///
       , ytitle("MoCA-SA score, 13-item (0-13)") ///
         xtitle("Number of alters (roster section A)") ///
         title("Wave 3 (10-yr follow-up): cognition vs. network size") ///
         subtitle("Complete-case sample") ///
         legend(off)
graph export "reg_w3_moca_alters.png", replace width(1600)

// -- linearity check (see Wave 1 note) --
quietly regress moca_sa2 i.alters_w3
margins alters_w3
marginsplot, ytitle("MoCA-SA score, 13-item (0-13)") ///
    xtitle("Number of alters (roster section A)") ///
    title("Wave 3: cognition by network size") ///
    subtitle("Complete-case sample; model-based means +/- 95% CI")
graph export "reg_w3_moca_alters_margins.png", replace width(1600)

// -- Model 2: adjust for demographics (wave-3 age; baseline sex/race/educ) --
display as text _newline "=== Wave 3 Model 2 (adjusted): + age, sex, race, education ==="
regress moca_sa2 alters_w3 age i.gender i.race i.educ
estimates store m2_w3

estimates table m1_w3 m2_w3, b(%9.3f) se stats(N r2_a) ///
    title("Wave 3: unadjusted (m1) vs demographic-adjusted (m2)")

log close
