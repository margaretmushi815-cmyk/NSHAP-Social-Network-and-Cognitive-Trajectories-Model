// density-stratified-model.do
//
// Runs the fully-adjusted growth model (cognition ~ years x alters_base +
// demographics) SEPARATELY in low vs high baseline NETWORK DENSITY groups
// (median split) -- i.e. baseline density as a MODERATOR: does the network
// SIZE effect on the cognitive trajectory differ by how interconnected the
// network is? (Parallels loneliness-stratified-model.do.)
//
//   Density = baseline density_prop (proportion of alter-pairs with any
//     contact, 0-1), built from W1 talkfreq1-5 (see network-density-model
//     .do for construction + the directed-dyad caveat). Undefined for
//     respondents with < 2 confidants -> they drop.
//   Model per group: cogz ~ years##alters_base + baseline demographics,
//     random intercept + slope. Requires growth_long.dta.

version 14
capture log close
log using "density-stratified-model.log", replace text

if "$datadir"=="" global datadir "xxx"

//------------------------------------------------------------------------
// Build baseline network density (density_prop) and median-split
//------------------------------------------------------------------------
use su_id lineno talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5 ///
    using "$datadir/nshap_w1_network.dta", clear
keep if inrange(lineno, 1, 5)
foreach v of varlist talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5 {
    assert inrange(`v', 0, 8) if !missing(`v')
}
egen tie_n   = rownonmiss(talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5)
egen tie_pos = anycount(talkfreq1 talkfreq2 talkfreq3 talkfreq4 talkfreq5), ///
    values(1 2 3 4 5 6 7 8)
collapse (sum) tie_n tie_pos, by(su_id)
gen density_prop = tie_pos / tie_n if tie_n > 0
label variable density_prop "Baseline network density (proportion of pairs connected, 0-1)"

// median split among respondents with a defined density
summarize density_prop, detail
scalar med = r(p50)
gen byte dens_grp = density_prop > med if !missing(density_prop)
label define dens_lbl 0 "Low density" 1 "High density"
label values dens_grp dens_lbl
display as text "Median density = " as result med
tab dens_grp                     // check balance (ties at the median -> may be uneven)

keep su_id density_prop dens_grp
tempfile dens
save "`dens'"

//------------------------------------------------------------------------
// Attach to the analytic long dataset
//------------------------------------------------------------------------
use "$datadir/growth_long.dta", clear
xtset id years
merge m:1 su_id using "`dens'", keep(match master) nogen

//========================================================================
// Fully-adjusted growth model, run separately by density group
//========================================================================
display as text _newline "=== LOW density group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if dens_grp==0 || id: years, cov(unstructured)
estimates store dens_low

display as text _newline "=== HIGH density group ==="
mixed cogz c.years##c.alters_base i.gender age_base i.race i.educ ///
    if dens_grp==1 || id: years, cov(unstructured)
estimates store dens_high

// key contrast: years#alters_base -- does baseline network SIZE affect the
// cognitive TRAJECTORY differently in sparse vs dense networks?
estimates table dens_low dens_high, b(%9.3f) se ///
    keep(years alters_base c.years#c.alters_base) ///
    title("Network-size effect on cognitive trajectory: low vs high density")

// predicted trajectories by network size within each density group
foreach g in 0 1 {
    estimates restore dens_`=cond(`g'==0,"low","high")'
    margins, at(years=(0 5 10) alters_base=(1 3 5))
    marginsplot, ///
        title("Cognitive trajectory by baseline network size") ///
        subtitle("`=cond(`g'==0,"Low","High")' density group") note("Adjusted for age, sex, race, education") ///
        ytitle("Cognition (within-wave z-score)") ///
        xtitle("Years since baseline") legend(title("Baseline no. of alters"))
    graph export "density_strat_margins_`=cond(`g'==0,"low","high")'.png", ///
        replace width(1600)
}

log close
