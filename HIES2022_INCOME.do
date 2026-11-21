*==============================================================================*
*      HIES 2022  —  HOUSEHOLD YEARLY INCOME ESTIMATION                        *
*      single-file version                                                     *
*                                                                              *
*      income = wage/salary + net agriculture + enterprise + transfers         *
*      everything on a 12-month basis, everything merged onto the 14,395       *
*      household roster in HH_SEC_1A                                           *
*==============================================================================*
*  Author : Atikur Rahman, White Globe Initiative                              *
*           https://orcid.org/0009-0000-2936-819X                              *
*  Repo   : see README.md for method, results and how to run                   *
*  Tested : StataMP 16.1 (runs on Stata 14+)                                   *
*  Licence: MIT (code only; HIES microdata belong to BBS)                      *
*==============================================================================*

clear all
set more off
set varabbrev off

*--- SET THESE TWO PATHS BEFORE RUNNING ---------------------------------------
* raw : folder holding the original HIES 2022 files (HH_SEC_1A.dta, HH_SEC_4A.dta,
*       ... , weight_final_2022.dta). The data are NOT in this repository; get
*       them from the Bangladesh Bureau of Statistics (BBS).
* out : any folder where results may be written. It is created if missing.
global raw  "C:/path/to/HIES-2022"
global out  "C:/path/to/hies2022-income-output"

global work "$out/work"
capture mkdir "$out"
capture mkdir "$work"

capture confirm file "$raw/HH_SEC_1A.dta"
if _rc {
    di as error "HH_SEC_1A.dta not found in $raw -- set global raw at the top of this file"
    exit 601
}

capture log close _all
log using "$out/hies2022_income.log", replace text

di as text _n "{hline 70}"
di as result "HIES 2022 household yearly income"
di as text "Run: `c(current_date)' `c(current_time)'"
di as text "{hline 70}"

* no switches in this version. the four judgement calls are hardcoded to the
* signed-off headline, and each alternative is just another named variable:
*     D1 crop   = net of in-kind rent/wages, seed, feed, waste
*     D2 floor  = yes, only for households with costs but no output
*     D3 meat   = keep meat and live animals both
*     D4 salary = gross
* part F prints all four alternatives side by side.


*==============================================================================*
* PART A — WAGE AND SALARY                                     HH_SEC_4A
*==============================================================================*

di as text _n "--- A. wage and salary ---"

use "$raw/HH_SEC_4A.dta", clear
drop if missing(PSU) | missing(HHID)

* employment status: Q7 if agriculture, Q8 if not. same code list both columns.
*   1 day labourer, 4 employee -> Part B wage questions, counted here
*   2 self employed, 3 employer -> counted in section 5 or section 7 instead
gen byte status = s4aq07
replace  status = s4aq08 if s4aq06 == 2
qui count
local rows = r(N)
keep if status == 1 | status == 4
di as text "   activities: `rows'   kept (day labourer + employee): " _N

* days worked over the year = days per month x months worked
gen double dayyear = s4aq03 * s4aq02

* daily-rated workers. s4bq10c is the reported average daily wage.
gen double wage_cash_annual   = s4bq10c * dayyear if s4bq09 == 1
gen double wage_inkind_annual = s4bq13b * dayyear if s4bq09 == 1 & s4bq11 == 1

* salaried workers. x months actually worked, not x 12.
* s4bq17 is already a 12-month total, so it is added as it is.
gen double salary_gross_annual  = s4bq15 * s4aq02 if s4bq09 == 2
gen double salary_net_annual    = s4bq16 * s4aq02 if s4bq09 == 2
gen double salary_inkind_annual = s4bq17          if s4bq09 == 2

mvencode wage_cash_annual wage_inkind_annual salary_gross_annual ///
         salary_net_annual salary_inkind_annual, mv(0) override

gen double salary_cash_annual = salary_gross_annual

egen double wage_salary_income_annual = rowtotal(wage_cash_annual ///
     wage_inkind_annual salary_cash_annual salary_inkind_annual)

* checks
qui count if s4bq09 == 1
di as text "   daily-rated                 : " r(N)
qui count if s4bq09 == 1 & missing(s4bq10c)
di as text "     s4bq10c missing           : " r(N) "   (expect 0)"
qui count if s4bq09 == 2
di as text "   salaried                    : " r(N)
qui count if missing(s4bq09)
di as text "   s4bq09 missing              : " r(N) "   (expect 0)"

