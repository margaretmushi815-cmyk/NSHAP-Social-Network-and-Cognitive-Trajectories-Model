// loneliness-stratified-model.do
//
// Runs the fully-adjusted growth model (Model 4 from growth-model.do)
// SEPARATELY in two baseline-loneliness groups (low vs high, median
// split) -- i.e. baseline loneliness as a MODERATOR: does the network /
// cognitive-trajectory story differ for lonely vs non-lonely people?
//
//   Loneliness = W1 UCLA 3-item scale (Hughes et al. 2004): companion +
//     leftout + isolated. W1 items are coded 1-3 (composite range 3-9;
//     higher = lonelier). NO pre-built composite exists -- summed here.
//   Grouping is BASELINE (W1) so it cleanly precedes the trajectory.
//
//   *** CROSS-WAVE NOTE: W1 loneliness items (companion/leftout/isolated,
//   coded 1-3) are NOT comparable to W2/W3 (companion2/leftout2/isolated2,
//   coded 0-3). Fine here -- we only use W1 for baseline grouping. ***
//
// Model (per group): cogz ~ years##alters_base + baseline demographics,
//   random intercept + slope. Requires growth_long.dta (run growth-model
//   .do first).

version 14
capture log close
log using "loneliness-stratified-model.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline UCLA loneliness composite (person-level) and median-split
//------------------------------------------------------------------------
use su_id companion leftout isolated using "$datadir/nshap_w1_core.dta", clear

// non-missing values must be on the 1-3 scale
assert inlist(companion,1,2,3) if !missing(companion)
assert inlist(leftout,1,2,3)   if !missing(leftout)
assert inlist(isolated,1,2,3)  if !missing(isolated)

// simple addition -> composite is missing unless ALL three items are
// present (Stata arithmetic returns missing if any addend is missing,
// including extended missing codes)
gen loneliness = companion + leftout + isolated
label variable loneliness "W1 UCLA loneliness (sum of 3 items, 3-9)"

// median split among respondents with a score
summarize loneliness, detail
scalar med = r(p50)
gen byte lonely_grp = loneliness > med if !missing(loneliness)
label define lon_lbl 0 "Low loneliness" 1 "High loneliness"
label values lonely_grp lon_lbl
display as text "Median loneliness = " as result med
tab lonely_grp   // check group balance (discrete scale -> may be uneven)

keep su_id loneliness lonely_grp
tempfile lon
save "`lon'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear
xtset id years
merge m:1 su_id using "`lon'", keep(match master) nogen

//========================================================================
// Fully-adjusted growth model (Model 4), run separately by group
//========================================================================
display as text _newline "=== LOW loneliness group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if lonely_grp==0 || id: years, cov(unstructured)
// capture fixed + random effects for the LOW group NOW (before the margins
// loop below overwrites r(table))
matrix FE_low = r(table)'
estat recovariance
matrix RE_low = r(cov)
estimates store lon_low

display as text _newline "=== HIGH loneliness group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if lonely_grp==1 || id: years, cov(unstructured)
// capture fixed + random effects for the HIGH group NOW
matrix FE_high = r(table)'
estat recovariance
matrix RE_high = r(cov)
estimates store lon_high

// side-by-side comparison of the network terms across the two groups.
// The key contrast is years#alters_base: does baseline network size
// affect the cognitive TRAJECTORY differently for lonely vs non-lonely?
estimates table lon_low lon_high, b(%9.3f) se ///
    keep(years alters_base c.years#c.alters_base) ///
    title("Network effect on cognitive trajectory: low vs high loneliness")

// visualise each group's trajectories by baseline network size
foreach g in 0 1 {
    estimates restore lon_`=cond(`g'==0,"low","high")'
    margins, at(years=(0 5 10) alters_base=(1 3 5))
    marginsplot, ///
        title("Cognitive trajectory by baseline network size") ///
        note("`=cond(`g'==0,"Low","High")' loneliness group" "Adjusted for age, sex, race, education") ///
        ytitle("Cognition (within-wave z-score)") ///
        xtitle("Years since baseline") legend(title("Baseline no. of alters"))
    graph export "lonely_strat_margins_`=cond(`g'==0,"low","high")'.png", ///
        replace width(1600)
}

//========================================================================
// Export fixed + random effects for BOTH groups to a 4-sheet workbook:
//   "Low - Fixed", "High - Fixed", "Low - Random", "High - Random".
// Uses the FE_/RE_ matrices captured right after each group's mixed
// command. Written cell-by-cell (robust across Stata versions).
//========================================================================
local xlfile "loneliness_stratified_models.xlsx"

// -- fixed-effects sheets (one per group) --
local first = 1
foreach g in low high {
    local G = proper("`g'")
    matrix M = FE_`g'
    if `first' {
        putexcel set "`xlfile'", sheet("`G' - Fixed") replace
        local first = 0
    }
    else {
        putexcel set "`xlfile'", sheet("`G' - Fixed") modify
    }
    putexcel A1 = ("`G' loneliness group -- fixed effects")
    putexcel A3 = ("Parameter")
    putexcel B3 = ("b")
    putexcel C3 = ("SE")
    putexcel D3 = ("z")
    putexcel E3 = ("p")
    putexcel F3 = ("ll (95%)")
    putexcel G3 = ("ul (95%)")
    local fn : rowfullnames M
    local nf = rowsof(M)
    forvalues r = 1/`nf' {
        local nm : word `r' of `fn'
        local xr = `r' + 3
        putexcel A`xr' = ("`nm'")
        putexcel B`xr' = (M[`r',1])
        putexcel C`xr' = (M[`r',2])
        putexcel D`xr' = (M[`r',3])
        putexcel E`xr' = (M[`r',4])
        putexcel F`xr' = (M[`r',5])
        putexcel G`xr' = (M[`r',6])
    }
}

// -- random-effects sheets (one per group) --
foreach g in low high {
    local G = proper("`g'")
    matrix M = RE_`g'
    putexcel set "`xlfile'", sheet("`G' - Random") modify
    putexcel A1 = ("`G' loneliness group -- random-effects (co)variance")
    local nc = colsof(M)
    local cn : colfullnames M
    forvalues c = 1/`nc' {
        local L : word `c' of `cn'
        local col = char(65 + `c')
        putexcel `col'3 = ("`L'")
    }
    local rn : rowfullnames M
    forvalues r = 1/`nc' {
        local nm : word `r' of `rn'
        local xr = `r' + 3
        putexcel A`xr' = ("`nm'")
        forvalues c = 1/`nc' {
            local col = char(65 + `c')
            putexcel `col'`xr' = (M[`r',`c'])
        }
    }
}

log close
