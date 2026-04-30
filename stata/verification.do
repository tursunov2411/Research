/* ============================================================
   STATA VERIFICATION SCRIPT
   Purpose: Cross-verify R results using independent software
   Thesis: FDI-Led Industrialisation in Uzbekistan
   ============================================================ */

clear all
set more off
log using "output/logs/stata_verification.log", replace

/* Import processed data from R */
import delimited "data/processed/wb_indicators.csv", clear

/* -------------------------------------------------------
   VERIFY: Structural break test (Uzbekistan only)
   ------------------------------------------------------- */
keep if country_code == "UZB"
xtset year

/* Trend regression with reform dummy */
gen post_reform = (year >= 2017)
gen time_trend  = year - 2010
gen interaction = post_reform * time_trend

reg manuf_va_gdp time_trend post_reform interaction
estimates store model_full

/* Test coefficient on interaction term */
/* Significant positive = manufacturing increasing post-reform */
test interaction

/* -------------------------------------------------------
   VERIFY: FDI composition shift
   ------------------------------------------------------- */
reg fdi_gdp time_trend post_reform interaction
estimates store model_fdi

/* -------------------------------------------------------
   OUTPUT TABLE
   ------------------------------------------------------- */
estimates restore model_full
local manuf_time_b = _b[time_trend]
local manuf_time_se = _se[time_trend]
local manuf_post_b = _b[post_reform]
local manuf_post_se = _se[post_reform]
local manuf_int_b = _b[interaction]
local manuf_int_se = _se[interaction]
local manuf_cons_b = _b[_cons]
local manuf_cons_se = _se[_cons]
local manuf_n = e(N)
local manuf_r2 = e(r2)

estimates restore model_fdi
local fdi_time_b = _b[time_trend]
local fdi_time_se = _se[time_trend]
local fdi_post_b = _b[post_reform]
local fdi_post_se = _se[post_reform]
local fdi_int_b = _b[interaction]
local fdi_int_se = _se[interaction]
local fdi_cons_b = _b[_cons]
local fdi_cons_se = _se[_cons]
local fdi_n = e(N)
local fdi_r2 = e(r2)

file open tbl using "output/tables/stata_verification_table.rtf", write replace
file write tbl "{\rtf1\ansi" _n
file write tbl "\b Table: Stata Verification of R Results\b0\par" _n
file write tbl "Coefficient (standard error)\par" _n
file write tbl "\par" _n
file write tbl "Variable\tab Manufacturing VA\tab FDI GDP\par" _n
file write tbl "Time trend\tab " %9.4f (`manuf_time_b') " (" %9.4f (`manuf_time_se') ")\tab " %9.4f (`fdi_time_b') " (" %9.4f (`fdi_time_se') ")\par" _n
file write tbl "Post reform\tab " %9.4f (`manuf_post_b') " (" %9.4f (`manuf_post_se') ")\tab " %9.4f (`fdi_post_b') " (" %9.4f (`fdi_post_se') ")\par" _n
file write tbl "Interaction\tab " %9.4f (`manuf_int_b') " (" %9.4f (`manuf_int_se') ")\tab " %9.4f (`fdi_int_b') " (" %9.4f (`fdi_int_se') ")\par" _n
file write tbl "Constant\tab " %9.4f (`manuf_cons_b') " (" %9.4f (`manuf_cons_se') ")\tab " %9.4f (`fdi_cons_b') " (" %9.4f (`fdi_cons_se') ")\par" _n
file write tbl "\par" _n
file write tbl "Observations\tab " %9.0f (`manuf_n') "\tab " %9.0f (`fdi_n') "\par" _n
file write tbl "R-squared\tab " %9.4f (`manuf_r2') "\tab " %9.4f (`fdi_r2') "\par" _n
file write tbl "}" _n
file close tbl

log close