* activities -> persons -> households in one collapse
collapse (sum) wage_cash_annual wage_inkind_annual salary_cash_annual    ///
               salary_gross_annual salary_net_annual salary_inkind_annual ///
               wage_salary_income_annual                                  ///
         (count) n_wage_activities = status, by(PSU HHID)

label var wage_salary_income_annual "COMPONENT A: wage and salary income (Tk/yr)"
save "$work/A_wage.dta", replace
di as text "   households with wage income : " _N


*==============================================================================*
* PART B — NET AGRICULTURE                          7B 7C1 7C2 7C3 7C4 7E 7D
*==============================================================================*

di as text _n "--- B. agriculture ---"

*--- B1 crops. s7bq04a = kg produced, s7bq04b = price per kg -------------------
use "$raw/HH_SEC_7B.dta", clear
drop if missing(PSU) | missing(HHID)
mvencode s7bq04a s7bq04b s7bq05 s7bq06 s7bq07 ///
         s7bq08a s7bq08b s7bq08c s7bq08d s7bq08e s7bq08f, mv(0) override

* the form prints 4 = 5 + 6 + 7 + 8. check it before trusting the split.
egen double alluses = rowtotal(s7bq08a s7bq08b s7bq08c s7bq08d s7bq08e s7bq08f)
gen byte okcrop = abs(s7bq04a - (s7bq05 + s7bq06 + s7bq07 + alluses)) < 0.5
sum okcrop, meanonly
di as text "   crop identity 4=5+6+7+8 holds in " %5.2f r(mean)*100 "% of rows"

* counted as income : 05 consumed, 06 sold, 07 stock, 08f other
* not counted       : 08a landlord share and 08b in-kind wages (both are costs)
*                     08c seed and 08d feed (inputs, come back as later output)
*                     08e waste (never realised)
egen double kg_income = rowtotal(s7bq05 s7bq06 s7bq07 s7bq08f)

gen double crop_income_net   = kg_income * s7bq04b
gen double crop_income_gross = s7bq04a   * s7bq04b

collapse (sum) crop_income_net crop_income_gross, by(PSU HHID)
save "$work/B1_crop.dta", replace

*--- B2 livestock. all taka columns are totals, so no multiplying -------------
* Q02B owned now is wealth, left out. Q03B born/bought out, Q04B died/sold and
* Q05B consumed in. births cannot be told from purchases in this data, nor
* deaths from sales — that limitation belongs in the write-up.
use "$raw/HH_SEC_7C1.dta", clear
drop if missing(PSU) | missing(HHID)
mvencode S7C1Q03B S7C1Q04B S7C1Q05B, mv(0) override
qui count if S7C1Q00 == 210
di as text "   7C1 summary rows (code 210) : " r(N) "   (expect 0)"

gen double livestock_income  = S7C1Q04B + S7C1Q05B - S7C1Q03B
gen double animal_disposals  = S7C1Q04B + S7C1Q05B
collapse (sum) livestock_income animal_disposals, by(PSU HHID)
gen byte has_animal_disposal = animal_disposals > 0
save "$work/B2_livestock.dta", replace

*--- B3 livestock products. Q6 only; Q7 and Q8 just split Q6 ------------------
use "$raw/HH_SEC_7C2.dta", clear
drop if missing(PSU) | missing(HHID)
replace S7C2Q06B = 0 if missing(S7C2Q06B)
qui count if S7C2Q00 == 220
di as text "   7C2 summary rows (code 220) : " r(N) "   (expect 0)"

gen double animal_product_all  = S7C2Q06B
gen double animal_product_meat = S7C2Q06B * inlist(S7C2Q00, 211, 212, 213)
collapse (sum) animal_product_all animal_product_meat, by(PSU HHID)
save "$work/B3_products.dta", replace

