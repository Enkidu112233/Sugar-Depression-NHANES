* NHANES 1127 statistical analysis. Source file supplied by the repository maintainer.
* Use 00_master.do from the repository root to set up dependencies and paths.
* Stata 18. Requires gologit2 and gsvy 3.2.8.
* Upstream extension: https://academicweb.nd.edu/~rwilliam/gologit2/
version 18.0
set more off
args datafile resultdir
if "`datafile'"=="" local datafile "data/processed/final_two_cycles.dta"
if "`resultdir'"=="" local resultdir "output/analysis"
confirm file "`datafile'"
capture which gsvy
if _rc {
    display as error "Install a version of gologit2 supplying gsvy before running this file."
    exit 199
}
capture mkdir "`resultdir'"
use "`datafile'", clear
isid seqn
assert inlist(cycle,10,12)
assert inrange(phq9,0,27) if !missing(phq9)
assert missing(phq8)==missing(phq9)

* Export the statistics used in the revision.
tempname md bs dc fl sa hd
postfile `md' str16 block str24 spec str60 term long n double r2 df b se ll ul p using "`resultdir'/estimates.dta", replace
postfile `bs' str16 spec str12 term long reps double b se lo hi blo bhi using "`resultdir'/bootstrap.dta", replace
postfile `dc' str25 term long n double mean sd min max using "`resultdir'/profile.dta", replace
postfile `fl' int cycle str35 stage long n using "`resultdir'/flow.dta", replace
postfile `sa' int cycle byte included str24 measure long n double value sd using "`resultdir'/selection.dta", replace
postfile `hd' int cycle str22 measure double b using "`resultdir'/cutoffs.dta", replace

