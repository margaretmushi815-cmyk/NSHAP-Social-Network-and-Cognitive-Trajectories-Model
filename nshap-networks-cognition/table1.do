// table1.do
//
// Table 1: Wave 1 (baseline) characteristics of the analytic sample
// (respondents with cognition AND social network data in all 3 waves,
// i.e. complete_both==1 in three_wave_flags.dta) compared against
// respondents excluded from that sample (complete_both==0), restricted
// to the original Wave 1 cohort.
//
// Variables (all confirmed against the Wave 1 codebook):
//   spmsq_noadd - continuous, baseline cognition (SPMSQ excl. address,
//               rescaled 0-10); computed here with the same scoring as
//               cognition-network-regression.do
//   alters    - continuous, W1 social network size (0-6, where 6 =
//               "more than 5"). NOTE this top-code exists only in W1;
//               W2/W3 cap at 5 (see the cross-wave comparability issue).
//   age       - continuous, age of respondent (57-85)
//   agegrp    - categorical, age recode (57-64 / 65-74 / 75-85)
//   gender    - categorical, male/female
//   race      - categorical, self-identified (white, black, American
//               Indian/Alaskan Native, Asian/Pacific Islander, other)
//   educ      - categorical, education recode (4 categories)
//   maritlst  - categorical, marital status (6 categories)
//   hearn     - continuous, household income last year, dollars.
//               NOTE: ~29% missing in Wave 1 (881/3005) -- income
//               nonresponse is common; consider whether the bracketed
//               follow-up items (iml50k/iml25k/iml100k) should be used
//               to build a categorical income variable instead/in
//               addition if missingness is a concern for your write-up.
//
// NOTE ON dtable SYNTAX: dtable/collect is Stata's built-in table-1
// command (introduced Stata 17, fully available in your 19.5). I have
// not been able to run this against real data, so please run
// "help dtable" and "help collect export" to confirm the options below
// behave as expected before relying on the output -- particularly how
// dtable handles the extended missing codes (.a refused, .b don't know,
// etc.) in race/hearn.

version 14

log using "table1.log", replace text

// EDIT this to match the path used in three-wave-overlap.do
if "$datadir"=="" global datadir "/path/to/your/nshap/data"

//----------------------------------------------------------------------
// Pull Wave 1 demographics, keep only original W1 respondents, attach
// the complete_both flag from three_wave_flags.dta
//----------------------------------------------------------------------
// alters = W1 network size (pre-built, 0-6 where 6 = "more than 5");
// spmsq_ans* = SPMSQ cognition items, scored below.
local spmsq_items spmsq_ans1 spmsq_ans2 spmsq_ans3 spmsq_ans4 spmsq_ans5 ///
    spmsq_ans6 spmsq_ans7 spmsq_ans8 spmsq_ans9 spmsq_ans10

use su_id age agegrp gender race educ maritlst hearn alters `spmsq_items' ///
    using "$datadir/nshap_w1_core.dta", clear

merge 1:1 su_id using "$datadir/three_wave_flags.dta", ///
    keepusing(complete_both) keep(match master) nogen

// Anyone somehow missing complete_both after the merge has no data in
// later waves by definition -> excluded.
replace complete_both = 0 if missing(complete_both)

//----------------------------------------------------------------------
// Baseline cognition: SPMSQ excluding address (per Martha), treating
// don't know / refused as missing -- same scoring as the regression
// do-file, so the two are consistent.
//----------------------------------------------------------------------
foreach v of varlist `spmsq_items' {
    assert inlist(`v', 0, 1, .c, .i)
}
egen spmsq_noadd = rowmean(`spmsq_items')
// rescale to # correct
replace spmsq_noadd = spmsq_noadd * 10

//----------------------------------------------------------------------
// Column order: dtable orders the by() columns by the variable's numeric
// values, so complete_both (0=Excluded, 1=Complete) would put Excluded
// first. Build a reversed grouping variable so the COMPLETE-CASE column
// prints on the far left, with Excluded beside it.
//----------------------------------------------------------------------
gen byte sample_grp = 1 - complete_both
label define sample_grp_lbl 0 "Complete case (all 3 waves)" 1 "Excluded"
label values sample_grp sample_grp_lbl

//----------------------------------------------------------------------
// Clean labels for presentation. dtable pulls each row's label from the
// variable label, and the column-group spanner from the by-variable's
// label -- so relabelling here is what replaces the raw codebook text
// ("age of respondent (calculated in CAPI from dob)", "complete_both",
// etc.) with publication-ready wording.
//----------------------------------------------------------------------
label variable spmsq_noadd "Baseline cognition (SPMSQ, 0-10)"
label variable alters   "Social network size (no. of alters)"
label variable age      "Age, years"
label variable agegrp   "Age group, years"
label variable gender   "Gender"
label variable race     "Race/ethnicity"
label variable educ     "Education"
label variable maritlst "Marital status"
label variable sample_grp "3-wave data completeness"

// Income prints with absurd precision in dollars (e.g. 44,147.509).
// Rescale to $1,000s so a single decimal reads cleanly (44.1).
gen double hearn_k = hearn/1000
label variable hearn_k "Household income, $1,000s"

//----------------------------------------------------------------------
// Build the table: continuous vars unprefixed, categorical vars with
// the i. (factor-variable) prefix, by() adds the comparison column and
// requests a test statistic per row.
//   nformat(%9.1f mean sd) -> continuous stats to 1 decimal (counts and
//   percents already print sensibly by default).
//----------------------------------------------------------------------
// Key study measures (cognition, network size) lead the table, then
// demographics. by(sample_grp) puts the complete-case column on the left.
dtable spmsq_noadd alters age hearn_k ///
       i.agegrp i.gender i.race i.educ i.maritlst, ///
    by(sample_grp, tests) ///
    nformat(%9.1f mean sd) ///
    title("Table 1. Wave 1 baseline characteristics by 3-wave data completeness")

// Suggested footnote to add under the table (in Word, or via dtable's
// note() option if your version supports it):
//   "Values are mean (SD) for continuous variables and n (%) for
//    categorical variables. P-value from t-test (continuous) or Pearson
//    chi-squared (categorical). Cognition measured by the Short Portable
//    Mental Status Questionnaire (SPMSQ), excluding the address item.
//    Social network size is the number of confidants named in the Wave 1
//    roster, top-coded at 6 ('more than 5'). Household income missing for
//    ~29% of respondents."

// The p-value column header defaults to "Test"; this tries to rename it,
// but is wrapped in capture so it can't halt the do-file if the level
// name differs in your version -- if the header stays "Test", just rename
// it in Word.
capture collect label levels result test "P-value", modify

// Export for the manuscript -- change extension to .xlsx or .tex if you
// prefer Excel or LaTeX instead of Word.
collect export "table1.docx", replace

log close