*--- B4 fish. Q10 only -------------------------------------------------------
use "$raw/HH_SEC_7C3.dta", clear
drop if missing(PSU) | missing(HHID)
replace S7C3Q10B = 0 if missing(S7C3Q10B)
qui count if S7C3Q00 == 230
di as text "   7C3 summary rows (code 230) : " r(N) "   (expect 0)"
gen double fisheries_income = S7C3Q10B
collapse (sum) fisheries_income, by(PSU HHID)
save "$work/B4_fish.dta", replace

*--- B5 forestry. Q15 sold + Q16 consumed. trees owned = wealth, left out -----
use "$raw/HH_SEC_7C4.dta", clear
drop if missing(PSU) | missing(HHID)
replace S7C4Q15 = 0 if missing(S7C4Q15)
replace S7C4Q16 = 0 if missing(S7C4Q16)
qui count if S7C4Q00 == 240
di as text "   7C4 summary rows (code 240) : " r(N) "   (expect 0)"
gen double forestry_income = S7C4Q15 + S7C4Q16
collapse (sum) forestry_income, by(PSU HHID)
save "$work/B5_forest.dta", replace

*--- B6 farm asset rental. Q04 only. buy/sell are capital, left out -----------
use "$raw/HH_SEC_7E.dta", clear
drop if missing(PSU) | missing(HHID)
replace S7EQ04 = 0 if missing(S7EQ04)
gen double agri_rental_income = S7EQ04
collapse (sum) agri_rental_income, by(PSU HHID)
save "$work/B6_rental.dta", replace

*--- B7 input costs. netted once at household level, not per crop -------------
use "$raw/HH_SEC_7D.dta", clear
drop if missing(PSU) | missing(HHID)
replace S7DQ03B = 0 if missing(S7DQ03B)
qui count if S7DQ01 == 330
di as text "   7D summary rows (code 330)  : " r(N) "   (expect 0)"
gen double agri_input_costs = S7DQ03B
collapse (sum) agri_input_costs, by(PSU HHID)
save "$work/B7_costs.dta", replace

*--- put B together on the roster --------------------------------------------
use "$raw/HH_SEC_1A.dta", clear
drop if missing(PSU) | missing(HHID)
keep PSU HHID

merge 1:1 PSU HHID using "$work/B1_crop.dta",      nogen
merge 1:1 PSU HHID using "$work/B2_livestock.dta", nogen
merge 1:1 PSU HHID using "$work/B3_products.dta",  nogen
merge 1:1 PSU HHID using "$work/B4_fish.dta",      nogen
merge 1:1 PSU HHID using "$work/B5_forest.dta",    nogen
merge 1:1 PSU HHID using "$work/B6_rental.dta",    nogen
merge 1:1 PSU HHID using "$work/B7_costs.dta",     nogen

* blank after the merge means the household simply has no farm, so it is zero
mvencode _all, mv(0) override

gen double crop_income = crop_income_net

gen double farm_output        = crop_income + livestock_income + animal_product_all ///
                              + fisheries_income + forestry_income + agri_rental_income
gen double farm_output_nomeat = farm_output - animal_product_meat * has_animal_disposal

gen double agri_raw        = farm_output        - agri_input_costs
gen double agri_raw_nomeat  = farm_output_nomeat - agri_input_costs

* a real farm loss is kept. but costs with literally no recorded output is a
* reporting gap, not a loss, so only those households are floored at zero.
gen byte flag_agri_costs_no_output = agri_input_costs > 0 & farm_output <= 0

gen double agri_income_annual = agri_raw
replace    agri_income_annual = 0 if flag_agri_costs_no_output == 1

gen double agri_income_alt = agri_raw_nomeat
replace    agri_income_alt = 0 if flag_agri_costs_no_output == 1

gen byte flag_neg_agri = agri_income_annual < 0

label var agri_income_annual "COMPONENT B: net agricultural income (Tk/yr)"
qui count if flag_agri_costs_no_output == 1
di as text "   costs but no output         : " r(N)
qui count if flag_neg_agri == 1
di as text "   negative net agriculture    : " r(N)

save "$work/B_agriculture.dta", replace


*==============================================================================*
* PART C — NON-FARM ENTERPRISE                                 HH_SEC_05
*==============================================================================*

di as text _n "--- C. enterprise ---"

use "$raw/HH_SEC_05.dta", clear
drop if missing(PSU) | missing(HHID)
mvencode s5q13 s5q14 s5q15 s5q16 s5q17 s5q18 s5q19 s5q20, mv(0) override