capture program drop ap_post
program define ap_post
    args handle block spec term
    local n = e(N_sub)
    local r2 = e(r2)
    local df = e(df_r)
    quietly lincom `term'
    post `handle' ("`block'") ("`spec'") ("`term'") (`n') (`r2') (`df') ///
        (r(estimate)) (r(se)) (r(lb)) (r(ub)) (r(p))
end

capture program drop ap_boot
program define ap_boot
    args handle spec
    tempname pct bc
    matrix `pct' = e(ci_percentile)
    matrix `bc' = e(ci_bc)
    foreach term in total indirect direct {
        local j = cond("`term'"=="total",5,cond("`term'"=="direct",4,3))
        post `handle' ("`spec'") ("`term'") (e(N_reps)) (_b[`term']) (_se[`term']) ///
            (`pct'[1,`j']) (`pct'[2,`j']) (`bc'[1,`j']) (`bc'[2,`j'])
    }
end

**************************************************
* PART 1. Prepare analysis variables
**************************************************

* Retain the original gender coding.
replace gender = 0 if gender == 2

* Define the controls for the fully adjusted model.
local controls gender age edu famsize avg_energy pir i.race

**************************************************
* PART 2. Define analysis samples
**************************************************

capture drop sample_full

gen byte sample_full = ///
    inrange(age,20,44) & ///
    !inlist(edu,7,9) & ///
    !missing(phq9,avg_sugar,gender,age,edu, ///
             famsize,avg_energy,pir,race,cycle, ///
             wtdr2d,sdmvstra,sdmvpsu) & ///
    wtdr2d > 0

* Check sample sizes in each of the two survey cycles.
tab cycle if sample_full == 1

**************************************************
* PART 3. BASELINE
**************************************************

* 3.1 Fit models separately by survey cycle.

levelsof cycle, local(cycles)

foreach c of local cycles {

    preserve

    keep if cycle == `c'

    display "================================"
    display "BASELINE - Cycle `c'"
    display "================================"

    svyset sdmvpsu [pweight=wtdr2d], ///
        strata(sdmvstra) singleunit(centered)

    svy, subpop(sample_full): regress ///
        phq9 avg_sugar `controls'

    ap_post `md' primary `c' avg_sugar
    display "Cycle Sample N = " e(N_sub)

    restore
}

**************************************************
* 3.2 Fit the pooled baseline model.
**************************************************

* The following exploratory specification pools cycles across the pandemic.
* The pooled survey weights have not been officially validated.

capture drop weight_pool strata_pool

gen double weight_pool = wtdr2d/2

egen strata_pool = group(cycle sdmvstra)

svyset sdmvpsu [pweight=weight_pool], ///
    strata(strata_pool) singleunit(centered)

* Include survey cycle indicators in the pooled baseline model.
svy, subpop(sample_full): regress ///
    phq9 avg_sugar `controls' i.cycle

ap_post `md' primary pooled avg_sugar
display "Pooled Sample N = " e(N_sub)

* Keep the original four nested columns in R1 Table 2.
foreach term in avg_sugar gender age edu famsize pir avg_energy _cons {
    ap_post `md' steps 4 `term'
}
forvalues model = 1/3 {
    local step ""
    if `model'==2 local step gender age
    if `model'==3 local step gender age edu famsize
    svy, subpop(sample_full): regress phq9 avg_sugar `step' i.cycle
    foreach term in avg_sugar `step' _cons {
        ap_post `md' steps `model' `term'
    }
}


**************************************************
* PART 4. ROBUSTNESS CHECK
* Use the pooled dataset for the remaining analyses.
**************************************************

*** Robustness 1: LPM

capture drop phq9_binary

gen byte phq9_binary = .
replace phq9_binary = 1 if phq9 >= 10 & !missing(phq9)
replace phq9_binary = 0 if phq9 < 10

svy, subpop(sample_full): regress ///
    phq9_binary avg_sugar `controls' i.cycle
ap_post `md' outcome lpm avg_sugar

*** Robustness 2: Binary Logit

svy, subpop(sample_full): logit ///
    phq9_binary avg_sugar `controls' i.cycle

* Average marginal effects.
ap_post `md' outcome logit avg_sugar
* Standardize within the 20–44 analytic subpopulation, not all survey records.
margins if sample_full == 1, dydx(avg_sugar)
matrix mt = r(table)
post `md' ("outcome") ("ame") ("avg_sugar") (e(N_sub)) (.) (e(df_r)) ///
    (mt[1,1]) (mt[2,1]) (mt[5,1]) (mt[6,1]) (mt[4,1])


*** Robustness 3: Ordered Logit

capture drop phq9_level

gen byte phq9_level = .
replace phq9_level = 0 if inrange(phq9,0,4)
replace phq9_level = 1 if inrange(phq9,5,9)
replace phq9_level = 2 if inrange(phq9,10,14)
replace phq9_level = 3 if inrange(phq9,15,19)
replace phq9_level = 4 if inrange(phq9,20,27)

capture label drop phq9lbl

label define phq9lbl ///
    0 "Minimal depression" ///
    1 "Mild depression" ///
    2 "Moderate depression" ///
    3 "Moderately severe depression" ///
    4 "Severe depression"

label values phq9_level phq9lbl

tab phq9_level if sample_full == 1

svy, subpop(sample_full): ologit ///
    phq9_level avg_sugar `controls' i.cycle, or
ap_post `md' outcome ordered avg_sugar

	
*** Robustness 4: Partial Proportional Odds Logit
gsvy, subpop(sample_full): ///
    gologit2 phq9_level avg_sugar `controls' i.cycle, npl(avg_sugar)
* Four cumulative cutoffs: PHQ-9 >= 5, 10, 15, and 20.
local eqs : coleq e(b)
local eqs : list uniq eqs
local k 5
foreach eq of local eqs {
    ap_post `md' ppo ge`k' [`eq']avg_sugar
    local k = `k' + 5
}
assert `k'==25


**************************************************
* PART 5. HETEROGENEITY ANALYSIS
* Fit subgroup regressions, then test interactions.
* Use the pooled dataset.
**************************************************

* Prerequisites:
* Parts 1 to 4 have run.
* The sample_full variable has been defined.
* The pooled survey design has been declared with svyset.


**************************************************
* 5.1 Diabetes
**************************************************

* Retain the original three groups.
* 1 = Yes
* 2 = No
* 3 = Borderline

tab diq010 if sample_full == 1, missing

* Define the sample for heterogeneity by diabetes status.
capture drop sample_diabetes

gen byte sample_diabetes = ///
    sample_full == 1 & inlist(diq010,1,2,3)


* ---------- Group 1: Diabetes = Yes ----------

capture drop sample_diab1

gen byte sample_diab1 = ///
    sample_diabetes == 1 & diq010 == 1

display "Diabetes Group 1: Yes"

svy, subpop(sample_diab1): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy pir i.race i.cycle
ap_post `md' subgroup diab1 avg_sugar


* ---------- Group 2: Diabetes = No ----------

capture drop sample_diab2

gen byte sample_diab2 = ///
    sample_diabetes == 1 & diq010 == 2

display "Diabetes Group 2: No"

svy, subpop(sample_diab2): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy pir i.race i.cycle
ap_post `md' subgroup diab2 avg_sugar


* ---------- Group 3: Borderline ----------

capture drop sample_diab3

gen byte sample_diab3 = ///
    sample_diabetes == 1 & diq010 == 3

display "Diabetes Group 3: Borderline"

svy, subpop(sample_diab3): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy pir i.race i.cycle
ap_post `md' subgroup diab3 avg_sugar


* ---------- Interaction Test ----------

display "Diabetes Interaction Test"

* Use diq010 == 2 (No) as the reference group.

svy, subpop(sample_diabetes): regress ///
    phq9 c.avg_sugar##ib2.diq010 ///
    gender age edu famsize ///
    avg_energy pir i.race i.cycle

* Difference in coefficients between the Yes and No diabetes groups.
lincom 1.diq010#c.avg_sugar

* Difference in coefficients between the Borderline and No diabetes groups.
lincom 3.diq010#c.avg_sugar

* Joint test of interactions across all groups.
testparm i.diq010#c.avg_sugar

* Marginal slope for sugar intake in each group.
ap_post `md' contrast diab1v2 1.diq010#c.avg_sugar
ap_post `md' contrast diab3v2 3.diq010#c.avg_sugar
quietly testparm i.diq010#c.avg_sugar
post `md' ("joint") ("diab") ("interaction") (e(N_sub)) (.) (r(df_r)) (r(F)) (.) (.) (.) (r(p))
margins diq010, dydx(avg_sugar)


**************************************************
* 5.2 Income
**************************************************

* Retain the original criteria for income groups.

capture drop pir_group

gen byte pir_group = .

replace pir_group = 1 if pir < 1.3
replace pir_group = 2 if ///
    pir >= 1.3 & pir < 3 & !missing(pir)
replace pir_group = 3 if ///
    pir >= 3 & !missing(pir)

tab pir_group if sample_full == 1


* ---------- Group 1: Low Income ----------

capture drop sample_low

gen byte sample_low = ///
    sample_full == 1 & pir_group == 1

display "Low Income Group"

svy, subpop(sample_low): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy i.race i.cycle
ap_post `md' subgroup inc1 avg_sugar


* ---------- Group 2: Middle Income ----------

capture drop sample_middle

gen byte sample_middle = ///
    sample_full == 1 & pir_group == 2

display "Middle Income Group"

svy, subpop(sample_middle): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy i.race i.cycle
ap_post `md' subgroup inc2 avg_sugar


* ---------- Group 3: High Income ----------

capture drop sample_high

gen byte sample_high = ///
    sample_full == 1 & pir_group == 3

display "High Income Group"

svy, subpop(sample_high): regress ///
    phq9 avg_sugar gender age edu famsize ///
    avg_energy i.race i.cycle
ap_post `md' subgroup inc3 avg_sugar


* ---------- Interaction Test ----------

display "Income Interaction Test"

* Use the same specification as the original subgroup models.
* Omit the continuous PIR control when PIR already defines the groups.

svy, subpop(sample_full): regress ///
    phq9 c.avg_sugar##ib1.pir_group ///
    gender age edu famsize ///
    avg_energy i.race i.cycle

* Middle vs Low
lincom 2.pir_group#c.avg_sugar

* High vs Low
lincom 3.pir_group#c.avg_sugar

* Joint test.
testparm i.pir_group#c.avg_sugar

* Slope for sugar intake in each income group.
ap_post `md' contrast inc2v1 2.pir_group#c.avg_sugar
ap_post `md' contrast inc3v1 3.pir_group#c.avg_sugar
quietly testparm i.pir_group#c.avg_sugar
post `md' ("joint") ("inc") ("interaction") (e(N_sub)) (.) (r(df_r)) (r(F)) (.) (.) (.) (r(p))
margins pir_group, dydx(avg_sugar)


**************************************************
* 5.3 Gender
**************************************************

tab gender if sample_full == 1


* ---------- Group 1: Female ----------

capture drop sample_female

gen byte sample_female = ///
    sample_full == 1 & gender == 0

display "Female Group"

svy, subpop(sample_female): regress ///
    phq9 avg_sugar age edu famsize ///
    avg_energy pir i.race i.cycle
ap_post `md' subgroup gender0 avg_sugar


* ---------- Group 2: Male ----------

capture drop sample_male

gen byte sample_male = ///
    sample_full == 1 & gender == 1

display "Male Group"

svy, subpop(sample_male): regress ///
    phq9 avg_sugar age edu famsize ///
    avg_energy pir i.race i.cycle
ap_post `md' subgroup gender1 avg_sugar


* ---------- Interaction Test ----------

display "Gender Interaction Test"

svy, subpop(sample_full): regress ///
    phq9 c.avg_sugar##ib0.gender ///
    age edu famsize avg_energy pir ///
    i.race i.cycle

* Male vs Female
lincom 1.gender#c.avg_sugar

* Slope for sugar intake in each group.
ap_post `md' contrast gender1v0 1.gender#c.avg_sugar
quietly testparm i.gender#c.avg_sugar
post `md' ("joint") ("gender") ("interaction") (e(N_sub)) (.) (r(df_r)) (r(F)) (.) (.) (.) (r(p))
margins gender, dydx(avg_sugar)

**************************************************
* END OF HETEROGENEITY ANALYSIS
**************************************************



**************************************************
* PART 6. EXPLORATORY PATHWAY ANALYSIS
**************************************************

**************************************************
* PATH 1: avg_sugar -> sleep -> phq8
**************************************************

* Define the sample for the sleep analysis.
capture drop sample_sleep

gen byte sample_sleep = ///
    sample_full == 1 & !missing(sleep,phq8)


* =========================================
* 1. Three baseline regression steps.
* =========================================

display "PATH 1 - SLEEP BASIC ANALYSIS"

* Step 1: Total association
svy, subpop(sample_sleep): regress ///
    phq8 avg_sugar ///
    gender age edu famsize avg_energy ///
    pir i.race i.cycle
ap_post `md' sleep phq8 avg_sugar


* Step 2: Path a
svy, subpop(sample_sleep): regress ///
    sleep avg_sugar ///
    gender age edu famsize avg_energy ///
    pir i.race i.cycle
ap_post `md' sleep a avg_sugar


* Step 3: Path b and direct association
svy, subpop(sample_sleep): regress ///
    phq8 avg_sugar sleep ///
    gender age edu famsize avg_energy ///
    pir i.race i.cycle
ap_post `md' sleep phq8_direct avg_sugar
ap_post `md' sleep phq8_direct sleep


* =========================================
* 2. Bootstrap
* =========================================

* Code strata and PSUs separately by survey cycle.
capture drop boot_strata boot_psu

egen boot_strata = group(cycle sdmvstra)
egen boot_psu = group(cycle sdmvstra sdmvpsu)

* Remove any previous definition of the program.
capture program drop med_sleep

* Define the bootstrap program.
program define med_sleep, rclass

    * Path a
    quietly regress sleep avg_sugar ///
        gender age edu famsize avg_energy ///
        pir i.race i.cycle ///
        [pweight=weight_pool] ///
        if sample_sleep == 1

    local a = _b[avg_sugar]

    * Path b and direct association
    quietly regress phq8 avg_sugar sleep ///
        gender age edu famsize avg_energy ///
        pir i.race i.cycle ///
        [pweight=weight_pool] ///
        if sample_sleep == 1

    local b = _b[sleep]
    local cprime = _b[avg_sugar]

    * Total association
    quietly regress phq8 avg_sugar ///
        gender age edu famsize avg_energy ///
        pir i.race i.cycle ///
        [pweight=weight_pool] ///
        if sample_sleep == 1

    local ctotal = _b[avg_sugar]

    * Return the estimates.
    return scalar a = `a'
    return scalar b = `b'
    return scalar indirect = `a' * `b'
    return scalar direct = `cprime'
    return scalar total = `ctotal'

end


* =========================================
* 3. Check the bootstrap program.
* =========================================

med_sleep
return list


* =========================================
* 4. Stratified PSU bootstrap.
* =========================================

preserve

* Keep records with valid survey design information.
keep if !missing(boot_strata,boot_psu,weight_pool)
keep if weight_pool > 0

bootstrap ///
    a=r(a) ///
    b=r(b) ///
    indirect=r(indirect) ///
    direct=r(direct) ///
    total=r(total), ///
    reps(2000) ///
    seed(12345) ///
    cluster(boot_psu) ///
    strata(boot_strata): med_sleep

* Bootstrap confidence intervals.
estat bootstrap, percentile bc
ap_boot `bs' sleep8

restore

**************************************************
* END OF SLEEP PATHWAY
**************************************************




**************************************************
* PATH 2: Adult Food Insecurity -> Sugar -> PHQ-9
* Exploratory analysis of adult food insecurity as a binary measure.
**************************************************

* =========================================
* 1. Define the binary food insecurity variable.
* =========================================

* 0 = full or marginal food security (FSDAD 1 or 2), the reference group.
* 1 = low or very low food security (FSDAD 3 or 4).
* Assign groups only to valid FSDAD values 1 to 4.
capture drop food_insecure
gen byte food_insecure = inlist(fsdad, 3, 4) ///
    if inlist(fsdad, 1, 2, 3, 4)

label define foodinlbl 0 "Food secure" 1 "Food insecure", replace
label values food_insecure foodinlbl

* Restrict the two-day main sample to participants with a valid food security classification.
capture drop sample_food
gen byte sample_food = sample_full == 1 & !missing(food_insecure)

* Check sample counts by food security group and survey cycle.
tab food_insecure if sample_food == 1
tab cycle if sample_food == 1

* =========================================
* 2. Three baseline regression steps.
* =========================================

* Step 1: Food insecurity and PHQ-9 (total association).
svy, subpop(sample_food): regress ///
    phq9 ib0.food_insecure ///
    gender age edu famsize avg_energy pir i.race i.cycle

* Step 2: Food insecurity and sugar intake (path a).
svy, subpop(sample_food): regress ///
    avg_sugar ib0.food_insecure ///
    gender age edu famsize avg_energy pir i.race i.cycle

* Step 3: Food Insecurity + Sugar -> PHQ-9
* Include food insecurity and sugar intake to estimate path b and the direct association.
svy, subpop(sample_food): regress ///
    phq9 ib0.food_insecure avg_sugar ///
    gender age edu famsize avg_energy pir i.race i.cycle

* =========================================
* 3. Create bootstrap sampling variables.
* =========================================

* Include survey cycle in the stratum and PSU identifiers to distinguish units across cycles.
capture drop boot_strata
capture drop boot_psu
egen boot_strata = group(cycle sdmvstra)
egen boot_psu = group(cycle sdmvstra sdmvpsu)

* =========================================
* 4. Define the bootstrap program.
* =========================================

capture program drop med_food
program define med_food, rclass

    * Path a: Food Insecurity -> Sugar
    quietly regress avg_sugar ib0.food_insecure ///
        gender age edu famsize avg_energy pir i.race i.cycle ///
        if sample_food == 1 [pweight=weight_pool]
    local a = _b[1.food_insecure]

    * Path b: Sugar -> PHQ-9
    * Extract the food insecurity coefficient c' after adjusting for sugar intake.
    quietly regress phq9 ib0.food_insecure avg_sugar ///
        gender age edu famsize avg_energy pir i.race i.cycle ///
        if sample_food == 1 [pweight=weight_pool]
    local b = _b[avg_sugar]
    local cprime = _b[1.food_insecure]

    * Total association: Food Insecurity -> PHQ-9
    * Extract the food insecurity coefficient c from the model without sugar intake.
    quietly regress phq9 ib0.food_insecure ///
        gender age edu famsize avg_energy pir i.race i.cycle ///
        if sample_food == 1 [pweight=weight_pool]
    local ctotal = _b[1.food_insecure]

    * Return the path coefficients, indirect association a*b, direct association c', and total association c.
    return scalar a = `a'
    return scalar b = `b'
    return scalar indirect = `a' * `b'
    return scalar direct = `cprime'
    return scalar total = `ctotal'

end

* =========================================
* 5. Bootstrap the comparison of the food-insecure and reference groups.
* =========================================

preserve

* Keep observations with complete survey design information and positive pooled weights.
keep if !missing(boot_strata, boot_psu, weight_pool) & weight_pool > 0

* Fit the model to the original sample and inspect the returned results.
med_food
return list

* Run 2,000 bootstrap replications, resampling PSUs within strata.
bootstrap a=r(a) b=r(b) indirect=r(indirect) ///
    direct=r(direct) total=r(total), ///
    reps(2000) seed(12345) ///
    cluster(boot_psu) strata(boot_strata) ///
    reject(missing(r(indirect))): med_food

* Display percentile bootstrap confidence intervals.
estat bootstrap, percentile

restore

**************************************************
* END OF FOOD SECURITY PATHWAY
**************************************************



**************************************************
* PART 7. Day 1 dietary robustness check
**************************************************

* Retain every participant with a valid Day 1 record for the Day 1 analysis.
* If participants with missing Day 2 records were removed when pooling the data,
* rebuild the dataset using the full Day 1 sample.

capture drop sample_day1

gen byte sample_day1 = ///
    inrange(age,20,44) & ///
    !inlist(edu,7,9) & ///
    !missing(phq9,day1_sugar,gender,age,edu, ///
             famsize,dr1tkcal,pir,race,cycle, ///
             wtdrd1,sdmvstra,sdmvpsu) & ///
    wtdrd1 > 0

* The following is an exploratory pooled Day 1 analysis.
* The weights for pooling cycles across the pandemic require methodological validation.

capture drop weight_day1

gen double weight_day1 = wtdrd1/2

svyset sdmvpsu [pweight=weight_day1], ///
    strata(strata_pool) singleunit(centered)

svy, subpop(sample_day1): regress ///
    phq9 day1_sugar gender age edu ///
    famsize dr1tkcal pir i.race i.cycle
ap_post `md' sensitivity pooled_day1 day1_sugar


**************************************************

* R1 minor: sample flow, selection, energy and extreme sugar checks
**************************************************
gen byte age_ok = inrange(age,20,44)
gen byte phq_ok = age_ok & !missing(phq9)
gen byte diet_ok = phq_ok & !missing(avg_sugar,avg_energy,wtdr2d,sdmvstra,sdmvpsu) & wtdr2d>0
gen byte edu_ok = diet_ok & inrange(edu,1,5)
gen byte other_ok = edu_ok & !missing(gender,age,famsize,pir,race,cycle)
assert other_ok==sample_full
gen byte trim = 0
foreach c in 10 12 {
    quietly count if cycle==`c'
    post `fl' (`c') ("public file") (r(N))
    foreach v in age_ok phq_ok diet_ok edu_ok sample_full sample_day1 {
        quietly count if cycle==`c' & `v'
        local stage "two-day main"
        if "`v'"=="age_ok" local stage "age eligible"
        if "`v'"=="phq_ok" local stage "complete PHQ"
        if "`v'"=="diet_ok" local stage "reliable and weighted two-day"
        if "`v'"=="edu_ok" local stage "valid education"
        if "`v'"=="sample_day1" local stage "one-day sensitivity"
        post `fl' (`c') ("`stage'") (r(N))
    }
    quietly count if cycle==`c' & sample_day1 & !sample_full
    post `fl' (`c') ("eligible Day 1 only") (r(N))

    * Available-case, unweighted comparison within the age-eligible pool.
    * The excluded group includes participants with no dietary weight.
    foreach included in 1 0 {
        local dom "age_ok & cycle==`c' & sample_full==`included'"
        foreach m in age gender famsize edu pir phq9 {
            local valid ""
            if "`m'"=="edu" local valid "& inrange(edu,1,5)"
            quietly summarize `m' if `dom' `valid'
            post `sa' (`c') (`included') ("`m'") (r(N)) (r(mean)) (r(sd))
        }
        quietly count if `dom' & !missing(race)
        local den = r(N)
        foreach v in 1 2 3 4 6 7 {
            quietly count if `dom' & race==`v'
            post `sa' (`c') (`included') ("race_`v'") (`den') (r(N)/`den') (.)
        }
    }
    * Unweighted within-cycle 99th percentiles define the sensitivity domain.
    quietly _pctile avg_sugar if cycle==`c' & sample_full, p(99)
    local q = r(r1)
    post `hd' (`c') ("trim_cutoff") (`q')
    quietly replace trim = (avg_sugar <= `q') if cycle==`c' & sample_full
}

