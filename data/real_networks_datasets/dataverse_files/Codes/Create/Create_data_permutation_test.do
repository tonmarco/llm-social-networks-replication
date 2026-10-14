

////////////////////////////////////////////////////////////////////////////////
*********** Code to create ranking of names ***************
////////////////////////////////////////////////////////////////////////////////


////////////////////////// Ranking on full sample of students

*** set path

*** load data for 2013 cohort (cohort used in the main analysis)
use "$path/Data/Raw/name_1314.dta", clear

*** append data for the cohorts that finished their diploma in 2013, 2014, and 2015
append using "$path/Data/Raw/name_end131415.dta"

*** append data for the 2017 cohort 
append using "$path/Data/Raw/name_17.dta"

*** append data for the 2009 cohort
append using "$path/Data/Raw/name_09.dta"

*** normalize unicode strings
replace name = ustrto(ustrnormalize(name, "nfd"), "ascii", 2)

*** remove commas from the name variables
replace name = subinstr(name, ",", "", .)

*** parse name variable to isolate surname
split name, parse(" ")

*** keep only capital letters (used for surnames in the data provided from the university administartion)
forval i = 2/8 { 
	gen name`i'_2 = substr(name`i',-1,.)
	replace name`i' = " " if regexm(name`i'_2, "[a-z]+")
	drop name`i'_2 
}

*** concatenate surbame variables
egen surname = concat(name1 name2 name3 name4 name5 name6 name7 name8)

*** keep only surname and student id variables
keep surname uid

*** sort based on surname alphabetical order
sort surname

*** save file with full ranking of names
save "$path/Data/Intermediate/name_ranking_full.dta", replace

*** generate ranking of names
gen AlphaRankExt = _n

*** drop duplicate names
duplicates drop surname, force

*** save file with single occurances of names
save "$path/Data/Intermediate/name_ranking.dta", replace

*** load file with full ranking of names, keep only those associated to a student id (includes names of students in the cohort used for the analysis), and update file
use "$path/Data/Intermediate/name_ranking_full.dta", clear
keep if uid!=.
save "$path/Data/Intermediate/name_ranking_full.dta", replace

*** load file with single occurances of names
use "$path/Data/Intermediate/name_ranking.dta", clear

*** drop student id
drop uid

*** merge using names
merge 1:m surname using "$path/Data/Intermediate/name_ranking_full.dta"

*** keep only if names matched
keep if _merge==3

*** keep only student id and ranking
keep uid AlphaRankExt

*** save file containing student ids and ranking of their names
save "$path/Data/Intermediate/name_ranking.dta", replace


//////// generate file containing rankings for individuals that are in the cohort used for the analysis

*** load raw individual data for cohort of analysis
use "$path/Data/Raw/base_complete_1314.dta", clear

*** drop if student id is missing
drop if uid==.

*** keep only student id
keep uid 

*** merge with ranking of names
merge 1:1 uid using "$path/Data/Intermediate/name_ranking.dta"

*** keep only if names matched
keep if _merge==3

*** drop merge variable
drop _merge

*** save file containing ranking of names for individual 1
rename * *_i1
save "$path/Data/Intermediate/name_ranking_i1.dta", replace

*** save file containing ranking of names for individual 2
rename *_i1 *_i2
save "$path/Data/Intermediate/name_ranking_i2.dta", replace


////////////////////////// Ranking only on cohort used in the analysis

*** load data for 2013 cohort (cohort used in the main analysis)
use "$path/Data/Raw/name_1314.dta", clear

/*** normalize unicode strings
replace name = ustrto(ustrnormalize(name, "nfd"), "ascii", 2)

*** remove commas from the name variables
replace name = subinstr(name, ",", "", .)

*** parse name variable to isolate surname
split name, parse(" ")

*** keep only capital letters (used for surnames in the data provided from the university administartion)
forval i = 2/5 { 
	gen name`i'_2 = substr(name`i',-1,.)
	replace name`i' = " " if regexm(name`i'_2, "[a-z]+")
	drop name`i'_2 
}

*** concatenate surbame variables
egen surname = concat(name1 name2 name3 name4 name5)

*** keep only surname and student id variables
keep surname uid

*** sort based on surname alphabetical order
sort surname
*/

gen name_up = upper(name)
sort name_up

*** generate ranking of names
gen AlphaRank = _n

*** keep only student id and ranking
keep uid AlphaRank

*** save file with full ranking of names
save "$path/Data/Intermediate/name_ranking_internal.dta", replace

//////// generate file containing rankings for individuals that are in the cohort used for the analysis

*** load raw individual data for cohort of analysis
use "$path/Data/Raw/base_complete_1314.dta", clear

*** drop if student id is missing
drop if uid==.

*** keep only student id
keep uid 

*** merge with ranking of names
merge 1:1 uid using "$path/Data/Intermediate/name_ranking_internal.dta"

*** keep only if names matched
keep if _merge==3

*** drop merge variable
drop _merge

*** save file containing ranking of names for individual 1
rename * *_i1
save "$path/Data/Intermediate/name_ranking_internal_i1.dta", replace

*** save file containing ranking of names for individual 2
rename *_i1 *_i2
save "$path/Data/Intermediate/name_ranking_internal_i2.dta", replace