* the form itself prints  net = 13 - (14+15+16+17+18+19).  check s5q20 matches.
egen double ent_costs = rowtotal(s5q14 s5q15 s5q16 s5q17 s5q18 s5q19)
gen byte okent = abs((s5q13 - ent_costs) - s5q20) < 1
sum okent, meanonly
di as text "   s5q20 = 13-(14..19) in " %5.2f r(mean)*100 "% of enterprises"

* household's share of the profit. q07 first, q06 as backup, else 100.
* out-of-range zeros exist, so test inrange not missing.
gen double share = s5q07
replace    share = s5q06 if !inrange(share, 1, 100)
replace    share = 100   if !inrange(share, 1, 100)

gen double enterprise_income_annual = s5q20 * share / 100

qui count if s5q20 < 0
di as text "   enterprises with a loss     : " r(N) "   (kept, not zeroed)"

* left out: s5q21 capital goods, s5q22 asset sales, s5q23 what the business
* would sell for (that is a valuation, not income)
collapse (sum) enterprise_income_annual (count) n_enterprises = s5q00, by(PSU HHID)
label var enterprise_income_annual "COMPONENT C: enterprise income (Tk/yr)"
save "$work/C_enterprise.dta", replace
di as text "   households with enterprise  : " _N


*==============================================================================*
* PART D — PROPERTY, TRANSFERS, REMITTANCE, SAFETY NET        8B 8C 1C
*==============================================================================*

di as text _n "--- D. property and transfers ---"

*--- D1 section 8B. every item already says "past 12 months", so just add -----
use "$raw/HH_SEC_8B.dta", clear
drop if missing(PSU) | missing(HHID)

egen double property_income       = rowtotal(S8BQ01 S8BQ02)
egen double remit_8b              = rowtotal(S8BQ08 S8BQ09)
egen double other_transfer_income = rowtotal(S8BQ03A S8BQ03B S8BQ03C S8BQ04 ///
                                    S8BQ05 S8BQ06 S8BQ07 S8BQ11 S8BQ12 S8BQ13)
* S8BQ10 is a code for where the money went, not an amount. not used.

collapse (sum) property_income remit_8b other_transfer_income, by(PSU HHID)
save "$work/D1_sec8b.dta", replace
di as text "   8B households               : " _N " of 14,395"

*--- D2 section 8C. amounts cover 2 years, so divide by 2 ---------------------
* S8CQ17A/B/C are goods codes, not taka. never add them.
use "$raw/HH_SEC_8C.dta", clear
drop if missing(PSU) | missing(HHID)
egen double remit_2yr = rowtotal(S8CQ15 S8CQ18)
gen double remit_8c_annual = remit_2yr / 2
collapse (sum) remit_8c_annual (count) n_migrants = S8CQ00, by(PSU HHID)
save "$work/D2_sec8c.dta", replace
di as text "   8C households with migrant  : " _N

*--- D3 section 1C safety net. Q10 is the 12-month figure ---------------------
* Q5 is one payment, Q9 is one entitlement, Q10 is the year. use Q10.
use "$raw/HH_SEC_1C.dta", clear
drop if missing(PSU) | missing(HHID)
egen double ssn_q10 = rowtotal(S1CQ10A S1CQ101D S1CQ102D)
egen double ssn_q9  = rowtotal(S1CQ09A S1CQ091D S1CQ092D)

sum ssn_q10 if ssn_q10 > 0 & ssn_q9 > 0, meanonly
local m10 = r(mean)
local nb  = r(N)
sum ssn_q9  if ssn_q10 > 0 & ssn_q9 > 0, meanonly
local m9 = r(mean)
di as text "   records with both Q9 and Q10: `nb'"
di as text "   mean Q10 " %8.0f `m10' "  vs mean Q9 " %8.0f `m9' ///
           "  ratio " %4.2f `m10'/`m9'

collapse (sum) safetynet_income = ssn_q10 (count) n_ssn_records = S1CQ00, by(PSU HHID)
save "$work/D3_sec1c.dta", replace
di as text "   households on a programme   : " _N

*--- put D together, and settle the two remittance sources -------------------
use "$raw/HH_SEC_1A.dta", clear
drop if missing(PSU) | missing(HHID)
keep PSU HHID