foreach c in 10 12 pooled {
    preserve
    local pw weight_pool
    local st strata_pool
    local period i.cycle
    if "`c'"!="pooled" {
        keep if cycle==real("`c'")
        local pw wtdr2d
        local st sdmvstra
        local period ""
    }
    svyset sdmvpsu [pweight=`pw'], strata(`st') singleunit(centered)
    * Remove total energy as a covariate, not as an eligibility criterion.
    svy, subpop(sample_full): regress phq9 avg_sugar gender age edu famsize pir i.race `period'
    ap_post `md' sensitivity `c'_noenergy avg_sugar
    svy, subpop(trim): regress phq9 avg_sugar `controls' `period'
    ap_post `md' sensitivity `c'_trim avg_sugar
    restore
}

* Existing Table 1: descriptive statistics for the corrected sample.
foreach v in phq9 avg_sugar avg_energy sleep age famsize pir phq9_binary gender {
    quietly summarize `v' if sample_full
    post `dc' ("`v'") (r(N)) (r(mean)) (r(sd)) (r(min)) (r(max))
}
foreach v in fsdad diq010 pir_group edu cycle race phq9_level {
    local valid ""
    if "`v'"=="diq010" local valid "& inlist(diq010,1,2,3)"
    quietly levelsof `v' if sample_full `valid', local(vs)
    quietly count if sample_full & !missing(`v') `valid'
    local den = r(N)
    foreach z of local vs {
        quietly count if sample_full & `v'==`z'
        post `dc' ("`v'_`z'") (`den') (r(N)/`den') (r(N)) (0) (1)
    }
}
foreach h in md bs dc fl sa hd {
    postclose ``h''
}
preserve
foreach tab in estimates bootstrap profile flow selection cutoffs {
    use "`resultdir'/`tab'.dta", clear
    export delimited using "`resultdir'/`tab'.csv", replace
}
restore
display "NHANES 1127 analysis completed."
