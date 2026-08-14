// community-stratified-model.do
//
// Runs the fully-adjusted growth model (cognition ~ years x alters_base +
// demographics) SEPARATELY in low vs high baseline COMMUNITY INVOLVEMENT
// groups (median split) -- involvement as a MODERATOR: does the network
// SIZE effect on the cognitive trajectory differ by how involved in the
// community the respondent is? (Parallels loneliness-stratified-model.do.)
//
//   Community involvement = comminv (0-18) = atndserv + attend +
//     volunteer (religious services + organized-group meetings +
//     volunteering), each 0-6 (see community-involvement-model.do).
//     Missing unless all three items present (leave-behind non-returners
//     drop).
//   Model per group: cogz ~ years##alters_base + baseline demographics,
//     random intercept + slope. Requires growth_long.dta.

version 14
capture log close
log using "community-stratified-model.log", replace text

if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline community-involvement scale (comminv, 0-18) and split
//------------------------------------------------------------------------
use su_id atndserv attend volunteer using "$datadir/nshap_w1_core.dta", clear
foreach v of varlist atndserv attend volunteer {
    assert inrange(`v', 0, 6) if !missing(`v')
}
gen comminv = atndserv + attend + volunteer     // missing unless all 3 present
label variable comminv "W1 community involvement (0-18)"

// median split among respondents with a score
summarize comminv, detail
scalar med = r(p50)
gen byte comm_grp = comminv > med if !missing(comminv)
label define comm_lbl 0 "Low involvement" 1 "High involvement"
label values comm_grp comm_lbl
display as text "Median community involvement = " as result med
tab comm_grp                     // check balance (discrete scale -> may be uneven)

keep su_id comminv comm_grp
tempfile comm
save "`comm'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear
xtset id years
merge m:1 su_id using "`comm'", keep(match master) nogen

//========================================================================
// Fully-adjusted growth model, run separately by involvement group
//========================================================================
display as text _newline "=== LOW community involvement group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if comm_grp==0 || id: years, cov(unstructured)
estimates store comm_low

display as text _newline "=== HIGH community involvement group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if comm_grp==1 || id: years, cov(unstructured)
estimates store comm_high

// key contrast: years#alters_base -- does baseline network SIZE affect the
// cognitive TRAJECTORY differently for low vs high community involvement?
estimates table comm_low comm_high, b(%9.3f) se ///
    keep(years alters_base c.years#c.alters_base) ///
    title("Network-size effect on cognitive trajectory: low vs high community involvement")

// predicted trajectories by network size within each involvement group
foreach g in 0 1 {
    estimates restore comm_`=cond(`g'==0,"low","high")'
    margins, at(years=(0 5 10) alters_base=(1 3 5))
    marginsplot, ///
        title("Cognitive trajectory by baseline network size") ///
        subtitle("`=cond(`g'==0,"Low","High")' community involvement") note("Adjusted for age, sex, race, education") ///
        ytitle("Cognition (within-wave z-score)") ///
        xtitle("Years since baseline") legend(title("Baseline no. of alters"))
    graph export "community_strat_margins_`=cond(`g'==0,"low","high")'.png", ///
        replace width(1600)
}

log close
