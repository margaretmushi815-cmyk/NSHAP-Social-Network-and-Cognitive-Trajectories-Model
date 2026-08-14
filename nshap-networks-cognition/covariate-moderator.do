// covariate-moderator.do
//
// Framework for examining individual variables as either COVARIATES
// (confounders) or MODERATORS (effect modifiers) of the baseline
// network-size effect on cognition, building on growth-model.do.
//
// THE DISTINCTION (decide the role from theory/a DAG, then test it):
//
//   COVARIATE / CONFOUNDER  -- a common cause of BOTH network size and
//     cognition. You ADJUST for it (main effect) and ask whether the
//     alters_base effect ATTENUATES. Term: add X as a main effect.
//     Question: "Is the network-cognition association real, or explained
//     by X?"
//
//   MODERATOR / EFFECT MODIFIER -- changes the STRENGTH/DIRECTION of the
//     network effect. You INTERACT it with alters_base and test the
//     interaction. Term: add X#alters_base. Question: "Does the
//     network-cognition association depend on X?"
//
//   Same variable can be tested either way; the role is a causal
//   decision, not a statistical one. A significant interaction does NOT
//   make something a confounder, and attenuation does NOT make it a
//   moderator.
//
// EXPOSURE here has two parts: alters_base (level) and alters_base#years
// (trajectory). "Moderating the effect" can mean the level (X#alters_base)
// or the trajectory (three-way X#alters_base#years). Start with the level.
//
// Candidate variables are entered as BASELINE (time-invariant) values, to
// match how alters_base and the demographics are handled in the growth
// model (and to avoid the cross-wave harmonization issues).

version 14
capture log close
log using "covariate-moderator.log", replace text

// EDIT to match your setup
if "$datadir"=="" global datadir "xxx"

// Load the analytic long dataset built + saved by growth-model.do.
// It contains: su_id id years cogz alters_base age_base gender race educ
use "$datadir/growth_long.dta", clear
xtset id years

//========================================================================
// REFERENCE MODEL: baseline network size x time (Model 3 from
// growth-model.do). Every check below is compared against this.
//========================================================================
display as text _newline "=== Reference: alters_base x time ==="
mixed cogz c.years##c.alters_base || id: years, cov(unstructured)
estimates store ref

//========================================================================
// WORKED EXAMPLE using education (educ), which is already in the dataset.
// Shows the two tests side by side. Swap educ for your real candidate.
//========================================================================

//---- (A) educ as a COVARIATE / confounder: add as MAIN effect ----
// Compare the alters_base and years#alters_base coefficients to the
// reference model. Meaningful shrinkage => educ was confounding the
// network effect.
display as text _newline "=== (A) educ as covariate (main effect) ==="
mixed cogz c.years##c.alters_base i.educ || id: years, cov(unstructured)
estimates store cov_educ

// Side-by-side: watch the alters_base terms move ref -> cov_educ
estimates table ref cov_educ, b(%9.3f) se ///
    keep(years alters_base c.years#c.alters_base) ///
    title("Confounder check: alters_base effect before vs after adjusting for educ")

//---- (B) educ as a MODERATOR / effect modifier: add INTERACTION ----
// c.alters_base##i.educ expands to alters_base, i.educ, and their
// interaction. The interaction term is the moderation test: does the
// network-cognition association differ across education groups?
display as text _newline "=== (B) educ as moderator (interaction) ==="
mixed cogz c.years##c.alters_base c.alters_base##i.educ ///
    || id: years, cov(unstructured)

// formal joint test of the moderation (all interaction dummies at once)
testparm c.alters_base#i.educ

// if the interaction is significant, visualise the moderated effect:
// margins educ, dydx(alters_base)     // network slope within each educ group
// marginsplot

//========================================================================
// TEMPLATE for a NEW candidate variable
//
// 1. SOURCE IT FIRST. Before modeling, verify the variable's name,
//    coding, and missingness in the Wave 1 file (lookfor / codebook), the
//    way we did for alters and the cognition measures -- don't trust the
//    codebook name blindly (recall the ccfm/moca surprise).
//
// 2. MERGE the baseline value in. Replace VARNAME with the real name:
//
//        preserve
//        use su_id VARNAME using "$datadir/nshap_w1_core.dta", clear
//        rename VARNAME xcand           // generic name for the code below
//        tempfile cand
//        save "`cand'"
//        restore
//        merge m:1 su_id using "`cand'", keep(match master) nogen
//        label variable xcand "..."
//
//    (Use c.xcand if continuous, i.xcand if categorical, in the models.)
//
// 3. RUN the two checks, exactly like (A) and (B) above:
//        * covariate:  mixed cogz c.years##c.alters_base <xcand> ...
//        * moderator:  mixed cogz c.years##c.alters_base ///
//                          c.alters_base##<xcand> ...
//                      testparm <the interaction term>
//
// 4. DECIDE based on your causal reasoning + the results, and record the
//    decision (a covariate stays in the adjusted model; a moderator means
//    you report/stratify the interaction).
//========================================================================

//========================================================================
// CANDIDATE: network persistence (W1->W2 carryover)
//
// The persistence measure is built + saved by network-persistence.do
// (run it first so network_persistence.dta exists). We use
// prop_carryover_w2 (proportion of W2 confidants carried over from W1),
// the cleaner-referenced of the two carryover measures.
//
// *** TEMPORALITY CAVEAT (same as network-persistence.do): persistence is
// a BETWEEN-wave quantity measured over W1->W2, not a baseline value like
// alters_base. Treating it as a covariate/moderator of the baseline size
// effect is provisional -- a first look to take to the meeting. ***
//
// Note on framing: as a MODERATOR the question is natural -- "does the
// effect of baseline network SIZE depend on how STABLE the network is?".
// As a COVARIATE (confounder) it is less natural, since persistence is
// not clearly upstream of baseline size; run it, but interpret with that
// in mind.
//========================================================================
merge m:1 su_id using "$datadir/network_persistence.dta", ///
    keepusing(prop_carryover_w2) keep(match master) nogen

//---- (A) persistence as a COVARIATE (main effect) ----
display as text _newline "=== (A) prop_carryover_w2 as covariate (main effect) ==="
mixed cogz c.years##c.alters_base c.prop_carryover_w2 ///
    || id: years, cov(unstructured)
estimates store cov_pers

estimates table ref cov_pers, b(%9.3f) se ///
    keep(years alters_base c.years#c.alters_base) ///
    title("Confounder check: alters_base effect before vs after adjusting for persistence")

//---- (B) persistence as a MODERATOR (interaction with network size) ----
// c.alters_base##c.prop_carryover_w2 gives both main effects + their
// interaction; the interaction is the moderation test: does the
// size-cognition association depend on network stability?
display as text _newline "=== (B) prop_carryover_w2 as moderator (interaction) ==="
mixed cogz c.years##c.alters_base c.alters_base##c.prop_carryover_w2 ///
    || id: years, cov(unstructured)

// single-df test of the moderation term (both continuous, so one coef)
testparm c.alters_base#c.prop_carryover_w2

log close
