
////////////////////////////////////////////////////////////////////////////////
*********** Code to run the analysis ***************
////////////////////////////////////////////////////////////////////////////////

////// Preparation

***
set more off

* set path (add path here)
*global path="C:/Users/wb560757/OneDrive - WBG/Desktop/Network/Replication_Package_2"

global path = "/Users/quocanhdo/Monash Uni Enterprise Dropbox/Quoc-Anh Do/Project - Network at Sciences Po/QA - Nicolo/Replication_Package/Replication_Package_Mar2025"

cd "$path/Codes/Analysis/"

*** load code for correct clustering
capture which IVdyadic
if _rc == 0 {
    di "IVdyadic already exists on ado-path or in memory"
}
else {
    di "IVdyadic is not included yet"
	do "$path/Codes/Analysis/IVdyadic.ado"
}

*** load code for permutation

do "$path/Codes/Analysis/Permutation.ado" 

*** load data
if "$confidentiality" == "confidential" {
	use "$path/Data/Analysis/work_data_confidential.dta", clear
}
if "$confidentiality" == "public" {
	use "$path/Data/Analysis/work_data_public.dta", clear
}

*** define list of control variables
global Xvar = "SEX FEMALE NAT1 ADM ADPR DEPB REGBAC SERIEBAC DiffDR NOFEE PARI ZIP Paris IDFBAC PRO1"

* define threshold of time taken to respond to questions used to select sample
*get sample of couples were the main dependent variable, the friendship variable, the IV, and the controls are not missing
qui reg ChangePP LUL IG $Xvar 
gen sam=e(sample)
* get 95 percentile of time taken to respond in this sample
sum timepfr_i1 if sam, d
global time_threshold = r(p95)

*** define conditions to be applied to select sample for estimation and deriving statistics
global condition = "sample & uid_i1>uid_i2 & timepfr_i1<=$time_threshold & timepfr_i2<=$time_threshold & IGno_i1~=. & IGno_i2~=. "

*** define sample for analyis
cap drop sample
quietly reg ChangePP LUL DiffPP $Xvar 
gen sample=e(sample)

//------------------------------------------------------------------------------
// TABLES
//------------------------------------------------------------------------------

////// DESCRIPTIVE STATISTICS 

if "$confidentiality" == "confidential" {
	cap cap log close
	log using "$path/Results/LogTable1", replace

	/// TABLE 1

	*** Panel A - requires individual data
	preserve
	use "$path/Data/Raw/base_complete_1314.dta", clear
	foreach var in q4a q4b {
	replace `var'=. if `var'==99
	}
	estpost summarize q4a q4b
	estimates store panel_a_1
	use "$path/Data/Analysis/recall_data.dta", clear
	estpost summarize actual_15
	estimates store panel_a_2
	use "$path/Data/Raw/base_complete_1314_i1.dta", clear
	gen asso=0
	replace asso=1 if q3_1uid_i1!=.
	replace asso=. if q3_1uid_i1==0
	estpost summarize asso
	estimates store panel_a_3
	restore				 


	preserve
	keep if $condition
	bysort uid_i1: gen t=_n
	keep if t==1
	gen asso=0
	replace asso=1 if q3_1uid_i1!=.
	replace asso=. if q3_1uid_i1==0
	estpost summarize polposnow_i1 polpos_i1 polposnow_15_i1 asso
	estimates store panel_a_benchmark
	restore			 
}

*** Panel B: Dyadic Variables  
estpost summarize DiffPPa DiffPP DiffPPa_15 SameSports SameNonSports SameAsso_Type_Pol SameAsso_Type_Ply SameAsso_Type_Iden if uid_i1>uid_i2
estimates store panel_b_full

estpost summarize DiffPPa DiffPP DiffPPa_15 SameSports SameNonSports SameAsso_Type_Pol SameAsso_Type_Ply SameAsso_Type_Iden if $condition
estimates store panel_b_benchmark

* Create the table
if "$confidentiality" == "confidential" {
	esttab panel_a_1 panel_a_2 panel_a_3 panel_a_benchmark using "$path/Results/Table1_panel_a.tex", replace ///
		cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
		title("Panel A: Monadic Dependent Variables") ///
		mtitles("Full Sample" "Benchmark Sample") ///
		label booktabs ///
		addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
				 "while statistics in (2) are computed on the benchmark sample.")
}

esttab panel_b_full panel_b_benchmark using "$path/Results/Table1_panel_b.tex", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
    title("Panel B: Dyadic Dependent Variables") ///
    mtitles("Full Sample" "Benchmark Sample") ///
    label booktabs ///
    addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
             "while statistics in (2) are computed on the benchmark sample.")

cap log close // Table 1
			 		 
////// FIGURE 1 - Distributions of political opinions (based on individual data)		 

if "$confidentiality" == "confidential" {
	cap cap log close
	log using "$path/Results/LogFigure1", replace

	preserve
	use "$path/Data/Raw/base_complete_1314_i1.dta", clear
		
	* Create the histogram with both time periods
	 
	histogram q4b_i1 if  q4a_i1~=., discrete ///
		yline(0.05(0.05)0.30, lcolor(gs14) lpattern(solid) lwidth(vthin)) ///
		lcolor(none) lwidth(thin) fcolor(ltblue) barwidth(0.9) ///
		addplot( ///
			histogram q4a_i1 if q4b_i1~=., discrete ///
				fcolor(gs10) lcolor(dkgray) lwidth(thin) barwidth(0.6) ///
		) ///
		xtitle("Political position") ytitle("Density") ///
		legend(order(1 "Pre-Sciences Po (Aug 2013)" ///
					 2 "Survey time (Mar 2014)") ///
			   position(6) rows(1) size(small)) ///
		scheme(s1mono) plotregion(margin(b+2)) graphregion(color(white))
	* Save the graph
	graph export "$path/Results/Figure1.png", replace width(800) height(600)
	restore			 

	cap log close // Figure 1
}