merge 1:1 PSU HHID using "$work/D1_sec8b.dta", nogen
merge 1:1 PSU HHID using "$work/D2_sec8c.dta", nogen
merge 1:1 PSU HHID using "$work/D3_sec1c.dta", nogen
mvencode _all, mv(0) override

* 8B where it is reported, 8C only where 8B is blank. adding both would double
* count the 1,056 households in both; dropping 8C would lose the 945 that are
* only there.
gen double remittance_income = remit_8b
replace    remittance_income = remit_8c_annual if remit_8b == 0 & remit_8c_annual > 0

gen byte flag_remit_source = 0
replace  flag_remit_source = 1 if remit_8b >  0 & remit_8c_annual == 0
replace  flag_remit_source = 2 if remit_8b == 0 & remit_8c_annual >  0
replace  flag_remit_source = 3 if remit_8b >  0 & remit_8c_annual >  0
label define remitsrc 0 "No remittance" 1 "8B only" 2 "8C fallback" 3 "Both (8B used)", replace
label values flag_remit_source remitsrc
tab flag_remit_source

* left out: 8A entirely (asset values and sale proceeds are wealth, not income)
*           8D1/8D2 micro-credit (loans are a liability)
egen double property_transfer_income_annual = rowtotal(property_income ///
     remittance_income other_transfer_income safetynet_income)

label var property_transfer_income_annual "COMPONENT D: property and transfers (Tk/yr)"
save "$work/D_transfers.dta", replace


*==============================================================================*
* PART E — TOTAL
*==============================================================================*

di as text _n "--- E. total ---"

use "$raw/HH_SEC_1A.dta", clear
drop if missing(PSU) | missing(HHID)
keep PSU HHID MEMBER urbrural domain16 ID_01_CODE ID_01_NAME
rename ID_01_CODE division_code
rename ID_01_NAME division_name
di as text "   roster households           : " _N "   (expect 14,395)"

merge 1:1 PSU HHID using "$raw/weight_final_2022.dta", ///
      keepusing(hh_wgt pop_wgt stratum16) nogen

merge 1:1 PSU HHID using "$work/A_wage.dta",         nogen
merge 1:1 PSU HHID using "$work/B_agriculture.dta",  nogen
merge 1:1 PSU HHID using "$work/C_enterprise.dta",   nogen
merge 1:1 PSU HHID using "$work/D_transfers.dta",    nogen

* households with no wage job / no enterprise come out blank -> zero
ds, has(type numeric)
mvencode `r(varlist)', mv(0) override

* 1 = rural, 2 = urban. checked against domain16 parity below.
label define urbrural_lbl 1 "Rural" 2 "Urban", replace
label values urbrural urbrural_lbl
gen byte domodd = mod(domain16, 2)
di as text "   urbrural vs domain16 parity (rural should be odd):"
tab urbrural domodd
drop domodd

egen double hh_income_annual = rowtotal(wage_salary_income_annual ///
     agri_income_annual enterprise_income_annual property_transfer_income_annual)

* same total but with the meat de-duplication, for the sensitivity table
egen double hh_income_annual_altD3 = rowtotal(wage_salary_income_annual ///
     agri_income_alt enterprise_income_annual property_transfer_income_annual)

* dividing by 12 is only for presentation. the measure is the 12-month total.
gen double hh_income_monthly    = hh_income_annual / 12
gen double hh_income_pc_annual  = hh_income_annual / MEMBER
gen double hh_income_pc_monthly = hh_income_annual / (12 * MEMBER)

gen byte flag_zero_income     = hh_income_annual == 0
gen byte flag_negative_income = hh_income_annual <  0

label var hh_income_annual     "Household total income, last 12 months (Tk)"
label var hh_income_monthly    "Household total income per month (Tk)"
label var hh_income_pc_annual  "Per capita income, last 12 months (Tk)"
label var hh_income_pc_monthly "Per capita income per month (Tk)"

xtile income_quintile = hh_income_pc_annual [pw=pop_wgt], nq(5)
xtile income_decile   = hh_income_pc_annual [pw=pop_wgt], nq(10)

svyset PSU [pweight=hh_wgt], strata(stratum16) singleunit(centered)

order PSU HHID MEMBER urbrural domain16 division_code division_name       ///
      hh_wgt pop_wgt hh_income_annual hh_income_monthly                   ///
      hh_income_pc_annual hh_income_pc_monthly                            ///
      wage_salary_income_annual agri_income_annual                        ///
      enterprise_income_annual property_transfer_income_annual

compress
save "$out/hies2022_household_income.dta", replace
di as text "   saved: $out/hies2022_household_income.dta"


*==============================================================================*
* PART F — CHECKS AND EXPORT
*==============================================================================*

di as text _n "{hline 70}"
di as result "PART F. checks"
di as text "{hline 70}"

*--- F1 key and completeness --------------------------------------------------
di as text _n "--- F1 key ---"
di as text "   households : " _N "   (expect 14,395)"
isid PSU HHID
di as text "   isid PSU HHID passed"

di as text _n "--- F2 nothing missing ---"
foreach v of varlist wage_salary_income_annual agri_income_annual ///
        enterprise_income_annual property_transfer_income_annual hh_income_annual {
    qui count if missing(`v')
    di as text "   missing `v' : " r(N)
}

