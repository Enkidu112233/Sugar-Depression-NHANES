import sasxport5 "$root/data/raw/2017_2018/BMX_J.xpt", clear
save "$root/work/2017_2018/BMX_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DEMO_J.xpt", clear
save "$root/work/2017_2018/DEMO_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DPQ_J.xpt", clear
save "$root/work/2017_2018/DPQ_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DR1IFF_J.xpt", clear
save "$root/work/2017_2018/DR1IFF_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DR2IFF_J.xpt", clear
save "$root/work/2017_2018/DR2IFF_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DR1TOT_J.xpt", clear
save "$root/work/2017_2018/DR1TOT_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DR2TOT_J.xpt", clear
save "$root/work/2017_2018/DR2TOT_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/SLQ_J.xpt", clear
save "$root/work/2017_2018/SLQ_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/FSQ_J.xpt", clear
save "$root/work/2017_2018/FSQ_J.dta", replace

import sasxport5 "$root/data/raw/2017_2018/DIQ_J.xpt", clear
save "$root/work/2017_2018/DIQ_J.dta", replace


cd "$root/work/2017_2018"
* Construct PHQ-9 and the sleep-excluded PHQ score used in sleep mediation.
* Require valid responses to all nine items for PHQ-9.
use DPQ_J.dta, clear
isid seqn

local items dpq010 dpq020 dpq030 dpq040 dpq050 ///
            dpq060 dpq070 dpq080 dpq090

foreach item of local items {
    replace `item' = 0 if abs(`item') < 1e-12
    replace `item' = . if !inlist(`item', 0, 1, 2, 3)
}

egen byte phq_n = rownonmiss(`items')
egen double phq9 = rowtotal(`items') if phq_n == 9

* Exclude the sleep item while retaining the sample with all nine valid responses.
gen double phq8 = phq9 - dpq030 if phq_n == 9

assert missing(phq9) & missing(phq8) if phq_n != 9
assert inrange(phq9, 0, 27) & inrange(phq8, 0, 24) if phq_n == 9

label variable phq9 "PHQ-9 total (nine valid items)"
label variable phq8 "PHQ-9 total excluding sleep item (not standard PHQ-8)"

keep seqn phq9 phq8
save mental_final.dta, replace


* Construct exposure variables.
* Day 2: keep reliable recalls with nonmissing sugar and energy.
use DR2TOT_J.dta, clear
keep seqn dr2drstz dr2tsugr dr2tkcal
isid seqn

keep if dr2drstz == 1 & !missing(dr2tsugr, dr2tkcal)
drop dr2drstz
rename dr2tsugr day2_sugar

tempfile day2
save "`day2'"

* Day 1: keep reliable recalls with positive Day 1 weights.
use DR1TOT_J.dta, clear
keep seqn dr1drstz dr1tsugr dr1tkcal wtdrd1 wtdr2d
isid seqn

keep if dr1drstz == 1 & ///
    !missing(dr1tsugr, dr1tkcal, wtdrd1) & wtdrd1 > 0

rename dr1tsugr day1_sugar

* Keep participants with valid Day 1 data only as well.
merge 1:1 seqn using "`day2'", keep(master match)

* Require a Day 2 match and positive two-day weights for two-day measures.
gen byte valid_two = _merge == 3 & ///
    !missing(wtdr2d) & wtdr2d > 0

gen double avg_sugar = (day1_sugar + day2_sugar)/2 if valid_two
gen double avg_energy = (dr1tkcal + dr2tkcal)/2 if valid_two

foreach v in day2_sugar dr2tkcal wtdr2d {
    replace `v' = . if !valid_two
}

assert !missing(day1_sugar, dr1tkcal, wtdrd1) & wtdrd1 > 0
assert missing(avg_sugar, avg_energy, wtdr2d) == !valid_two

label variable avg_sugar "Mean total sugar over two reliable recalls (g/day)"
label variable avg_energy "Mean total energy over two reliable recalls (kcal/day)"

keep seqn day2_sugar dr2tkcal day1_sugar dr1tkcal ///
    wtdr2d wtdrd1 avg_sugar avg_energy

order seqn day2_sugar dr2tkcal day1_sugar dr1tkcal ///
    wtdr2d wtdrd1 avg_sugar avg_energy

save nutrition_final.dta, replace

* Covariates.
use DEMO_J.dta, clear
keep seqn dmdeduc2 dmdhhsiz indfmpir riagendr ridageyr sddsrvyr ridreth3 sdmvstra sdmvpsu
rename riagendr gender
rename ridageyr age
rename indfmpir pir      // Family income-to-poverty ratio.
rename dmdeduc2 edu
rename dmdhhsiz famsize
rename sddsrvyr cycle
rename ridreth3 race
isid seqn
assert cycle == 10
save demo_final.dta, replace

* BMI and sleep measures.
use BMX_J.dta, clear
keep seqn bmxbmi
rename bmxbmi bmi
save bmi_final.dta, replace
use SLQ_J.dta, clear
keep seqn sld012
rename sld012 sleep
save sleep_final.dta, replace
* Food security.
use FSQ_J.dta, clear
keep seqn fsdad
save fsq_final.dta, replace
* Diabetes.
use DIQ_J.dta, clear
keep seqn diq010
save diq_final.dta, replace

* Use the demographic master file to define the set of participants in the final merge.
use demo_final.dta, clear
local demo_n = _N

merge 1:1 seqn using mental_final.dta, keep(master match) nogen
merge 1:1 seqn using nutrition_final.dta, keep(master match) nogen
merge 1:1 seqn using sleep_final.dta, keep(master match) nogen
merge 1:1 seqn using bmi_final.dta, keep(master match) nogen
merge 1:1 seqn using fsq_final.dta, keep(master match) nogen
merge 1:1 seqn using diq_final.dta, keep(master match) nogen

assert _N == `demo_n'
isid seqn

save 17_18final_analysis_data.dta, replace