if "$confidentiality" == "confidential" {
	cap cap log close
	log using "$path/Results/LogTable2", replace
	/// TABLE 2 - Permutation test

	cap program drop W_B_Cat
	program W_B_Cat, rclass
		args varname groupname
		
		tempvar sd_w sd_b sd tagvar ratio gg
		
		bysort `groupname': egen `gg' = count(`varname')

		xi i.`varname', pre(_II_)
		gen `sd_w' = .
		gen `sd_b' = .
		gen `sd' = .
		gen `ratio'=.
		foreach subvarname of varlist _II_* {
			xtsum `subvarname', i(`groupname')
			replace `sd_w' = r(sd_w) if `subvarname'==1
			replace `sd_b' = r(sd_b) if `subvarname'==1
			*replace `sd' = r(sd) if `subvarname'==1
			replace `ratio' = `sd_w'/`sd_b'
		}
		drop _II_*
		egen `tagvar' = tag(`varname')
		sum `ratio' [aw=`gg'] if `tagvar'==1, meanonly
		scalar Ratio = r(mean)
		return scalar W_B_Cat = `=Ratio' // This is the mean of the ratios `SD_W'/`=SD_B' 
	end

	cap program drop W_B_SD
	program W_B_SD, rclass
		args varname groupname 
		cap drop sd_`varname' 
		xtsum `varname', i(`groupname')
		scalar sd_w = r(sd_w)
		scalar sd_b = r(sd_b)
		scalar sd = r(sd)
		return scalar w_b_sd_ratio = sd_w/sd_b // This is the ratio of within standard deviation/between standard deviation
	end

	preserve
	keep if $condition 
	egen tag_i1=tag(uid_i1)

	cap drop sample
	quietly reg DiffPPa LUL DiffPP $Xvar 
	gen sample=e(sample)

	reg polposnow_i1 polpos_i1 if tag_i1==1
	predict resid_i1, resid
	gen Dpolpos_i1 = polposnow_i1 - polpos_i1
	keep if tag_i1==1
	*keep sample Dpolpos_i1 polposnow_i1 resid_i1 polpos_i1 IGno_i1 LettFirst_i1 uid_i1 droits_i1 sex_i1 nat1_i1 nat2_i1 admission_i1 program1_i1 program2_i1 parent1_i1 seriebac_i1 mention_i1 departmentbac_i1 regionbac_i1 Codepostal_adressePR_i1
	keep if IGno_i1~=.


	// Permutation test of group asignment randomness for initial political opinions
	permute IGno_i1 W_SD_Post=r(w_b_sd_ratio) , reps(300) seed(142857): W_B_SD polpos_i1 IGno_i1 


	// Permutation test of group asignment randomness for initial tuition fees
	permute IGno_i1 W_SD_Post=r(w_b_sd_ratio) , reps(300) seed(142857): W_B_SD droits_i1 IGno_i1 

	// Permutation test of group asignment randomness for category variables
	gen admispr_i1 = (admission_i1==1)
	foreach var in sex admispr {
		di ""
		di "Permutation test for " "`var'"
		di ""
		permute IGno_i1 W_SD_Post=r(w_b_sd_ratio), reps(300) seed(142857): W_B_SD `var'_i1 IGno_i1
	}


	foreach var in nat2 admission program1 parent1 seriebac departmentbac regionbac Codepostal_adressePR {
		di ""
		di "Permutation test for " "`var'"
		di ""
		permute IGno_i1 Within_Between_links =r(W_B_Cat), reps(300) seed(142857): W_B_Cat `var'_i1 IGno_i1
	}


	restore
}


cap cap log close
log using "$path/Results/LogTable3", replace
/// TABLE 3 - Balance test

// Panel A
cap drop IGmeet
egen IGmeet = group(IGno_i1 IGno_i2)
reg IG $Xvar if $condition, cluster(IGmeet)
outreg2 using "$path/Results/Table3A.tex", tex replace label addstat(F-stat, e(F)) ctitle(" ") nonotes dec(4)

// Panel B
local first = 1
foreach var of varlist DiffPP $Xvar {
   reg IG `var' if $condition, cluster(IGmeet)
   if `first' == 1 {
       outreg2 using  "$path/Results/Table3B.tex", replace dec(3) keep(`var')
       local first = 0
   }
   else {
       outreg2 using  "$path/Results/Table3B.tex", append dec(3) keep(`var')
   }
}
cap log close


/// Figure 2
if "$confidentiality" == "confidential" {
	cap cap log close
	log using "$path/Results/LogFigure2", replace

	* Panel A
	preserve
	keep if $condition 
	egen tag_i1=tag(uid_i1)

	cap drop sample
	quietly reg DiffPPa LUL DiffPP $Xvar 
	gen sample=e(sample)

	reg polposnow_i1 polpos_i1 if tag_i1==1
	predict resid_i1, resid
	gen Dpolpos_i1 = polposnow_i1 - polpos_i1
	bysort uid_i1: egen DegIG_i1 = sum(LUL) if IGno_i2==IGno_i1
	bysort uid_i1: egen DegNIG_i1 = sum(LUL) if IGno_i2~=IGno_i1
	keep if tag_i1==1
	keep sample DegIG_i1 DegNIG_i1 Dpolpos_i1 polposnow_i1 resid_i1 polpos_i1 IGno_i1 uid_i1
	keep if IGno_i1~=.

	permute IGno_i1 W_B_SD=r(w_b_sd_ratio) , reps(300) seed(1) saving("$path/Data/Intermediate/Permutation2.dta", replace): W_B_SD Dpolpos_i1 IGno_i1
	mat B = r(b)
	sca value = B[1,1]
	mat B = r(p_lower)
	sca p_lower = B[1,1]
	local val : di %3.2f value 
	local p_low : di %3.2f p_lower 
	local legend_string = "Value in the data = `val' (p-value = `p_low')"
	di "`legend_string'"
	use "$path/Data/Intermediate/Permutation2.dta", clear
	kdensity W_B_SD, kernel(gaussian) recast(area) fcolor(ltblue) xscale(range(1.5 3)) addplot(scatteri 0 `=value' 1.5 `=value' "Value in the data", recast(line) lpattern(longdash)) legend(order(1 2 "`legend_string'") position(6) rows(1)) ///
		xtitle(Permuted Groups' Within-Group/Between-Group Standard Deviations) title("Permutation test of Changes in Political Opinions") graphregion(color(white)) bgcolor(white)
	graph save "$path/Results/Permutation_Dpolpos", replace
	graph export "$path/Results/Permutation_Dpolpos.pdf", as(pdf) replace
	restore


	* Panel B
	preserve
	keep if $condition 
	egen tag_i1=tag(uid_i1)

	cap drop sample
	quietly reg DiffPPa LUL DiffPP $Xvar 
	gen sample=e(sample)

	reg polposnow_i1 polpos_i1 if tag_i1==1
	predict resid_i1, resid
	gen Dpolpos_i1 = polposnow_i1 - polpos_i1

	bysort uid_i1: egen DegIG_i1 = sum(LUL) if IGno_i2==IGno_i1
	bysort uid_i1: egen DegNIG_i1 = sum(LUL) if IGno_i2~=IGno_i1
	keep if tag_i1==1
	keep sample DegIG_i1 DegNIG_i1 Dpolpos_i1 polposnow_i1 resid_i1 polpos_i1 IGno_i1 uid_i1
	keep if IGno_i1~=.

	permute IGno_i1 W_B_SD=r(w_b_sd_ratio) , reps(300) seed(1) saving("$path/Data/Intermediate/Permutation1.dta", replace): W_B_SD polposnow_i1 IGno_i1
	mat B = r(b)
	sca value = B[1,1]
	mat B = r(p_lower)
	sca p_lower = B[1,1]
	local val : di %3.2f value 
	local p_low : di %3.2f p_lower 
	local legend_string = "Value in the data = `val' (p-value = `p_low')"
	di "`legend_string'"
	use "$path/Data/Intermediate/Permutation1.dta", clear
	kdensity W_B_SD, kernel(gaussian) recast(area) fcolor(ltblue) xscale(range(1.5 3)) addplot(scatteri 0 `=value' 1.55 `=value', recast(line) lpattern(longdash)) legend(order(1 2 "`legend_string'") position(6) rows(1)) ///
		xtitle(Permuted Groups' Within-Group/Between-Group Standard Deviations) title("Permutation test of Present Political Opinions") graphregion(color(white)) bgcolor(white)
	graph save "$path/Results/Permutation_polposnow", replace
	graph export "$path/Results/Permutation_polposnow.pdf", as(pdf) replace
	restore

	cap log close // Figure 2
}

	
////// 

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable4A", replace 

// TABLE 4.A: Effect of integration group on movement of political opinion


* run specification (1)
ivreg2 CONV2 IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONV2 IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4A.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONVS2 IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVW IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 DIVS IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVS IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 COMOV IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic COMOV IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* close log file
cap log close




* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable4B", replace

/// TABLE 4B: IV spec - Effect of integration group on movement of political opinion

* run specification (1)
ivreg2 CONV2 (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONV2 IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONVS2 IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVW IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 DIVS (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVS IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (5)
ivreg2 COMOV (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic COMOV IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage
* run specification (same for the five second stage specifications)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table4B.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* close log file
cap log close


//-------

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable5A", replace
// TABLE 5A: Same Integration Group and Changes in Political Opinion

* run specification (1)
ivreg2 ChangePP IG $Xvar if $condition & CONV2==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5A.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (2)
ivreg2 ChangePP IG $Xvar if $condition & DIVW==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (3)
ivreg2 ChangePP IG $Xvar if $condition & COMOV==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 ChangePP IG $Xvar if $condition, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* close log file
cap log close




* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable5B", replace
// TABLE 5B: IV spec - Same Integration Group and Changes in Political Opinion

* run specification (1)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & CONV2==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (2)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DIVW==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (3)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & COMOV==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) DiffAlphaRank $Xvar if $condition, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG DiffAlphaRank $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
local pval = e(pvalues)[1,1]
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 ChangePP (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (7)
ivreg2 ChangePP IG $Xvar if $condition & CloseAlphaRank==1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* close log file
cap cap log close




* close previous log file
cap cap log close
* open new lof file
log using "$path/Results/LogTable5B_1ST", replace
// TABLE 5B 1st stage: IV spec 1st stage - Same Integration Group and Changes in Political Opinion

* run specification (1)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (2)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (3)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (4)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (5)
ivreg2 IG SameAlphaHypGroupIV DiffAlphaRank $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV DiffAlphaRank $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
local pval = e(pvalues)[1,1]
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (6)
ivreg2 IG AlphaDistIV $Xvar DiffAlphaRankExt if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG AlphaDistIV $Xvar DiffAlphaRankExt if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table5B_1ST.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

* close log file
cap log close


* close previous log file
cap cap log close
* open new lof file
log using "$path/Results/LogTable6", replace

// TABLE 6: Descriptive statistics of friendships
*** Panel A
* probability of correct answer: meeting
cap drop correct_meet
gen correct_meet = 0 if LAL==1
replace correct_meet = 1 if LAL==1 & meet_i1==meet_i2 
* probability of correct answer: time
cap drop correct_time
gen correct_time = 0 if LAL==1
replace correct_time = 1 if LAL==1 & time_i1==time_i2 
* probability of correct answer: activity
cap drop correct_activity
gen correct_activity = 0 if LAL==1
replace correct_activity = 1 if LAL==1 & activity_i1==activity_i2 
* probability of correct answer: strength
cap drop correct_strength
gen correct_strength = 0 if LAL==1
replace correct_strength = 1 if LAL==1 & strength_i1==strength_i2  
* full sample
estpost summarize fr_i1 rec correct_meet correct_time correct_activity correct_strength if uid_i1>uid_i2
estimates store panel_a_full
* benchmark sample
estpost summarize fr_i1 rec correct_meet correct_time correct_activity correct_strength if $condition
estimates store panel_a_benchmark
* Create the table
esttab panel_a_full panel_a_benchmark using "$path/Results/Table6_panel_a.tex", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
    title("Panel B: Dyadic Dependent Variables") ///
    mtitles("Full Sample" "Benchmark Sample") ///
    label booktabs ///
    addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
             "while statistics in (2) are computed on the benchmark sample.")

if "$confidentiality" == "confidential" {			 
	*** Panel B
	sum degree_i1 if uid_i1>uid_i2, d
	scalar avg_degree = `r(mean)'
	scalar var_degree = `r(Var)'
	scalar med_degree = `r(p50)'
	scalar max_degree = `r(max)'
	scalar min_degree = `r(min)'

	sum path if uid_i1>uid_i2, d
	scalar diameter = `r(max)'
	scalar avg_path = `r(mean)'

	sum eigen_bonacich_cent_i1 if uid_i1>uid_i2, d
	scalar avg_eigen = `r(mean)'
	scalar std_eigen = `r(sd)'

	matrix scalars_matrix = (avg_degree \ var_degree \ med_degree \ max_degree\ min_degree \ diameter \ avg_path \ avg_eigen \ std_eigen)
	matrix rownames scalars_matrix = Mean_degree Variance_degree Median_degree Max_degree Min_degree Diameter Average_pathlength Avg_eigen_centrality StdErr_eigen_centrality

	estout matrix(scalars_matrix) using "$path/Results/Table6_panel_b.tex", ///
		style(tex) replace ///
		mlabels(none) collabels(none) ///
		prehead("\begin{tabular}{lr}" "\toprule") ///
		posthead("\midrule") ///
		prefoot("\bottomrule") ///
		postfoot("\end{tabular}")
}

*** Panel C
	* mere relationship
cap drop LUL1
gen LUL1 = 0
replace LUL1 = 1 if LULint==1
	* firendship link
cap drop LUL2
gen LUL2 = 0
replace LUL2 = 1 if LULint==2
	* close firendship
cap drop LUL3
gen LUL3 = 0
replace LUL3 = 1 if LULint==3
	* very close friendship
cap drop LUL4
gen LUL4 = 0
replace LUL4 = 1 if LULint==4

cap drop path1 path2 path3
gen path1 = (path==1)
gen path2 = (path==2)
gen path3 = (path==3)

* full sample
estpost summarize LUL path1 path2 path3 LUL1 LUL2 LUL3 LUL4 IG if uid_i1>uid_i2
estimates store panel_c_full
* benchmark sample
estpost summarize LUL path1 path2 path3 LUL1 LUL2 LUL3 LUL4 IG if $condition
estimates store panel_c_benchmark
* Create the table
esttab panel_c_full panel_c_benchmark using "$path/Results/Table6_panel_c.tex", replace ///
    cells("mean(fmt(4)) sd(fmt(4)) count(fmt(0))") ///
    title("Panel B: Dyadic Dependent Variables") ///
    mtitles("Full Sample" "Benchmark Sample") ///
    label booktabs ///
    addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
             "while statistics in (2) are computed on the benchmark sample.")

cap log close  // Table 6


* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable7", replace
// TABLE 7: Same group membership and friendship formation

* run specification (1)
ivreg2 LUL IG if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7.tex", tex replace label addtext(IV, No, Controls, No, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (2)
ivreg2 LUL IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (3)
ivreg2 LUL (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
// First stage is same as column 4 of Table 5

* run specification (4)
ivreg2 LUL (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
// First stage is same as column 6 of Table 5

* run specification (5)
ivreg2 LUL IG $Xvar if $condition & CloseAlphaRank==1, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage
* First stage for column (3)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* First stage for column (5)
ivreg2 IG AlphaDistIV $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic IG AlphaDistIV $Xvar DiffAlphaRankExt if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table7_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)


* close log file
cap log close



// TABLE 8: Friendship and movements of opinion pairs

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable8", replace 

* run specification (1)
ivreg2 CONV2 (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONV2 LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (2)
ivreg2 CONVS2 (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic CONVS2 LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 DIVW (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVW LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (4)
ivreg2 DIVS (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic DIVS LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (5)
ivreg2 COMOV (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic COMOV LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*log using "LogTable8An", append 

// First stage
* run specification (1-5)
ivreg2 LUL IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table8.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* close log file
cap log close // Table 8




// Table 9 - Friendship and change in political opinion gaps

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable9", replace

* run specification (1)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & CONV2==1, noid
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (2)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & DIVW==1, noid
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (3)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & COMOV==1, noid
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (4)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* close log file
cap log close



// TABLE 9 1st stage: IV spec 1st stage - Friendship and change in political opinion gaps

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable9_1st", replace


* run specification (1)
ivreg2 LUL IG $Xvar if $condition & CONV2==1, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (2)
ivreg2 LUL IG $Xvar if $condition & DIVW==1, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (3)
ivreg2 LUL IG $Xvar if $condition & COMOV==1, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 LUL IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table9_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* close log file
cap log close


//-- Figure 3: Heterogenous effect of firendship by pairs of initial political opinions
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogFigure3", replace

* effect on gap in political opinion
preserve
* left-left
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & LCR==1
local res_1 = _b[LUL]
* right-right
ivreg2 ChangePP (LUL=IG) $Xvar if $condition &  LCR==2
local res_2 = _b[LUL]
* center-center
ivreg2 ChangePP (LUL=IG) $Xvar if $condition &  LCR==3
local res_3 = _b[LUL]
* left-right
ivreg2 ChangePP (LUL=IG) $Xvar if $condition &  LCR==4
local res_4 = _b[LUL]
* left-center
ivreg2 ChangePP (LUL=IG) $Xvar if $condition &  LCR==5
local res_5 = _b[LUL]
* center-right
ivreg2 ChangePP (LUL=IG) $Xvar if $condition &  LCR==6
local res_6 = _b[LUL]

/*
gen orientation = ""
replace orientation = "left-left" if _n==1
replace orientation = "right-right" if _n==2
replace orientation = "center-center" if _n==3
replace orientation = "left-right" if _n==4
replace orientation = "left-center" if _n==5
replace orientation = "center-right" if _n==6
*/

gen gap_effect = .
replace gap_effect = `res_1' in 1  // left-left
replace gap_effect = `res_2' in 2 // right-right
replace gap_effect = `res_3' in 3  // center-center
replace gap_effect = `res_4' in 4 // left-right
replace gap_effect = `res_5' in 5  // left-center
replace gap_effect = `res_6' in 6 // center-right

cap drop n
gen n = _n
* Create Graph A: Effect on political opinion gap
graph bar (mean) gap_effect in 1/6, ///
	over(n, label(angle(45)) relabel(1 "left-left" 2 "right-right" 3 "center-center" 4 "left-right" 5 "left-center" 6 "center-right")) ///
    ytitle("Effect on the pair's political opinion gap") ///
    ylabel(-1.8(0.2)0) ///
    bar(1, color("31 119 180")) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(graph_a, replace)
	//    title("(A) Effect on the pair's political opinion gap", position(11) size(medium))
graph export "$path/Results/Figure3a.png", replace width(800) height(600)
restore	
	
* effect on sum of political opinions	
preserve
* left-left
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition & LCR==1
local res_1 = _b[LUL]
* right-right
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition &  LCR==2
local res_2 = _b[LUL]
* center-center
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition &  LCR==3
local res_3 = _b[LUL]
* left-right
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition &  LCR==4
local res_4 = _b[LUL]
* left-center
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition &  LCR==5
local res_5 = _b[LUL]
* center-right
ivreg2 ChangeSumPP (LUL=IG) $Xvar if $condition &  LCR==6
local res_6 = _b[LUL]

/*
gen orientation = ""
replace orientation = "left-left" if _n==1
replace orientation = "right-right" if _n==2
replace orientation = "center-center" if _n==3
replace orientation = "left-right" if _n==4
replace orientation = "left-center" if _n==5
replace orientation = "center-right" if _n==6
*/

gen sum_effect = .
replace sum_effect = `res_1' in 1  // left-left
replace sum_effect = `res_2' in 2 // right-right
replace sum_effect = `res_3' in 3  // center-center
replace sum_effect = `res_4' in 4 // left-right
replace sum_effect = `res_5' in 5  // left-center
replace sum_effect = `res_6' in 6 // center-right	

cap drop n
gen n = _n
* Create Graph B: Effect on sum of political opinions  
graph bar sum_effect in 1/6, ///
	over(n, label(angle(45)) relabel(1 "left-left" 2 "right-right" 3 "center-center" 4 "left-right" 5 "left-center" 6 "center-right")) ///
	ytitle("Effect on the pair's sum of political opinions") ///
    ylabel(-1(0.5)1.5) ///
    bar(1, color("31 119 180")) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(graph_b, replace)
	// title("(B) Effect on the pair's sum of political opinions", position(11) size(medium))
graph export "$path/Results/Figure3b.png", replace width(800) height(600)
restore	

cap log close // Figure 3

//-- Table 10: Friendship, integration group, and associative activities

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable10", replace

* run specification (1)
ivreg2 SameAsso IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 SameAsso (LUL = IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 SameAsso_Type_Pol IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 SameAsso_Type_Pol (LUL = IG) $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (5)
ivreg2 SameAsso_Type_Ply IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Ply IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 SameAsso_Type_Iden IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Iden IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (7)
ivreg2 SameSports IG $Xvar if $condition, noid
* compute corrected clustered standard errors 
IVdyadic SameSports IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* close log file
cap log close

//-- Table 10 1st stage: IV spec 1st stage - Friendship and Association activities

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable10_1st", replace

* 1st stage for column (2)
ivreg2 LUL IG $Xvar if $condition & SameAsso~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & SameAsso~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* 1st stage for column (4)
ivreg2 LUL IG $Xvar if $condition & SameAsso_Type_Pol~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & SameAsso_Type_Pol~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table10_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close


//-- Table 11: Effects of integration group and friendship by initial political opinion gaps

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable11", replace

* run specification (1)
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<=1, cluster(IGno_i1 IGno_i2)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<=1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11.tex", tex replace label addtext(IV, No, Controls, yes, Double Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (2)
ivreg2 ChangePP (LUL = IG) $Xvar if $condition & DiffPP<=1, cluster(IGno_i1 IGno_i2) 
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition & DiffPP<=1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11.tex", tex append label addtext(IV, Yes, Controls, yes, Double Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* run specification (3)
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2, cluster(IGno_i1 IGno_i2) //partial($Xvar)
* compute corrected clustered standard errors 
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11.tex", tex append label addtext(IV, No, Controls, yes, Double Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 ChangePP (LUL = IG) $Xvar if $condition & DiffPP>=2, cluster(IGno_i1 IGno_i2) //partial($Xvar)
* compute corrected clustered standard errors 
IVdyadic ChangePP LUL $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11.tex", tex append label addtext(IV, Yes, Controls, yes, Double Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* close log file
cap log close

//-- Table 11 1st stage: IV 1st stage for Effects of integration group and friendship by initial political opinion gaps

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable11_1st", replace

* 1st stage for column (2)
ivreg2 LUL IG $Xvar if $condition & DiffPP<=1, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP<=1, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* 1st stage for column (4)
ivreg2 LUL IG $Xvar if $condition & DiffPP>=2, noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table11_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close


//-- Figure 4: Effects of integration group and friendship by initial political opinion gap

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogFigure4", replace


global DiffPP0 "DiffPP==0"
global DiffPP1 "DiffPP==1"
global DiffPP2 "DiffPP==2"
global DiffPP3 "DiffPP>=3"

global DiffPP4 "DiffPP==4"
global DiffPP5 "DiffPP>=5"

cap drop Graph*
gen GraphIG = .
gen GraphLUL = .
gen GraphIG2 = .
gen GraphLUL2 = .

gen GraphIG_upper = .
gen GraphIG_lower = .
gen GraphLUL_upper = .
gen GraphLUL_lower = .
gen GraphIG2_upper = .
gen GraphIG2_lower = .
gen GraphLUL2_upper = .
gen GraphLUL2_lower = .

global TeXfile = "$path/Results/R1_T_ChangePPsimilarGraph1"
cap erase "$TeXfile.tex"
cap erase "$TeXfile.txt"

forval i = 0/3 {
	ivreg2 ChangePP IG $Xvar if $condition & ${DiffPP`i'}, noid
	local b = e(b)[1,1]
	IVdyadic ChangePP IG $Xvar if $condition & ${DiffPP`i'}, iv(IG) groups(IGno_i1 IGno_i2)

	local j = `i'+1
	replace GraphIG = `b' in `j'
	local stderr = e(StdErr)[1,1]
	local upper = `b' + `stderr'*1.96
	local lower = `b' - `stderr'*1.96
	replace GraphIG_upper = `upper' in `j'
	replace GraphIG_lower = `lower' in `j'
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "${TeXfile}", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes, Condition, ${DiffPP`i'}) addstat(StdErr IG, `stderr', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
}

cap drop n
gen n = _n-1
*replace n = . if n>5
*label def polgap 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">=5"
replace n = . if n>3
label def polgap 0 "0" 1 "1" 2 "2" 3 ">=3", replace //4 "4" 5 ">=5"
label value n polgap

twoway (rcap GraphIG_upper GraphIG_lower n, msize(4-pt) legend(label(1 "95% confidence interval") position(6) rows(1))) (connected GraphIG n, lpattern(dash) legend(label(2 "Estimate") position(6) rows(1))), yline(0) ylabel(-.4(.1).2) ymtick(##5) xtitle(`"Political opinion gap from before Sciences Po"') xlabel(, labels valuelabel) title(`"Same-integration group effect by initial opinion gap"')
graph save "$path/Results/IG_eff_by_polgap", replace
*graph use "IG_eff_by_polgap"
graph export "$path/Results/IG_eff_by_polgap.pdf", replace

global TeXfile = "$path/Results/R1_T_ChangePPsimilarGraph2"
cap erase "$TeXfile.tex"
cap erase "$TeXfile.txt"

forval i = 0/3 {
	ivreg2 ChangePP (LUL=IG) $Xvar if $condition & ${DiffPP`i'}, noid
	local b = e(b)[1,1]
	IVdyadic ChangePP LUL $Xvar if $condition & ${DiffPP`i'}, iv(IG) groups(IGno_i1 IGno_i2)

	local j = `i'+1
	replace GraphLUL = `b' in `j'
	local stderr = e(StdErr)[1,1]
	local upper = `b' + `stderr'*1.96
	local lower = `b' - `stderr'*1.96
	replace GraphLUL_upper = `upper' in `j'
	replace GraphLUL_lower = `lower' in `j'
	local stderr = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "${TeXfile}", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes, Condition, ${DiffPP`i'}) addstat(StdErr LUL, `stderr', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
}

twoway (rcap GraphLUL_upper GraphLUL_lower n, msize(4-pt) legend(label(1 "95% confidence interval") position(6) rows(1))) (connected GraphLUL n, lpattern(dash) legend(label(2 "Estimate") position(6) rows(1))), yline(0) ymtick(##5) xtitle(`"Political opinion gap from before Sciences Po"') xlabel(, labels valuelabel) title(`"Friendship effect by initial opinion gap"')
graph save "$path/Results/LUL_eff_by_polgap", replace
*graph use "LUL_eff_by_polgap"
graph export "$path/Results/LUL_eff_by_polgap.pdf", replace

global TeXfile = "$path/Results/R1_T_ChangePPsimilarGraph3"
cap erase "$TeXfile.tex"
cap erase "$TeXfile.txt"

forval i = 0/3 {
	ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & ${DiffPP`i'}, noid
	local b = e(b)[1,1]
	IVdyadic ChangePP IG $Xvar if $condition & ${DiffPP`i'}, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)

	local j = `i'+1
	replace GraphIG2 = `b' in `j'
	local stderr = e(StdErr)[1,1]
	local upper = `b' + `stderr'*1.96
	local lower = `b' - `stderr'*1.96
	replace GraphIG2_upper = `upper' in `j'
	replace GraphIG2_lower = `lower' in `j'
	local stderr = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "${TeXfile}", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes, Condition, ${DiffPP`i'}) addstat(StdErr IG, `stderr', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
}

twoway (rcap GraphIG2_upper GraphIG2_lower n, msize(4-pt) legend(label(1 "95% confidence interval") position(6) rows(1))) (connected GraphIG2 n, lpattern(dash) legend(label(2 "Estimate") position(6) rows(1))), yline(0) ymtick(##5) xtitle(`"Political opinion gap from before Sciences Po"') xlabel(, labels valuelabel) title(`"Same-integration group effect by initial opinion gap (Same Hyp. Group IV)"', size(11pt))
graph save "$path/Results/IG_IV_eff_by_polgap", replace
*graph use "IG_IV_eff_by_polgap"
graph export "$path/Results/IG_IV_eff_by_polgap.pdf", replace

global TeXfile = "$path/Results/R1_T_ChangePPsimilarGraph4"
cap erase "$TeXfile.tex"
cap erase "$TeXfile.txt"

forval i = 0/3 {
	ivreg2 ChangePP (LUL=SameAlphaHypGroupIV) $Xvar if $condition & ${DiffPP`i'}, noid
	local b = e(b)[1,1]
	IVdyadic ChangePP LUL $Xvar if $condition & ${DiffPP`i'}, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)

	local j = `i'+1
	replace GraphLUL2 = `b' in `j'
	local stderr = e(StdErr)[1,1]
	local upper = `b' + `stderr'*1.96
	local lower = `b' - `stderr'*1.96
	replace GraphLUL2_upper = `upper' in `j'
	replace GraphLUL2_lower = `lower' in `j'
	local stderr = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "${TeXfile}", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes, Condition, ${DiffPP`i'}) addstat(StdErr LUL, `stderr', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
}

twoway (rcap GraphLUL2_upper GraphLUL2_lower n, msize(4-pt) legend(label(1 "95% confidence interval") position(6) rows(1))) (connected GraphLUL2 n, lpattern(dash) legend(label(2 "Estimate") position(6) rows(1))), yline(0) ymtick(##5) xtitle(`"Political opinion gap from before Sciences Po"') xlabel(, labels valuelabel) title(`"Friendship effect by initial opinion gap (Same Hyp. Group IV)"', size(14pt))
graph save "$path/Results/LUL_IV_eff_by_polgap", replace
*graph use "LUL_IV_eff_by_polgap"
graph export "$path/Results/LUL_IV_eff_by_polgap.pdf", replace

cap cap log close


//-- Table 12: Friendship, integration group, and associative activities

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable12", replace

* run specification (1)
ivreg2 SameAsso IG $Xvar if $condition & DiffPP<2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex replace label addtext(IV, No, Controls, yes, Double Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 SameAsso (LUL = IG) $Xvar if $condition & DiffPP<2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso LUL $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 SameAsso IG $Xvar if $condition & DiffPP>=2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 SameAsso (LUL = IG) $Xvar if $condition & DiffPP>=2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso LUL $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (5)
ivreg2 SameAsso_Type_Pol IG $Xvar if $condition & DiffPP<2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 SameAsso_Type_Pol (LUL = IG) $Xvar if $condition & DiffPP<2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol LUL $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (7)
ivreg2 SameAsso_Type_Pol IG $Xvar if $condition & DiffPP>=2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (8)
ivreg2 SameAsso_Type_Pol (LUL = IG) $Xvar if $condition & DiffPP>=2, noid
* compute corrected clustered standard errors 
IVdyadic SameAsso_Type_Pol LUL $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


* close log file
cap log close

//-- Table 12 1st stage: IV first stage for Friendship, integration group, and associative activities

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTable12_1st", replace


* 1st stage for column (2)
ivreg2 LUL IG $Xvar if $condition & DiffPP<2 & SameAsso~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP<2 & SameAsso~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12_1st.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* 1st stage for column (4)
ivreg2 LUL IG $Xvar if $condition & DiffPP>=2 & SameAsso~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP>=2 & SameAsso~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 LUL IG $Xvar if $condition & DiffPP<2 & SameAsso_Type_Pol~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP<2 & SameAsso_Type_Pol~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (8)
ivreg2 LUL IG $Xvar if $condition & DiffPP>=2 & SameAsso_Type_Pol~=., noid
* compute corrected clustered standard errors 
IVdyadic LUL IG $Xvar if $condition & DiffPP>=2 & SameAsso_Type_Pol~=., iv(IG) groups(IGno_i1 IGno_i2)
* store output of interest
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
* export output
outreg2 using "$path/Results/Table12_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


cap log close

////////////////////////////////////////////////////////////////////////////////
/////////////////////////// APPENDIX
////////////////////////////////////////////////////////////////////////////////
*** structure for tables follows the structure used for main results

/*
*** load data
use "$path/Data/Analysis/work_data_confidential.dta", clear

*** define list of control variables
global Xvar = "SEX FEMALE NAT1 ADM ADPR DEPB REGBAC SERIEBAC DiffDR NOFEE PARI ZIP Paris IDFBAC PRO1"

* define threshold of time taken to respond to questions used to select sample
*get sample of couples were the main dependent variable, the friendship variable, the IV, and the controls are not missing
qui reg ChangePP LUL IG $Xvar 
gen sam=e(sample)
* get 95 percentile of time taken to respond in this sample
sum timepfr_i1 if sam, d
global time_threshold = r(p95)

*** define conditions to be applied to select sample for estimation and deriving statistics
global condition = "sample & uid_i1>uid_i2 & timepfr_i1<=$time_threshold & timepfr_i2<=$time_threshold & IGno_i1~=. & IGno_i2~=. "

*** define sample for analyis
cap drop sample
quietly reg ChangePP LUL DiffPP $Xvar 
gen sample=e(sample)
*/


	* mere relationship
cap drop LUL1
gen LUL1 = 0
replace LUL1 = 1 if LULint==1
	* firendship link
cap drop LUL2
gen LUL2 = 0
replace LUL2 = 1 if LULint==2
	* close firendship
cap drop LUL3
gen LUL3 = 0
replace LUL3 = 1 if LULint==3
	* very close friendship
cap drop LUL4
gen LUL4 = 0
replace LUL4 = 1 if LULint==4

//- Table A3: Additional descriptive statistics and covariates
*** panel A
if "$confidentiality" == "confidential" {
	* close previous log file
	cap cap log close
	* open new log file
	log using "$path/Results/LogTableA3", replace

	* full sample
	preserve
	bysort uid_i1: gen t=_n
	keep if t==1
	replace sex_i1 = 0 if sex_i1==2
	gen mention_i1=0 if Mentiontrsbien_i1=="Non"
	replace mention_i1=1 if Mentiontrsbien_i1=="Oui"
	estpost summarize sex_i1 mention_i1 droits_i1
	estimates store panel_a_full
	restore

	* benchmark sample
	preserve
	keep if $condition
	bysort uid_i1: gen t=_n
	keep if t==1
	replace sex_i1 = 0 if sex_i1==2
	gen mention_i1=0 if Mentiontrsbien_i1=="Non"
	replace mention_i1=1 if Mentiontrsbien_i1=="Oui"
	estpost summarize sex_i1 mention_i1 droits_i1 // $Xvar 
	estimates store panel_a_benchmark
	restore

	* Create the table
	esttab panel_a_full panel_a_benchmark using "$path/Results/TableA3_panel_a.tex", replace ///
		cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
		title("Panel A: Monadic Dependent Variables") ///
		mtitles("Full Sample" "Benchmark Sample") ///
		label booktabs ///
		addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
				 "while statistics in (2) are computed on the benchmark sample.")
}
 
 
*** panel B
* full sample
preserve
estpost summarize $Xvar if uid_i1>uid_i2
estimates store panel_b_full
* benchmark sample
estpost summarize $Xvar if $condition
estimates store panel_b_benchmark
* Create the table
esttab panel_b_full panel_b_benchmark using "$path/Results/TableA3_panel_b.tex", replace ///
    cells("mean(fmt(3)) sd(fmt(3)) count(fmt(0))") ///
    title("Panel B: Dyadic Dependent Variables") ///
    mtitles("Full Sample" "Benchmark Sample") ///
    label booktabs ///
    addnotes("Statistics in (1) are computed on the full sample of data available for each variable," ///
             "while statistics in (2) are computed on the benchmark sample.")

restore

cap log close // Table A3

//- Figure A1: True effect of L2 and L1 on political opinions

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogFigureA1", replace

//////  ROBUSTNESS CHECKS
******* New check using Intensity of Friendship
cap drop sample
quietly reg DiffPPa LUL2 IG DiffPP $Xvar // GG
gen sample=e(sample)

cap drop FrIntens
gen FrIntens = 0 if $condition 
forval i = 1/4 {
	cap rename str_fr_`i' Intens`i'plus
	local i1 = `i'-1
	if `i'>1{
		gen Intens`i1' = Intens`i1'plus - Intens`i'plus
	}
	replace FrIntens = `i' if Intens`i'plus==1
}
gen Intens4 = Intens4plus

forval i = 1/4 {
	cap drop Resid`i'
	reg Intens`i' IG $Xvar if $condition
	predict Resid`i', resid
}

forval i = 1/4 {
	cap drop Resid`i'plus
	reg Intens`i'plus IG $Xvar if $condition
	predict Resid`i'plus, resid
}


// Rebuild it - Dec 3 2025
reg Intens2plus IG $Xvar if $condition
reg Intens1 IG $Xvar if $condition
global pi1 = 0.1293134
global pi2 = 0.0353468
global pistar = $pi1/$pi2
di "pi_star = $pistar"

reg ChangePP Intens2plus Resid2plus Intens1 $Xvar if $condition

global coeff_nu2 = 1.124088
global coeff_L1 = -.0947624
global coeff_L2 = -1.198854

global gamma = 1 
global delta = 1 

global B1 = ($delta * $pistar * $coeff_L1 + $coeff_nu2)/(($delta +1)* $pistar  + 1/$gamma)
global B2 = $B1/$gamma

global beta1 = $coeff_L1 - $B1
global beta2 = $coeff_L2 + ($coeff_nu2 - $B2)

di "B1=" $B1
di "beta_1=" $beta1
di "beta_2=" $beta2


cap drop gamma
gen gamma = _n/50 in 12/100
forval i = 1(1)20{
	global delta = `i'/10
	cap drop B1 B2
	gen B1 = ($delta * $pistar * $coeff_L1 + $coeff_nu2)/(($delta +1)* $pistar  + 1/gamma)
	gen B2 = B1/gamma
	cap drop beta1_`i' beta2_`i'
	gen beta1_`i' = $coeff_L1 - B1
	gen beta2_`i' = $coeff_L2 + ($coeff_nu2 - B2)
}

twoway (line beta2_1 gamma) (line beta2_4 gamma) (line beta2_7 gamma) (line beta2_10 gamma) (line beta2_15 gamma) (line beta2_20 gamma) in 12/100, ///
	xtitle(gamma) title("Coefficient beta_2 of L_2 as a function of delta and gamma", size(medium)) legend(order(1 "delta = 0.1" 2 "delta = 0.4" 3 "delta = 0.7" 4 "delta = 1" 5 "delta = 1.5" 6 "delta = 2")) ///
	graphregion(color(white)) bgcolor(white) 
graph save "$path/Results/Beta2_by_DeltaGamma", replace
cap erase "$path/Results/Beta2_by_DeltaGamma.pdf"
graph export "$path/Results/Beta2_by_DeltaGamma.pdf", as(pdf) replace
twoway (line beta1_1 gamma) (line beta1_4 gamma) (line beta1_7 gamma) (line beta1_10 gamma) (line beta1_15 gamma) (line beta1_20 gamma) in 12/100, ///
	xtitle(gamma) title("Coefficient beta_1 of L_1 as a function of delta and gamma", size(medium)) legend(order(1 "delta = 0.1" 2 "delta = 0.4" 3 "delta = 0.7" 4 "delta = 1" 5 "delta = 1.5" 6 "delta = 2")) ///
	graphregion(color(white)) bgcolor(white)
graph save "$path/Results/Beta1_by_DeltaGamma", replace
cap erase "$path/Results/Beta1_by_DeltaGamma.pdf"
graph export "$path/Results/Beta1_by_DeltaGamma.pdf", as(pdf) replace


cap log close // FIgure A1
//- Table A4: Permutation tests of randomness of last name's first letter
if "$confidentiality" == "confidential" {

	cap cap log close
	* open new log file
	log using "$path/Results/LogTableA4", replace

	preserve

	cap drop sample
	quietly reg DiffPPa LUL DiffPP $Xvar 
	gen sample=e(sample)

	keep if $condition 
	egen tag_i1=tag(uid_i1)

	reg polposnow_i1 polpos_i1 if tag_i1==1
	predict resid_i1, resid
	gen Dpolpos_i1 = polposnow_i1 - polpos_i1
	keep if tag_i1==1
	*keep sample Dpolpos_i1 polposnow_i1 resid_i1 polpos_i1 IGno_i1 LettFirst_i1 uid_i1 droits_i1 sex_i1 nat1_i1 nat2_i1 admission_i1 program1_i1 program2_i1 parent1_i1 seriebac_i1 mention_i1 departmentbac_i1 regionbac_i1 Codepostal_adressePR_i1
	keep if IGno_i1~=.


	cap drop AFirst_i1
	egen AFirst_i1 = group(LettFirst_i1)

	cap drop 
	gen admispr_i1 = (admission_i1==1)

	permute AFirst_i1 W_SD_Post=r(w_b_sd_ratio) , reps(300) seed(142857): W_B_SD polpos_i1 AFirst_i1 
	permute AFirst_i1 W_SD_Post=r(w_b_sd_ratio) , reps(300) seed(142857): W_B_SD droits_i1 AFirst_i1 
	foreach var in sex admispr {
		di ""
		di "Permutation test for " "`var'"
		di ""
		permute AFirst_i1 W_SD_Post=r(w_b_sd_ratio), reps(300) seed(142857): W_B_SD `var'_i1 AFirst_i1
	}


	*foreach var in nat2 admission new_pro1 parent1 seriebac new_depb new_regb new_zip {
	foreach var in nat2 admission program1 parent1 seriebac departmentbac regionbac Codepostal_adressePR {
		di ""
		di "Permutation test for " "`var'"
		di ""
		permute AFirst_i1 Within_Between_links =r(W_B_Cat), reps(300) seed(142857): W_B_Cat `var'_i1 AFirst_i1
	}

	restore

	cap log close  // Table A4
}


//-Figure A3: Effects of Integration Group and Friendship by Initial Political Opinion Gap with Same Hypothetical Group IV
*** ALREADY GENERATED ABOVE


//-- Figure A2: Friendship formation by pairs of initial political opinions

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogFigureA3", replace

preserve
twoway ///
    (hist DiffPP  if LUL==1, ///
		density start(-0.5) width(1) ///
        fcolor(ltblue%35) lcolor(none) lwidth(none) ///
        barwidth(0.90) ) ///
    (hist DiffPPa if LUL==1, ///
		density start(-0.5) width(1) ///	
        fcolor(gs10) lcolor(dkgray) lwidth(thin) ///
        barwidth(0.50) ), ///
	xscale(range(0 8) noextend) xlabel(0(1)8) ///
    yline(0.05(0.05)0.4, lcolor(gs15) lwidth(vthin)) ///
    yline(0.0(0.1)0.4,  lcolor(gs13) lwidth(vthin)) ///
    legend(order(1 "Pre-Sciences Po (Aug 2013)" 2 "Survey time (Mar 2014)") ///
           position(6) rows(1) size(small)) ///
    xtitle("Political opinion gap") ytitle("Percent") ///
    scheme(s1mono) ///
    plotregion(margin(b+2)) ///
    graphregion(color(white))
graph save "$path/Results/FigureA3", replace
cap erase "$path/Results/FigureA3.pdf"
graph export "$path/Results/FigureA3.pdf", as(pdf) replace
	
restore

//- Table A5: Effects of Integration Group on Movement of Opinion Pairs Using Alphabetical Distance

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA5", replace

* run specification (1)
ivreg2 CONV2 (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic CONV2 IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex replace label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic CONVS2 IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic DIVW IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 DIVS (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic DIVS IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (5)
ivreg2 COMOV (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic COMOV IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

/// First stage
* run first stage regression - same for all specifications
ivreg2 IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA5.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

cap log close // Table A5

//- Table A6: Same Integration Group Membership and Changes in Political Opinion Gaps Using Alphabetical Distance
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA6", replace

* run specification (1)
ivreg2 ChangePP (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition & CONV2==1, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition & CONV2==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6.tex", tex replace label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 ChangePP (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition & DIVW==1, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition & DIVW==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (3)
ivreg2 ChangePP (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition & COMOV==1, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition & COMOV==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 ChangePP (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6.tex", tex append label addtext(IV, AlphaDistIV, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 ChangePP IG DiffAlphaRankExt $Xvar if $condition & CloseAlphaRank==1, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG DiffAlphaRankExt $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

/// First stage
* run specification (1)
ivreg2 IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & CONV2==1, noid
IVdyadic IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & CONV2==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

* run specification (2)
ivreg2 IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & DIVW==1, noid
IVdyadic IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & DIVW==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

* run specification (3)
ivreg2 IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & COMOV==1, noid
IVdyadic IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

* run specification (4)
ivreg2 IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic IG AlphaDistIV DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA6_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

cap log close // Table A6

//- Table A7: Same Group Membership and Friendship Formation Showing All Coefficients
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA7", replace

* run specification (1)
ivreg2 LUL IG if $condition, noid
IVdyadic LUL IG if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA7.tex", tex replace label addtext(IV, No, Controls, No, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(*)


* run specification (2)
ivreg2 LUL IG $Xvar if $condition, noid
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(*)


* run specification (3)
ivreg2 LUL (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic LUL IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(*)


* run specification (4)
ivreg2 LUL (IG=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic LUL IG DiffAlphaRankExt $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(*)


* run specification (5)
ivreg2 LUL IG $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic LUL IG $Xvar if $condition & CloseAlphaRank==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA7.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(*)

cap log close // Table A7

//- Table A8: Same Group Membership and Friendship Formation by Friendship Intensity
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA8", replace

* rename firendship variables

cap drop LUL1
gen LUL1 = LUL*(LULint<2)

cap erase "$path/Results/TableA8.tex"
cap erase "$path/Results/TableA8.txt"

* run specifications (1) to (8) - OLS and IV
forval i = 1/4 {
	* OLS specifications
	ivreg2 LUL`i' IG $Xvar if $condition, noid
	IVdyadic LUL`i' IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA8.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
	
	* IV specifications
	ivreg2 LUL`i' (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
	IVdyadic LUL`i' IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA8.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
}
*cap drop LUL1

cap log close // Table A8

//- Table A9: Same Group Membership and Friendship Formation by Frequent Activity

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA9", replace

cap erase "$path/Results/TableA9.tex"
cap erase "$path/Results/TableA9.txt"

* run specifications (1) to (8) - OLS and IV
forval i = 1/4 {
	* OLS specifications
	ivreg2 LULactiv`i' IG $Xvar if $condition, noid
	IVdyadic LULactiv`i' IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA9.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

	* IV specifications
	ivreg2 LULactiv`i' (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
	IVdyadic LULactiv`i' IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)	
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA9.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
}

cap log close // Table A9
//- Table A10: Same Group Membership and Friendship Formation by Time Spent Together

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA10", replace


cap erase "$path/Results/TableA10.tex"
cap erase "$path/Results/TableA10.txt"

* run specifications (1) to (8) - OLS and IV
forval i = 1/4 {
	* OLS specifications
	ivreg2 LULtime`i' IG $Xvar if $condition, noid
	IVdyadic LULtime`i' IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

	* IV specifications
	ivreg2 LULtime`i' (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
	IVdyadic LULtime`i' IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
	local stderr_IG = e(StdErr)[1,1]
	local depvar = e(depvar)
	sum `depvar' if e(sample)
	local MeanDepVar = r(mean)
	local StDevDepVar = r(sd)
	outreg2 using "$path/Results/TableA10.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
}

cap log close // Table A10

//- Table A11: Descriptive Statistics on Recall Bias

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA11", replace

* tabulate actual and recalled poltical opinion
preserve
* load individual data containing polictical opinions
use "$path/Data/Analysis/recall_data.dta", clear
estpost tab recalled_14 actual_14
esttab using "$path/Results/TableA11.tex", replace cells("b(fmt(0)) colpct(fmt(1))")
restore

cap log close // Table A11

//- Table A12: Recall Bias Regression on Individual Data 

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA12", replace

preserve
* load individual data containing polictical opinions
use "$path/Data/Analysis/recall_data.dta", clear
* create new variables
gen rbias = recalled_14 -  actual_14
gen abs_rbias = abs(recalled_14 -  actual_14)
gen diff_act1514 = actual_15 - actual_14
* select sample
cap drop sample
qui reg rbias diff_act1514
gen sample = e(sample)
* specification (1)
reg abs_rbias actual_15 actual_14 if sample, cluster(group)
outreg2 using "$path/Results/TableA12.tex", tex replace label addtext(Group Clustering, Yes ) ctitle(" ") nonotes 
* specification (2)
reg rbias diff_act1514 if sample, cluster(group)  
outreg2 using "$path/Results/TableA12.tex", tex append label addtext(Group Clustering, Yes ) ctitle(" ") nonotes 
restore

cap log close // Table A12


//- Table A13: Friendship and Movement of Opinion Pairs

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA13", replace

** integration group as instrument
*
ivreg2 CONV2 (LUL=IG) $Xvar if $condition, noid
IVdyadic CONV2 LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 CONVS2 (LUL=IG) $Xvar if $condition, noid
IVdyadic CONVS2 LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVW (LUL=IG) $Xvar if $condition, noid
IVdyadic DIVW LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVS (LUL=IG) $Xvar if $condition, noid
IVdyadic DIVS LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 COMOV (LUL=IG) $Xvar if $condition, noid
IVdyadic COMOV LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
* First stage - same for all spacifications
ivreg2 LUL IG $Xvar if $condition, noid
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13a.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
** Alphabetical order as instrument
*
ivreg2 CONV2 (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONV2 LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 CONVS2 (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONVS2 LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVW (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVW LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVS (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVS LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 COMOV (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic COMOV LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
* First stage - same for all spacifications
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition, noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA13b.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close // Table A13

//- Table A14: Friendship and Changes in Political Opinion Gaps

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA14", replace

// Basic IV specifications using IG
* run specification (1)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & CONV2==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14A.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (2)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & DIVW==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14A.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & COMOV==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14A.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (4)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition, noid
IVdyadic ChangePP LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14A.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


// IV specifications using SameAlphaHypGroupIV
* run specification (1)
ivreg2 ChangePP (LUL=SameAlphaHypGroupIV) $Xvar if $condition & CONV2==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (2)
ivreg2 ChangePP (LUL=SameAlphaHypGroupIV) $Xvar if $condition & DIVW==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 ChangePP (LUL=SameAlphaHypGroupIV) $Xvar if $condition & COMOV==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (4)
ivreg2 ChangePP (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic ChangePP LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (5)
ivreg2 ChangePP (LUL=AlphaDistIV) DiffAlphaRankExt $Xvar if $condition, noid
IVdyadic ChangePP LUL $Xvar DiffAlphaRankExt if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (6)
ivreg2 ChangePP (LUL=IG) $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic ChangePP LUL $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


// First stage A
ivreg2 LUL IG $Xvar if $condition & CONV2==1, noid
IVdyadic LUL IG $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stA.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 LUL IG $Xvar if $condition & DIVW==1, noid
IVdyadic LUL IG $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stA.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 LUL IG $Xvar if $condition & COMOV==1, noid
IVdyadic LUL IG $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stA.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 LUL IG $Xvar if $condition, noid
IVdyadic LUL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stA.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


// First stage B
* run specification (1)
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (2)
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (3)
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (4)
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition, noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (5)
ivreg2 LUL AlphaDistIV $Xvar DiffAlphaRankExt if $condition, noid
IVdyadic LUL AlphaDistIV $Xvar DiffAlphaRankExt if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

* run specification (6)
ivreg2 LUL IG $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic LUL IG $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA14_1stB.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A14

//- Table A15: Long-Term Effects of Integration Group on Pairwise Opinions
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA15", replace

// OLS 
* run specification (1)
ivreg2 CONV2_Long IG $Xvar if $condition, noid
IVdyadic CONV2_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2_Long IG $Xvar if $condition, noid
IVdyadic CONVS2_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW_Long IG $Xvar if $condition, noid
IVdyadic DIVW_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 DIVS_Long IG $Xvar if $condition, noid
IVdyadic DIVS_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 COMOV_Long IG $Xvar if $condition, noid
IVdyadic COMOV_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 ChangePP_Long IG $Xvar if $condition, noid
IVdyadic ChangePP_Long IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// IV
*
ivreg2 CONV2_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONV2_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*
ivreg2 CONVS2_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONVS2_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*
ivreg2 DIVW_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVW_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*
ivreg2 DIVS_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVS_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*
ivreg2 COMOV_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic COMOV_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*
ivreg2 ChangePP_Long (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic ChangePP_Long IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


// First stage - same for all specifications
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & ChangePP_Long!=., noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & ChangePP_Long!=., iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA15_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close  // Table A15

//- Table A16: Long-Term Effects of Friendship on Pairwise Opinions 
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA16", replace

// First IV w.r.t. IG 
* run specification (1)
ivreg2 CONV2_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic CONV2_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (2)
ivreg2 CONVS2_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic CONVS2_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (3)
ivreg2 DIVW_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic DIVW_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (4)
ivreg2 DIVS_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic DIVS_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (5)
ivreg2 COMOV_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic COMOV_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

* run specification (6)
ivreg2 ChangePP_Long (LUL=IG) $Xvar if $condition, noid
IVdyadic ChangePP_Long LUL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

// First stage - same for all specifications
ivreg2 LUL IG $Xvar if $condition & ChangePP_Long!=., noid
IVdyadic LUL IG $Xvar if $condition & ChangePP_Long!=., iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16a.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


// IV
*
ivreg2 CONV2_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONV2_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*
ivreg2 CONVS2_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONVS2_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*
ivreg2 DIVW_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVW_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*
ivreg2 DIVS_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVS_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*
ivreg2 COMOV_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic COMOV_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

*
ivreg2 ChangePP_Long (LUL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic ChangePP_Long LUL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LUL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LUL, `stderr_LUL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

// First stage - same for all specifications
ivreg2 LUL SameAlphaHypGroupIV $Xvar if $condition & ChangePP_Long!=., noid
IVdyadic LUL SameAlphaHypGroupIV $Xvar if $condition & ChangePP_Long!=., iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA16_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close // Table A16


//- Table A17: Effects of Integration Group on Movement of Opinion Pairs among Initially Politically Similar Pairs
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA17", replace
// OLS specifications
* run specification (1)
ivreg2 CONV2 IG $Xvar if $condition & DiffPP<2, noid
IVdyadic CONV2 IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 IG $Xvar if $condition & DiffPP<2, noid
IVdyadic CONVS2 IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW IG $Xvar if $condition & DiffPP<2, noid
IVdyadic DIVW IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 DIVS IG $Xvar if $condition & DiffPP<2, noid
IVdyadic DIVS IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (5)
ivreg2 COMOV IG $Xvar if $condition & DiffPP<2, noid
IVdyadic COMOV IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


// IV specifications  
* run specification (1)
ivreg2 CONV2 (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic CONV2 IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic CONVS2 IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic DIVW IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 DIVS (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic DIVS IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 COMOV (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic COMOV IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage - same for all specifications
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA17_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close // Table A17

//- Table A18: Effects of Integration Group on Movement of Opinion Pairs among Initially Politically Dissimilar Pairs
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA18", replace

// OLS specifications
* run specification (1)
ivreg2 CONV2 IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic CONV2 IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic CONVS2 IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic DIVW IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


* run specification (4)
ivreg2 DIVS IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic DIVS IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 COMOV IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic COMOV IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// IV specifications
* run specification (1)
ivreg2 CONV2 (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic CONV2 IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 CONVS2 (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic CONVS2 IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 DIVW (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic DIVW IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 DIVS (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic DIVS IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 COMOV (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic COMOV IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage - same for all specifications
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA18_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close // Table A18

//- Table A19: Effects of Integration Group on Changes in Political Opinion Gaps among Initially Politically Similar Pairs

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA19", replace

*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<2 & CONV2==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<2 & DIVW==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<2 & COMOV==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// IV specifications
* run specification (1)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2 & CONV2==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2 & DIVW==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2 & COMOV==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 ChangePP (IG=AlphaDistIV) $Xvar if $condition & DiffPP<2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 ChangePP IG $Xvar if $condition & DiffPP<2 & CloseAlphaRank==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP<2 & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage 
* run specification (1)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & CONV2==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (2)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & DIVW==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (3)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & COMOV==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2 & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (4)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP<2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (5)
ivreg2 IG AlphaDistIV $Xvar if $condition & DiffPP<2, noid
IVdyadic IG AlphaDistIV $Xvar if $condition & DiffPP<2, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA19_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

cap log close // Table A19

//- Table A20: Effects of Integration Group on Changes in Political Opinion Gaps among Initially Politically Dissimilar Pairs

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA20", replace

*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2 & CONV2==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2 & DIVW==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2 & COMOV==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// IV specifications
* run specification (1)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2 & CONV2==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (2)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2 & DIVW==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (3)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2 & COMOV==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (4)
ivreg2 ChangePP (IG=SameAlphaHypGroupIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (5)
ivreg2 ChangePP (IG=AlphaDistIV) $Xvar if $condition & DiffPP>=2, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

* run specification (6)
ivreg2 ChangePP IG $Xvar if $condition & DiffPP>=2 & CloseAlphaRank==1, noid
IVdyadic ChangePP IG $Xvar if $condition & DiffPP>=2 & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_iv.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

// First stage 
* run specification (1)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & CONV2==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (2)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & DIVW==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (3)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & COMOV==1, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2 & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (4)
ivreg2 IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2, noid
IVdyadic IG SameAlphaHypGroupIV $Xvar if $condition & DiffPP>=2, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

* run specification (5)
ivreg2 IG AlphaDistIV $Xvar if $condition & DiffPP>=2, noid
IVdyadic IG AlphaDistIV $Xvar if $condition & DiffPP>=2, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA20_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)

cap log close //Table A20

//- Table A21: Friendship, Integration Group, and Same Interests in Association Types
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA21", replace

// Pairs with low initial gap
// for Table 1: Descriptive Stat
sum BothAsso123 if uid_i1<uid_i2
sum BothAsso123 if $condition

ivreg2 BothAsso123 IG $Xvar if $condition & DiffPP<2, noid
IVdyadic BothAsso123 IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_A.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


ivreg2 BothAsso123 (LUL = IG) $Xvar if $condition & DiffPP<2, noid
IVdyadic BothAsso123 LUL $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_A.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


// for Table 1: Descriptive Stat
sum BothTypeDiffAsso123 if uid_i1<uid_i2
sum BothTypeDiffAsso123 if $condition

ivreg2 BothTypeDiffAsso123 IG $Xvar if $condition & DiffPP<2, noid
IVdyadic BothTypeDiffAsso123 IG $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_A.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


ivreg2 BothTypeDiffAsso123 (LUL = IG) $Xvar if $condition & DiffPP<2, noid
IVdyadic BothTypeDiffAsso123 LUL $Xvar if $condition & DiffPP<2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_A.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


// Pairs with high initial gap
// for Table 1: Descriptive Stat
sum BothAsso123 if uid_i1<uid_i2
sum BothAsso123 if $condition

ivreg2 BothAsso123 IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic BothAsso123 IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_B.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


ivreg2 BothAsso123 (LUL = IG) $Xvar if $condition & DiffPP>=2, noid
IVdyadic BothAsso123 LUL $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_B.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)


// for Table 1: Descriptive Stat
sum BothTypeDiffAsso123 if uid_i1<uid_i2
sum BothTypeDiffAsso123 if $condition

ivreg2 BothTypeDiffAsso123 IG $Xvar if $condition & DiffPP>=2, noid
IVdyadic BothTypeDiffAsso123 IG $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_B.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)


ivreg2 BothTypeDiffAsso123 (LUL = IG) $Xvar if $condition & DiffPP>=2, noid
IVdyadic BothTypeDiffAsso123 LUL $Xvar if $condition & DiffPP>=2, iv(IG) groups(IGno_i1 IGno_i2)

local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA21_B.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

cap log close // Table A21



//- Table A22: 
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA22", replace

*
ivreg2 LAL IG if $condition, noid
IVdyadic LAL IG if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA22.tex", tex replace label addtext(IV, No, Controls, No, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4)
*
ivreg2 LAL IG $Xvar if $condition, noid
IVdyadic LAL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA22.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4)
*
ivreg2 LAL (IG=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic LAL IG $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA22.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4)
*
ivreg2 LAL (IG=AlphaDistIV) $Xvar if $condition, noid
IVdyadic LAL IG $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA22.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4)
*
ivreg2 LAL IG $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic LAL IG $Xvar if $condition & CloseAlphaRank==1, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA22.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4)

cap log close // Table A22

//- Table A23: 

* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA23", replace

* panel A
*
ivreg2 CONV2 (LAL=IG) $Xvar if $condition, noid
IVdyadic CONV2 LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 CONVS2 (LAL=IG) $Xvar if $condition, noid
IVdyadic CONVS2 LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 DIVW (LAL=IG) $Xvar if $condition, noid
IVdyadic DIVW LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 DIVS (LAL=IG) $Xvar if $condition, noid
IVdyadic DIVS LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 COMOV (LAL=IG) $Xvar if $condition, noid
IVdyadic COMOV LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)

* First stage - same for all specifications
ivreg2 LAL IG $Xvar if $condition, noid
IVdyadic LAL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23a.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

*** panel B
*
ivreg2 CONV2 (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONV2 LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 CONVS2 (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic CONVS2 LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 DIVW (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVW LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 DIVS (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic DIVS LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 COMOV (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic COMOV LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
// First stage - same for all specifications
ivreg2 LAL SameAlphaHypGroupIV $Xvar if $condition, noid
IVdyadic LAL SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA23b.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)

cap log close // Table A23

//- Table A24
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA24", replace

* panel A
*
ivreg2 ChangePP (LAL=IG) $Xvar if $condition & CONV2==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=IG) $Xvar if $condition & DIVW==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=IG) $Xvar if $condition & COMOV==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=IG) $Xvar if $condition, noid
IVdyadic ChangePP LAL $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)

* panel B
*
ivreg2 ChangePP (LAL=SameAlphaHypGroupIV) $Xvar if $condition & CONV2==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex replace label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=SameAlphaHypGroupIV) $Xvar if $condition & DIVW==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=SameAlphaHypGroupIV) $Xvar if $condition & COMOV==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=SameAlphaHypGroupIV) $Xvar if $condition, noid
IVdyadic ChangePP LAL $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=AlphaDistIV) $Xvar if $condition, noid
IVdyadic ChangePP LAL $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)
*
ivreg2 ChangePP (LAL=IG) $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic ChangePP LAL $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_LAL = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b.tex", tex append label addtext(IV, Same Hyp. Group, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr LAL, `stderr_LAL', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LAL)

* panel A - first stage
*
ivreg2 LAL IG $Xvar if $condition & CONV2==1, noid
IVdyadic LAL IG $Xvar if $condition & CONV2==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a_1st.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 LAL IG $Xvar if $condition & DIVW==1, noid
IVdyadic LAL IG $Xvar if $condition & DIVW==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 LAL IG $Xvar if $condition & COMOV==1, noid
IVdyadic LAL IG $Xvar if $condition & COMOV==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 LAL IG $Xvar if $condition, noid
IVdyadic LAL IG $Xvar if $condition, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24a_1st.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
* panel B - first stage
*
ivreg2 LAL SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, noid
IVdyadic LAL SameAlphaHypGroupIV $Xvar if $condition & CONV2==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)
*
ivreg2 LAL SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, noid
IVdyadic LAL SameAlphaHypGroupIV $Xvar if $condition & DIVW==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)
*
ivreg2 LAL SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, noid
IVdyadic LAL SameAlphaHypGroupIV $Xvar if $condition & COMOV==1, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)
*
ivreg2 LAL SameAlphaHypGroupIV $Xvar if $condition, noid
IVdyadic LAL SameAlphaHypGroupIV $Xvar if $condition, iv(SameAlphaHypGroupIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(SameAlphaHypGroupIV)
*
ivreg2 LAL AlphaDistIV $Xvar if $condition, noid
IVdyadic LAL AlphaDistIV $Xvar if $condition, iv(AlphaDistIV) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(AlphaDistIV)
*
ivreg2 LAL IG $Xvar if $condition & CloseAlphaRank==1, noid
IVdyadic LAL IG $Xvar if $condition & CloseAlphaRank==1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA24b_1st.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A24

//- Table A25:
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA25", replace

* define less restrictive sample
global basicsample_1 = "sample & uid_i1>uid_i2 & IGno_i1~=. & IGno_i2~=. "
*
ivreg2 CONV2 IG $Xvar if $basicsample_1, noid
IVdyadic CONV2 IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 CONVS2 IG $Xvar if $basicsample_1, noid
IVdyadic CONVS2 IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 DIVW IG $Xvar if $basicsample_1, noid
IVdyadic DIVW IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 DIVS IG $Xvar if $basicsample_1, noid
IVdyadic DIVS IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 COMOV IG $Xvar if $basicsample_1, noid
IVdyadic COMOV IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $basicsample_1, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA25.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A25

//- Table A26: 
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA26", replace

*
ivreg2 CONV2 (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic CONV2 LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 CONVS2 (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic CONVS2 LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVW (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic DIVW LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVS (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic DIVS LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 COMOV (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic COMOV LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 ChangePP (LUL=IG) $Xvar if $basicsample_1, noid
IVdyadic ChangePP LUL $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
* First stage - same for all specifications
ivreg2 LUL IG $Xvar if $basicsample_1, noid
IVdyadic LUL IG $Xvar if $basicsample_1, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA26.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A26

//- Table A27: 
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA27", replace

* define new thresholds
_pctile timepfr_i1 if sam, p(2.5)
scalar p2_5 = r(r1)
_pctile timepfr_i1 if sam, p(97.5)
scalar p97_5 = r(r1)
* define new condition (adjustment needed to maintain the same number of observations as the main one-sided specification)
global condition_2 = "sample & uid_i1>uid_i2 & timepfr_i1>=(p2_5+0000.1) & timepfr_i2>=(p2_5+0000.1) & timepfr_i1<=p97_5 & timepfr_i2<=p97_5 & IGno_i1~=. & IGno_i2~=. "
*
ivreg2 CONV2 IG $Xvar if $condition_2, noid
IVdyadic CONV2 IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex replace label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 CONVS2 IG $Xvar if $condition_2, noid
IVdyadic CONVS2 IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 DIVW IG $Xvar if $condition_2, noid
IVdyadic DIVW IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 DIVS IG $Xvar if $condition_2, noid
IVdyadic DIVS IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 COMOV IG $Xvar if $condition_2, noid
IVdyadic COMOV IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
*
ivreg2 ChangePP IG $Xvar if $condition_2, cluster(IGno_i1 IGno_i2)
IVdyadic ChangePP IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA27.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A27

//- Table A28:
* close previous log file
cap cap log close
* open new log file
log using "$path/Results/LogTableA28", replace

*
ivreg2 CONV2 (LUL=IG) $Xvar if $condition_2, noid
IVdyadic CONV2 LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex replace label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 CONVS2 (LUL=IG) $Xvar if $condition_2, noid
IVdyadic CONVS2 LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVW (LUL=IG) $Xvar if $condition_2, noid
IVdyadic DIVW LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 DIVS (LUL=IG) $Xvar if $condition_2, noid
IVdyadic DIVS LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 COMOV (LUL=IG) $Xvar if $condition_2, noid
IVdyadic COMOV LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
*
ivreg2 ChangePP (LUL=IG) $Xvar if $condition_2, noid
IVdyadic ChangePP LUL $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IG = e(StdErr)[1,1]
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, `stderr_IG', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
* First stage - same for all specifications
ivreg2 LUL IG $Xvar if $condition_2, noid
IVdyadic LUL IG $Xvar if $condition_2, iv(IG) groups(IGno_i1 IGno_i2)
local stderr_IV = e(StdErr)[1,1]
local F_KP = e(F_1)
local depvar = e(depvar)
sum `depvar' if e(sample)
local MeanDepVar = r(mean)
local StDevDepVar = r(sd)
outreg2 using "$path/Results/TableA28.tex", tex append label addtext(IV, No, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, `stderr_IV', Kleibergen-Paap Weak IV F-stat, `F_KP', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

cap log close // Table A28

//- Table A29:
if "$confidentiality" == "confidential" {
	* close previous log file
	cap cap log close
	* open new log file
	log using "$path/Results/LogTableA29", replace

	* dropping nationalities one-by-one
	rename Libellnationalit1_i1 nationality1_i1
	rename Libellnationalit2_i1 nationality2_i1
	rename Libellnationalit1_i2 nationality1_i2
	rename Libellnationalit2_i2 nationality2_i2

	cap erase "$path/Results/TableA29.tex"
	cap erase "$path/Results/TableA29.txt"
	cap erase "$path/Results/TableA29_1st.tex"
	cap erase "$path/Results/TableA29_1st.txt"

	foreach Nat in ALGERIENNE ALLEMANDE BELGE ESPAGNOLE ITALIENNE MALGACHE MAROCAINE {
		
		display "Dropping nationality `Nat'"

		cap drop sample1
		gen sample1 = 1 if nationality1_i1~="`Nat'" &  nationality1_i2~="`Nat'" & nationality2_i1~="`Nat'" & nationality2_i2~="`Nat'"

		* IV specification
		ivreg2 ChangePP (LUL=IG) $Xvar if $condition & sample1==1, noid
		IVdyadic ChangePP LUL $Xvar if $condition & sample1==1, iv(IG) groups(IGno_i1 IGno_i2)
		local stderr_IG = e(StdErr)[1,1]
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA29.tex", tex append label addtext(Dropped Nationality, "`Nat'", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, (`stderr_IG'), p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)

		* First stage
		ivreg2 LUL IG $Xvar if $condition & sample1==1, noid
		IVdyadic LUL IG $Xvar if $condition & sample1==1, iv(IG) groups(IGno_i1 IGno_i2)

		local stderr_IV = e(StdErr)[1,1]
		local F_KP = e(F_1)
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA29_1st.tex", tex append label addtext(Dropped Nationality, "`Nat'", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, (`stderr_IV'), Kleibergen-Paap Weak IV F-stat, `F_KP', p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
	}

	cap log close // Table A29
}


//- Table A30: 
if "$confidentiality" == "confidential" {

	* close previous log file
	cap cap log close
	* open new log file
	log using "$path/Results/LogTableA30", replace

	preserve
	keep if $condition 
	egen tag_i1=tag(uid_i1)
	keep if tag_i1==1

	foreach var in sex nat2 admission parent1 seriebac new_depb new_regb droits new_zip {
		di "Permutations stratified by variable: `var'"
		permute IGno_i1 W_B_SD=r(w_b_sd_ratio) , reps(300) strata(`var'_i1) seed(1): W_B_SD polposnow_i1 IGno_i1
	}
	restore
	cap log close // Table A30
}

//- Table A31:
if "$confidentiality" == "confidential" {
	* close previous log file
	cap cap log close
	* open new log file
	log using "$path/Results/LogTableA31", replace

	* define new sample
	cap drop sample2
	gen sample2=1 if inlist(substr(name_i1,1,3),"DE ", "DU ") | inlist(substr(name_i2,1,3),"DE ", "DU ") //beginning by DE or DU (separated by space)
	replace sample2 = 1 if inlist(substr(name_i1,1,2),"D ") | inlist(substr(name_i2,1,2),"D ") //beginning by D'

	cap erase "$path/Results/TableA31.tex"
	cap erase "$path/Results/TableA31.txt"
	cap erase "$path/Results/TableA31_1st.tex"
	cap erase "$path/Results/TableA31_1st.txt"

	* drop names starting with letter (one-by-one)
	foreach letter in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z {
		display "Dropping names starting with `letter'"
		cap drop sample1
		gen sample1=1 if LettFirst_i1 ~= "`letter'" & LettFirst_i2 ~= "`letter'"

		* IV
		ivreg2 ChangePP (LUL=IG) $Xvar if $condition & sample1==1, noid
		IVdyadic ChangePP LUL $Xvar if $condition & sample1==1, iv(IG) groups(IGno_i1 IGno_i2)
		local stderr_IG = e(StdErr)[1,1]
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA31.tex", tex append label addtext(Dropped Letter, "`letter'", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, (`stderr_IG'), p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)	
		
		* First stage
		ivreg2 LUL IG $Xvar if $condition & sample1==1, noid
		IVdyadic LUL IG $Xvar if $condition & sample1==1, iv(IG) groups(IGno_i1 IGno_i2)
		local stderr_IV = e(StdErr)[1,1]
		local F_KP = e(F_1)
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA31_1st.tex", tex append label addtext(Dropped Letter, "`letter'", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, (`stderr_IV'), Kleibergen-Paap Weak IV F-stat, `F_KP', p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)
	}

	* dropping names starting with de, du, d'
		display "Dropping names starting with `De'"
	cap drop sample2

	gen sample2=1 if inlist(substr(name_i1,1,3),"DE ", "DU ") | inlist(substr(name_i2,1,3),"DE ", "DU ") //beginning by DE or DU (separated by space)
	replace sample2 = 1 if inlist(substr(name_i1,1,2),"D ") | inlist(substr(name_i2,1,2),"D ") //beginning by D'

		* IV
		ivreg2 ChangePP (LUL=IG) $Xvar if $condition & sample2~=1, noid
		IVdyadic ChangePP LUL $Xvar if $condition & sample2~=1, iv(IG) groups(IGno_i1 IGno_i2)
		local stderr_IG = e(StdErr)[1,1]
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA31.tex", tex append label addtext(Dropped Letter, "De", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IG, (`stderr_IG'), p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(LUL)
		
		* First stage
		ivreg2 LUL IG $Xvar if $condition & sample2~=1, noid
		IVdyadic LUL IG $Xvar if $condition & sample2~=1, iv(IG) groups(IGno_i1 IGno_i2)
		local stderr_IV = e(StdErr)[1,1]
		local F_KP = e(F_1)
		local pval = e(pvalues)[1,1]
		local depvar = e(depvar)
		sum `depvar' if e(sample)
		local MeanDepVar = r(mean)
		local StDevDepVar = r(sd)
		outreg2 using "$path/Results/TableA31_1st.tex", tex append label addtext(Dropped Letter, "De", IV, Yes, Controls, Yes, Dyadic Group Clustering, Yes) addstat(StdErr IV, (`stderr_IV'), Kleibergen-Paap Weak IV F-stat, `F_KP', p-value, `pval', \textit{Mean}(Dep. Var.), `MeanDepVar', \textit{Std.Dev.}(Dep. Var.), `StDevDepVar') ctitle(" ") nonotes dec(4) keep(IG)

	cap log close // Table A31
}

* END OF ANALYSIS.DO