di as text _n "--- F3 weights ---"
qui count if missing(hh_wgt)
di as text "   households with no hh_wgt : " r(N)

di as text _n "--- F4 flags ---"
foreach v of varlist flag_zero_income flag_negative_income flag_neg_agri ///
        flag_agri_costs_no_output {
    qui count if `v' == 1
    di as text "   `v' : " r(N)
}
tab flag_remit_source

*--- F5 the numbers -----------------------------------------------------------
di as text _n "--- F5 unweighted ---"
sum hh_income_annual hh_income_monthly hh_income_pc_annual hh_income_pc_monthly, detail

di as text _n "--- F5b weighted, with standard errors ---"
svy: mean hh_income_annual hh_income_monthly hh_income_pc_annual hh_income_pc_monthly

di as text _n "--- F5c by urban/rural ---"
svy: mean hh_income_monthly, over(urbrural)

di as text _n "--- F5d by division ---"
svy: mean hh_income_monthly, over(division_code)
di as text "   (10 Barishal, 20 Chattogram, 30 Dhaka, 40 Khulna,"
di as text "    45 Mymensingh, 50 Rajshahi, 55 Rangpur, 60 Sylhet)"

di as text _n "--- F5e weighted medians ---"
_pctile hh_income_monthly [pw=hh_wgt], p(50)
di as text "   median household monthly  : " %9.0f r(r1)
_pctile hh_income_pc_monthly [pw=pop_wgt], p(50)
di as text "   median per capita monthly : " %9.0f r(r1)

*--- F6 composition. built by collapse, then read off with [1] ---------------
di as text _n "--- F6 composition (weighted mean, Tk/year) ---"
preserve
    gen byte one = 1
    collapse (mean) wage  = wage_salary_income_annual ///
                    agri  = agri_income_annual        ///
                    ent   = enterprise_income_annual  ///
                    prop  = property_income           ///
                    remit = remittance_income         ///
                    othtr = other_transfer_income     ///
                    ssn   = safetynet_income          ///
                    total = hh_income_annual [pw=hh_wgt], by(one)
    export delimited using "$out/summary_composition.csv", replace

    di as text "   " %-22s "source" %14s "Tk/year" %10s "share"
    foreach v of varlist wage ent agri remit prop othtr ssn {
        di as text "   " %-22s "`v'" %14.0fc `v'[1] %9.1f 100*`v'[1]/total[1] "%"
    }
    di as text "   {hline 46}"
    di as text "   " %-22s "TOTAL" %14.0fc total[1]
    di as result "   mean monthly household income: " %9.0fc total[1]/12
restore

*--- F7 against the published BBS numbers ------------------------------------
di as text _n "--- F7 vs BBS (HIES 2022 report, key findings p.11) ---"
sum hh_income_monthly [aw=hh_wgt], meanonly
local nat = r(mean)
sum hh_income_monthly [aw=hh_wgt] if urbrural == 1, meanonly
local rur = r(mean)
sum hh_income_monthly [aw=hh_wgt] if urbrural == 2, meanonly
local urb = r(mean)
sum hh_income_pc_monthly [aw=hh_wgt], meanonly
local pc = r(mean)

