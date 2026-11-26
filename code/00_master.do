* Run from the repository root: do code/00_master.do [analysis|full|rebuild]
args mode
if "`mode'" == "" local mode "analysis"
if !inlist("`mode'", "analysis", "full", "rebuild") {
    display as error "Mode must be analysis, full, or rebuild."
    exit 198
}
global root "`c(pwd)'"
confirm file "$root/code/04_statistical_analysis.do"
set more off
capture mkdir "$root/work"
capture mkdir "$root/work/2017_2018"
capture mkdir "$root/work/2021_2023"
capture mkdir "$root/output"
capture mkdir "$root/output/logs"
capture log close replication
log using "$root/output/logs/`mode'.log", text replace name(replication)
display "Stata version: " c(stata_version)
display "Operating system: " c(os)
local original_type "`c(type)'"
display "Initial storage type for new numeric variables: " c(type)
global analysis_data "$root/data/processed/final_two_cycles.dta"
capture noisily {
    if "`mode'" != "rebuild" {
        do "$root/code/00_check_dependencies.do"
    }
    if inlist("`mode'", "full", "rebuild") {
        * Match the precision of the author's supplied datasets.
        set type double
        display "Rebuild storage type: " c(type)
        do "$root/code/01_cleaning_2017_2018.do"
        do "$root/code/02_cleaning_2021_2023.do"
        global analysis_data "$root/work/2021_2023/final_two_cycles.dta"
    }
    if "`mode'" != "rebuild" {
        confirm file "$analysis_data"
        do "$root/code/04_statistical_analysis.do" "$analysis_data" "$root/output/`mode'"
    }
}
local run_rc = _rc
if inlist("`mode'", "full", "rebuild") set type `original_type'
if `run_rc' == 0 {
    display "Entry completed."
}
else {
    display as error "Entry stopped with return code `run_rc'. Inspect this log."
}
log close replication
cd "$root"
exit `run_rc'
