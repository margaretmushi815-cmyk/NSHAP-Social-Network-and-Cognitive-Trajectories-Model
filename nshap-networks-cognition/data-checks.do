// data-checks.do
//
// Running log of exploratory/verification checks on the NSHAP three-wave
// cognition + social network sample (built by three-wave-overlap.do).
// Paste commands here as you run them interactively -- via the Review
// pane's "Send to Do-file Editor" -- so there's a permanent record of
// every check for the write-up / peer review.

version 14

log using "data-checks.log", replace text

// EDIT this to match the path used in three-wave-overlap.do -- globals
// don't carry over between separate Stata sessions, so it needs to be
// set again here.
if "$datadir"=="" global datadir "/path/to/your/nshap/data"

use "$datadir/three_wave_flags.dta", clear

// ---- add new checks below this line ----


// ---- add new checks above this line ----

log close