di as text "   " %-22s "" %12s "this run" %12s "BBS" %10s "diff %"
di as text "   " %-22s "national monthly HH" %12.0fc `nat' %12.0fc 32422 %9.1f 100*(`nat'-32422)/32422
di as text "   " %-22s "rural monthly HH"    %12.0fc `rur' %12.0fc 26163 %9.1f 100*(`rur'-26163)/26163
di as text "   " %-22s "urban monthly HH"    %12.0fc `urb' %12.0fc 45757 %9.1f 100*(`urb'-45757)/45757
di as text "   " %-22s "monthly per capita"  %12.0fc `pc'  %12.0fc  7614 %9.1f 100*(`pc'-7614)/7614
di as text ""
di as text "   the gap is what the questionnaire never asks about: regular"
di as text "   pensions have no question, and section 6A never asks an owner"
di as text "   what the house would rent for, so no imputed rent."

*--- F8 the four alternatives -------------------------------------------------
di as text _n "--- F8 sensitivity (weighted mean, Tk/month) ---"

* each alternative is just the headline total with one piece swapped
gen double alt_d1 = hh_income_annual - crop_income_net + crop_income_gross
gen double alt_d4 = hh_income_annual - salary_gross_annual + salary_net_annual
gen double alt_d3 = hh_income_annual_altD3
gen double alt_d2 = hh_income_annual
replace    alt_d2 = hh_income_annual + agri_raw if flag_agri_costs_no_output == 1

foreach v of varlist hh_income_annual alt_d1 alt_d2 alt_d3 alt_d4 {
    sum `v' [aw=hh_wgt], meanonly
    di as text "   " %-40s "`v'" %12.0fc r(mean)/12
}
di as text "   (headline = hh_income_annual;  d1 gross crop, d2 no floor,"
di as text "    d3 meat de-duplicated, d4 net salary)"
drop alt_d1 alt_d2 alt_d3 alt_d4

*--- F9 distribution ----------------------------------------------------------
di as text _n "--- F9 by per capita quintile ---"
mean hh_income_monthly hh_income_pc_monthly [pw=hh_wgt], over(income_quintile)
di as text _n "--- F9b by decile ---"
mean hh_income_pc_monthly [pw=hh_wgt], over(income_decile)

*--- F10 export ---------------------------------------------------------------
di as text _n "--- F10 export ---"

* nolabel so the csv keeps numbers, not words. otherwise urbrural comes out as
* "Rural"/"Urban" and  keep if urbrural == 1  stops working after reimport.
export delimited PSU HHID MEMBER urbrural domain16 division_code division_name ///
    hh_wgt pop_wgt                                                             ///
    wage_salary_income_annual agri_income_annual enterprise_income_annual      ///
    property_transfer_income_annual property_income remittance_income          ///
    other_transfer_income safetynet_income                                     ///
    hh_income_annual hh_income_monthly hh_income_pc_annual hh_income_pc_monthly ///
    income_quintile income_decile                                              ///
    flag_zero_income flag_negative_income flag_neg_agri                        ///
    flag_agri_costs_no_output flag_remit_source                                ///
    using "$out/hies2022_household_income.csv", replace nolabel

preserve
    gen byte one = 1
    collapse (mean) hh_income_monthly hh_income_pc_monthly ///
             (rawsum) n_households = one [pw=hh_wgt], by(urbrural)
    export delimited using "$out/summary_by_urbrural.csv", replace
    list, clean noobs
restore

preserve
    gen byte one = 1
    collapse (mean) hh_income_monthly hh_income_pc_monthly ///
             (rawsum) n_households = one [pw=hh_wgt], by(division_code division_name)
    export delimited using "$out/summary_by_division.csv", replace
    list, clean noobs
restore

di as text _n "   written to $out"
di as text "     hies2022_household_income.dta / .csv"
di as text "     summary_composition.csv"
di as text "     summary_by_urbrural.csv"
di as text "     summary_by_division.csv"
di as text "     hies2022_income.log"
di as text "   step files kept in $work — open them if you want to check a part"

di as result _n "{hline 70}"
di as result "DONE"
di as result "{hline 70}"
log close
