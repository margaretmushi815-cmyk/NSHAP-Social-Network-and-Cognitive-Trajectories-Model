// growth-model.do
//
// Linear mixed-effects (growth) models for cognition across the three
// NSHAP waves, in the 3-wave complete-case sample (complete_both==1),
// built up in nested steps:
//   Model 1: unconditional means  (random intercept)      -> ICC
//   Model 2: unconditional growth (random intercept+slope)
//   Model 3: + baseline network size (alters_base) x time
//   Model 4: + baseline demographics (age, sex, race, education)
//
// OUTCOME: within-wave z-scored cognition (cogz).
//   W1 = z-score of spmsq_noadd (SPMSQ, excl. address)
//   W2/W3 = z-score of moca_sa2 (13-item MoCA-SA)
//   Standardizing within wave puts the two different instruments (SPMSQ
//   vs MoCA-SA) on a common metric.
//
//   *** IMPORTANT INTERPRETATION CAVEAT ***
//   Because each wave is standardized to mean 0 / SD 1 within this sample,
//   the wave means are 0 BY CONSTRUCTION. So the fixed effect of time is
//   ~0 by design and does NOT represent average cognitive change over
//   time. What IS interpretable here: the variance components / ICC
//   (between- vs within-person variation) and whether individuals differ
//   in their trajectories (random slope). Absolute mean change is not
//   recoverable from within-wave z-scores -- this is a known limitation of
//   the standardization approach, pending the instrument-harmonization
//   decision at the upcoming meeting.
//
// TIME: coded in years since baseline (0, 5, 10).

version 14
capture log close
log using "growth-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"
if "$codedir"=="" global codedir "xxx"

//========================================================================
// Build person-wave (long) dataset: one row per respondent per wave, with
// within-wave z-scored cognition. Each wave is built separately, z-scored
// within the complete-case sample, then appended.
//========================================================================

//---- Wave 1: SPMSQ ----
local spmsq_items spmsq_ans1 spmsq_ans2 spmsq_ans3 spmsq_ans4 spmsq_ans5 ///
    spmsq_ans6 spmsq_ans7 spmsq_ans8 spmsq_ans9 spmsq_ans10

use su_id `spmsq_items' using "$datadir/nshap_w1_core.dta", clear
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

foreach v of varlist `spmsq_items' {
    assert inlist(`v', 0, 1, .c, .i)
}
egen spmsq_noadd = rowmean(`spmsq_items')
replace spmsq_noadd = spmsq_noadd * 10

// std() centers to mean 0 / SD 1 -- within-wave because this dataset is
// this wave's complete-case respondents only.
egen cogz = std(spmsq_noadd)
gen byte years = 0
keep su_id years cogz
tempfile w1
save "`w1'"

//---- Wave 2: MoCA-SA (5-yr) ----
local moca_items moca_month2 moca_date2 moca_rhino moca_contour moca_numbers ///
    moca_hands moca_trail2 moca_5numbers moca_3numbers moca_subcat ///
    moca_sentcat moca_word2 moca_alike2 moca_face moca_velvet moca_church ///
    moca_daisy moca_red

use su_id moca_flag `moca_items' using "$datadir/nshap_w2_core.dta", clear
do "$codedir/moca-sa.do" 2
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

egen cogz = std(moca_sa2)
gen byte years = 5
keep su_id years cogz
tempfile w2
save "`w2'"

//---- Wave 3: MoCA-SA (10-yr) ----
use su_id moca_flag `moca_items' using "$datadir/nshap_w3_core.dta", clear
do "$codedir/moca-sa.do" 3
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1

egen cogz = std(moca_sa2)
gen byte years = 10
keep su_id years cogz
tempfile w3
save "`w3'"

//---- Baseline (W1) person-level predictors: network size + demographics ----
// All taken from Wave 1 and held fixed across waves. Only W1 alters is
// used, so the unresolved cross-wave scale issue (W1 is 0-6, W2/W3 cap at
// 5) does not affect this model. Age is BASELINE age: in a growth model,
// age at each wave = baseline age + years, so time-varying age would be
// collinear with the time term.
use su_id alters age gender race educ ///
    using "$datadir/nshap_w1_core.dta", clear
merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen
keep if complete_both==1
rename alters alters_base
rename age    age_base
keep su_id alters_base age_base gender race educ
tempfile balt
save "`balt'"

//---- Stack into long format ----
use "`w1'", clear
append using "`w2'"
append using "`w3'"

// attach baseline network size to every person-wave row (m:1 = many long
// rows per su_id, one row per su_id in the baseline file)
merge m:1 su_id using "`balt'", keep(match master) nogen

// mixed needs a NUMERIC grouping id; su_id is a string, so build one.
egen long id = group(su_id)

// declare the panel structure (id = person, years = time)
xtset id years

label variable cogz  "Cognition (within-wave z-score)"
label variable years "Years since baseline"
label variable alters_base "Baseline network size (W1 alters, 0-6)"
label variable age_base    "Baseline age, years"
label variable gender      "Gender"
label variable race        "Race/ethnicity"
label variable educ        "Education"

// Save the built analytic long dataset so downstream do-files (e.g.
// covariate/moderator exploration) can load it without rebuilding.
save "$datadir/growth_long.dta", replace

//========================================================================
// SPAGHETTI PLOT: individual cognitive trajectories (raw data, no model)
//   One thin line per person connecting their cogz across years, for a
//   random subsample (~50) so it's legible, with the sample mean overlaid.
//   Shows the between-person heterogeneity in trajectories that motivates
//   the random effects. (The mean line sits ~0 at every wave BY
//   CONSTRUCTION -- within-wave z-scoring -- so read this plot for the
//   SPREAD and individual crossing, not the average trend.)
//========================================================================
preserve
    set seed 20240101
    // FULL-sample mean per wave -- computed BEFORE subsampling so the mean
    // line reflects all respondents, not just the plotted subset
    egen mcog = mean(cogz), by(years)

    // per-person baseline (year 0) and final (year 10) cognition, used to
    // pick a few ILLUSTRATIVE trajectories to highlight
    sort id years
    by id: gen double c0  = cogz[1]          // cognition at year 0
    by id: gen double c10 = cogz[_N]         // cognition at year 10
    gen byte _one = (years==0)               // one marker row per person

    // Select the person closest to each target (start, end) pattern, in
    // z-score units. This is deterministic (data-driven, no cherry-picking):
    //   A stable-high (1.2, 1.2)   B stable-low (-1.2, -1.2)
    //   C steep decline (1.5,-1.0) D gradual decline (0.8, 0.0)
    tempvar d
    gen double `d' = (c0-1.2)^2 + (c10-1.2)^2 if _one & !mi(c0) & !mi(c10)
    sort `d'
    local idA = id[1]
    drop `d'
    gen double `d' = (c0+1.2)^2 + (c10+1.2)^2 if _one & !mi(c0) & !mi(c10)
    sort `d'
    local idB = id[1]
    drop `d'
    gen double `d' = (c0-1.5)^2 + (c10+1.0)^2 if _one & !mi(c0) & !mi(c10)
    sort `d'
    local idC = id[1]
    drop `d'
    gen double `d' = (c0-0.8)^2 + (c10-0.0)^2 if _one & !mi(c0) & !mi(c10)
    sort `d'
    local idD = id[1]
    drop `d'

    // gray background: a random subset for legibility; always keep the 4
    // highlighted people so they appear even if not sampled
    egen tagid = tag(id)
    gen double _u = runiform() if tagid
    egen double _uid = min(_u), by(id)
    keep if _uid < 50/1552 | inlist(id, `idA', `idB', `idC', `idD')

    sort id years                            // re-sort for connect(L) below
    egen tagyr = tag(years)                  // one row per wave for the mean line

    // connect(L) links points only while x (years) increases, so the gray
    // line breaks between people -> spaghetti. The 4 colored lines are the
    // highlighted individuals; navy dashed = full-sample mean.
    twoway ///
      (line cogz years if !inlist(id,`idA',`idB',`idC',`idD'), ///
            connect(L) lcolor(gray%30) lwidth(vthin)) ///
      (line cogz years if id==`idA', sort lcolor(forest_green) lwidth(medthick)) ///
      (line cogz years if id==`idB', sort lcolor(dkorange)     lwidth(medthick)) ///
      (line cogz years if id==`idC', sort lcolor(cranberry)    lwidth(medthick)) ///
      (line cogz years if id==`idD', sort lcolor(purple)       lwidth(medthick)) ///
      (line mcog years if tagyr, sort lcolor(navy) lwidth(thick) lpattern(dash)) ///
      , title("Individual cognitive trajectories") ///
        subtitle("Random subsample; four illustrative trajectories highlighted") ///
        ytitle("Cognition (within-wave z-score)") ///
        xtitle("Years since baseline") xlabel(0 5 10) ///
        legend(order(1 "Other participants" 2 "Stable high" 3 "Stable low" ///
                     4 "Steep decline" 5 "Gradual decline" 6 "Sample mean") ///
               rows(2) size(small))
    graph export "growth_spaghetti.png", replace width(1600)
restore

//========================================================================
// Model 1: unconditional MEANS model (random intercept only)
//   cogz ~ 1, with a person-level random intercept. Partitions variance
//   into between-person vs within-person; estat icc gives the ICC.
//========================================================================
display as text _newline "=== Unconditional means model (random intercept) ==="
mixed cogz || id:
estat icc

//========================================================================
// Model 2: unconditional GROWTH model (random intercept + random slope)
//   cogz ~ years, with random intercept AND random slope of time, so each
//   person has their own trajectory. (Fixed effect of years ~0 by
//   construction -- see caveat at top; the random-slope VARIANCE is the
//   informative part: do people differ in how they change?)
//   cov(unstructured) lets the intercept and slope random effects
//   correlate rather than forcing them independent.
//========================================================================
display as text _newline "=== Unconditional growth model (random intercept + slope) ==="
mixed cogz years || id: years, cov(unstructured)

//========================================================================
// Model 3: + baseline network size and its interaction with time
//   c.years##c.alters_base expands to three fixed effects:
//     years         -- time slope when baseline alters = 0
//     alters_base   -- effect of baseline network size on cognition at
//                      baseline (years = 0)
//     years#alters_base -- does baseline network size relate to the
//                      cognitive TRAJECTORY? (the term of interest: do
//                      people who started with larger networks change
//                      differently over time)
//   Both entered as continuous (c.). Outcome is within-wave z-scored, so
//   these coefficients are in SD units of relative cognitive standing;
//   unlike the bare time effect, the alters_base terms ARE interpretable
//   (z-scoring removes wave means but preserves between-person differences
//   and within-person change).
//========================================================================
display as text _newline "=== Growth model + baseline network size (alters_base) ==="
mixed cogz c.years##c.alters_base || id: years, cov(unstructured)

// -- MARGINS PLOT: predicted cognitive trajectories by baseline network
//    size. margins computes the model-predicted cogz at each time point
//    (years 0/5/10) for a few representative network sizes; marginsplot
//    draws one line per size. The lines FANNING APART (or converging)
//    over time is the visual depiction of the years#alters_base
//    interaction -- i.e. whether baseline network size predicts the
//    cognitive TRAJECTORY. Change the alters_base=() values to taste.
margins, at(years=(0 5 10) alters_base=(1 3 5))
marginsplot, ///
    title("Cognitive trajectory by baseline network size") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Baseline no. of alters"))
graph export "growth_margins_alters.png", replace width(1600)

//========================================================================
// Model 4: + baseline demographic controls
//   Adds baseline age, sex, race, education as fixed (time-invariant)
//   covariates. These are BASELINE values (age especially -- see the note
//   at the baseline-predictor block on why time-varying age can't go in a
//   growth model alongside the time term).
//   Entered as MAIN EFFECTS only: they adjust cognitive level/standing.
//   NOTE: this controls the alters_base MAIN effect for demographic
//   confounding, but not necessarily the alters_base#years INTERACTION
//   (the trajectory term of interest). If you want to protect that
//   interaction too, the next step is adding demographic#years terms
//   (e.g. c.years##c.age_base) so demographics are allowed to shape the
//   trajectory -- say the word and I'll add them.
//========================================================================
display as text _newline "=== Growth model + baseline network size + demographics ==="
mixed cogz c.years##c.alters_base age_base i.gender i.race i.educ ///
    || id: years, cov(unstructured)

//========================================================================
// Export FINAL (Model 4) results to a 2-sheet Excel workbook.
//   Sheet "Fixed effects"  : parameter table (b, SE, z, p, 95% CI). The
//     interpretable fixed effects are the named rows (years, alters_base,
//     the interaction, demographics); the variance parameters (incl.
//     residual) appear at the bottom.
//   Sheet "Random effects" : (co)variance of the id-level random
//     intercept and random slope, from estat recovariance.
//
// IMPORTANT: capture the parameter table NOW, before margins runs --
// margins OVERWRITES r(table), so these two matrix captures must come
// first, immediately after the mixed command.
//========================================================================
matrix FE = r(table)'              // fixed effects (+ variance parameters)
estat recovariance                 // random-effects covariance -> r(cov)
matrix RE = r(cov)                 // (if this errors, run `return list`
                                   //  after estat recovariance to confirm
                                   //  the matrix name in your version)

// ---- Sheet 1: fixed effects (written cell-by-cell for robustness) ----
putexcel set "growth_final_model.xlsx", sheet("Fixed effects") replace
putexcel A1 = ("Fully adjusted growth model of cognition (z-score)")
putexcel A3 = ("Parameter")
putexcel B3 = ("b")
putexcel C3 = ("SE")
putexcel D3 = ("z")
putexcel E3 = ("p")
putexcel F3 = ("ll (95%)")
putexcel G3 = ("ul (95%)")
local fn : rowfullnames FE
local nf = rowsof(FE)
forvalues r = 1/`nf' {
    local nm : word `r' of `fn'
    local xr = `r' + 3
    putexcel A`xr' = ("`nm'")
    putexcel B`xr' = (FE[`r',1])
    putexcel C`xr' = (FE[`r',2])
    putexcel D`xr' = (FE[`r',3])
    putexcel E`xr' = (FE[`r',4])
    putexcel F`xr' = (FE[`r',5])
    putexcel G`xr' = (FE[`r',6])
}

// ---- Sheet 2: random-effects (co)variance (cell-by-cell) ----
putexcel set "growth_final_model.xlsx", sheet("Random effects") modify
putexcel A1 = ("Random-effects (co)variance: id-level intercept & slope")
local nc = colsof(RE)
local cn : colfullnames RE
forvalues c = 1/`nc' {
    local L : word `c' of `cn'
    local col = char(65 + `c')          // c=1 -> "B", c=2 -> "C", ...
    putexcel `col'3 = ("`L'")
}
local rn : rowfullnames RE
forvalues r = 1/`nc' {
    local nm : word `r' of `rn'
    local xr = `r' + 3
    putexcel A`xr' = ("`nm'")
    forvalues c = 1/`nc' {
        local col = char(65 + `c')
        putexcel `col'`xr' = (RE[`r',`c'])
    }
}

// -- MARGINS PLOT (demographic-adjusted): same predicted-trajectory-by-
//    network-size plot, now from the covariate-adjusted Model 4. Because
//    age_base/gender/race/educ are not named in at(), margins AVERAGES the
//    predictions over their observed distribution in the sample -- i.e.
//    these are demographic-adjusted predicted trajectories. Compare the
//    fanning here vs the unadjusted plot above: if the lines spread less
//    after adjustment, demographics accounted for part of the apparent
//    network-trajectory link.
margins, at(years=(0 5 10) alters_base=(1 3 5))
marginsplot, ///
    title("Cognitive trajectory by baseline network size") ///
    note("Adjusted for baseline age, sex, race, education") ///
    ytitle("Cognition (within-wave z-score)") ///
    xtitle("Years since baseline") ///
    legend(title("Baseline no. of alters"))
graph export "growth_margins_alters_adj.png", replace width(1600)

log close
