////////////////////////////////////////////////////////////////////////////////
*********** Code to anonymize individual ***************
////////////////////////////////////////////////////////////////////////////////

////////// Preliminary

*** run code to create name ranking variables
do "$path/Codes/Create/Create_data_permutation_test.do" 

*** load raw data
use "$path/Data/Raw/base_complete_1314.dta", clear

////////// Prepare individual data

/// Recode codes flagging missing information to missing values
* 0 to missing in selected variables
foreach var in q1_1uid q1_2uid q1_3uid q1_4uid q1_5uid q1_6uid q1_7uid q1_8uid q1_9uid q1_10uid q1_1if q1_2if q1_3if q1_4if q1_5if q1_6if q1_7if q1_8if q1_9if q1_10if q1_1cb q1_2cb q1_3cb q1_4cb q1_5cb q1_6cb q1_7cb q1_8cb q1_9cb q1_10cb q1_1at q1_2at q1_3at q1_4at q1_5at q1_6at q1_7at q1_8at q1_9at q1_10at q1_1fr q1_2fr q1_3fr q1_4fr q1_5fr q1_6fr q1_7fr q1_8fr q1_9fr q1_10fr q2_1uid q2_2uid q2_3uid q2_4uid q2_5uid q2_6uid q2_7uid q2_8uid q2_9uid q2_10uid q2_1if q2_2if q2_3if q2_4if q2_5if q2_6if q2_7if q2_8if q2_9if q2_10if q2_1cb q2_2cb q2_3cb q2_4cb q2_5cb q2_6cb q2_7cb q2_8cb q2_9cb q2_10cb q2_1at q2_2at q2_3at q2_4at q2_5at q2_6at q2_7at q2_8at q2_9at q2_10at q2_1fr q2_2fr q2_3fr q2_4fr q2_5fr q2_6fr q2_7fr q2_8fr q2_9fr q2_10fr {
replace `var'=. if `var'==0
}
* 99 to missing in selected variables
foreach var in q4a q4b q4c q4d q5a q5b {
replace `var'=. if `var'==99
}
* 88 and 99 to missing in selected variables
replace q6a1=. if q6a1==88
replace q6a2=. if q6a2==99
replace q6b1=. if q6b1==88
replace q6b2=. if q6b2==99

/// generate variable recording average time spent answering questions on friendship
* generate time variable recording time and day individual started of the questionnaire
split intro
split intro1, parse(/)
split intro2, parse(:)
foreach var in intro11 intro12 intro13 intro21 intro22 intro23 {
destring `var', replace
}
gen t_st_fr = intro23 + intro22*60 + intro21*60*60
gen d_st_fr = 59 + intro11 if intro12==3
replace d_st_fr = 90 + intro11 if intro12==4
replace d_st_fr = . + intro11 if intro13!=2014
* generate time variable recording time and day individual finished questionnaire on firendship of the questionnaire
split q1
split q11, parse(/)
split q12, parse(:)
foreach var in q111 q112 q113 q121 q122 q123 {
destring `var', replace
}
gen t_f_fr = q123 + q122*60 + q121*60*60
gen d_f_fr = 59 + q111 if q112==3
replace d_f_fr = 90 + q111 if q112==4
replace d_f_fr = . + q111 if q113!=2014
* generate variable recording total time spent on friendship variables
gen time_fr = t_f_fr - t_st_fr if d_f_fr==d_st_fr  
* generate variable recording time spent on friendship varibales per friend named
egen numfriends = rownonmiss(q1_*uid)
gen timepfr = time_fr/numfriends

///////////////////////////////////// Anonymize the data
/*
/// aninymize student id and related variables
egen new_id = group(uid)

preserve
keep uid new_id
save "$path/Data/Intermediate/map.dta", replace
restore

replace new_id = . if uid==.
replace new_id = 0 if uid==0
drop uid
rename new_id uid_

forval i=1/10 {
	rename q1_`i'uid uid
	merge m:1 uid using "$path/Data/Intermediate/map.dta"
	drop if _merge==2
	drop _merge
	replace new_id = . if uid==.
	replace new_id = 0 if uid==0
	rename new_id q1_`i'uid
	drop uid
}
rename uid_ uid
*/

/// anonymize student id
egen new_id = group(uid)
replace new_id = . if uid==.
replace new_id = 0 if uid==0

/// postal code
* destring zip code variables
destring Codepostal_adressePR, replace
* correct misreported code
replace Codepostal_adressePR=75011 if Codepostal_adressePR==750011
* generate equal to 1 if the zip code of the address of the individual is in Paris
gen code = .
replace code = 1 if Codepostal_adressePR<=75116 & Codepostal_adressePR>=75001
replace code = 0 if 75001>Codepostal_adressePR | Codepostal_adressePR>75116
* anonymize postal address
egen new_zip = group(Codepostal_adressePR)
// drop Codepostal_adressePR // To anonymize later

/// department
* encode individual numeric variable from individual string variable
encode DpartementobtentionbacLib, generate(departmentbac)
drop DpartementobtentionbacLib
* anonymize department variable
egen new_depb = group(departmentbac)
// drop departmentbac // To anonymize later

/// region
* encode individual numeric variable from individual string variable
encode Rgiondobtentionbac, generate(regionbac)
drop Rgiondobtentionbac
* anonymize region variable
egen new_regb = group(regionbac)
// drop regionbac // To anonymize later

/// program
* encode individual numeric variable from individual string variable (first characteristics)
encode Libellprogramme, generate(program1)
* encode individual numeric variable from individual string variable (second characteristics)
encode Libellprogramme2, generate(program2)
drop Libellprogramme Libellprogramme2
* anonymize program variables
egen new_pro1 = group(program1)
egen new_pro2 = group(program2)
// drop program1 program2 // To anonymize later

/// nationality
* encode individual numeric variable from individual string variable (first nationality)
encode Libellnationalit1, generate(nat1)
* encode individual numeric variable from individual string variable (second nationality)
encode Libellnationalit2, generate(nat2)

/// Associations

*** encode association variables
encode q3_1, generate(s1)
encode q3_2, generate(s2)
encode q3_3, generate(s3)
encode q3_4, generate(s4)
encode q3_5, generate(s5)

*** Manually correct association ID variables to account for miscoded/mispelled entries (for 5 association variables)
replace q3_1uid = 0005 if s1 == 24
replace q3_1uid = 0006  if s1 == 27
replace q3_1uid = 4593  if s1 == 28
replace q3_1uid = 0001 if s1 == 3 | s1 == 7 | s1 == 37
replace q3_1uid = 0008 if s1 == 31
replace q3_1uid = 0007 if s1 == 29
replace q3_1uid = 0009 if s1 == 32
replace q3_1uid = 2069 if s1 == 38
replace q3_1uid = 0002 if s1 == 44 | s1 == 105 | s1 == 45 | s1 == 46 | s1 == 47 | s1 == 48
replace q3_1uid = 0003 if s1 == 49
replace q3_1uid = 7434 if s1 == 56
replace q3_1uid = 0010 if s1 == 57
replace q3_1uid = 0004 if s1 == 77 | s1 == 78 | s1 == 73
replace q3_1uid = 0011 if s1 == 75
replace q3_1uid = 8210 if s1 == 86 | s1 == 92
replace q3_1uid = 0013 if s1 == 79
replace q3_1uid = 3601 if s1 == 102 | s1 == 101 | s1 == 103
replace q3_1uid = 0012 if s1 == 76
*replace q3_1uid = . if s1 == .

replace q3_2uid = 0016 if s2 == 1
replace q3_2uid = 0008 if s2 == 3 | s2== 4
replace q3_2uid = 4593  if s2 == 5
replace q3_2uid = 0015 if s2 == 26 | s2 == 27
replace q3_2uid = 0007 if s2 == 30
replace q3_2uid = 0009 if s2 == 31
replace q3_2uid = 0001 if s2 == 35
replace q3_2uid = 9321 if s2 == 33
replace q3_2uid = 0017 if s2 == 38
replace q3_2uid = 0021 if s2 == 93
replace q3_2uid = 0018 if s2 == 40
replace q3_2uid = 0002 if s2 == 42 | s2 == 43 | s2 == 44
replace q3_2uid = 0019 if s2 == 45
replace q3_2uid = 7434 if s2 == 52
replace q3_2uid = 7434 if s2 == 94
replace q3_2uid = 0000 if s2 == 53
replace q3_2uid = 7434 if s2 == 54
replace q3_2uid = 8603 if s2 == 95
replace q3_2uid = 4788 if s2 == 59
replace q3_2uid = 0013 if s2 == 96
replace q3_2uid = 7434 if s2 == 65
replace q3_2uid = 0004 if s2 == 71 | s2 == 97 | s2 == 67 | s2 == 68 | s2 == 69
replace q3_2uid = 0020 if s2 == 79
replace q3_2uid = 0007 if s2 == 98
replace q3_2uid = 0013 if s2 == 72 | s2 == 73
replace q3_2uid = 9612 if s2 == 85
replace q3_2uid = 3601 if s2 == 89 | s2 == 88
*replace q3_2uid = . if s2 == .

replace q3_3uid = 0008 if s3 == 1
replace q3_3uid = 0015 if s3 == 65
replace q3_3uid = 5478 if s3 == 19
replace q3_3uid = 0007 if s3 == 21
replace q3_3uid = 9321 if s3 == 23
replace q3_3uid = 0023 if s3 == 26
replace q3_3uid = 0021 if s3 == 27 | s3 == 28
replace q3_3uid = 0024 if s3 == 30
replace q3_3uid = 0002 if s3 == 31
replace q3_3uid = 7434 if s3 == 66
replace q3_3uid = 4788 if s3 == 39
replace q3_3uid = 0022 if s3 == 43 | s3 == 44
replace q3_3uid = 0025 if s3 == 45
replace q3_3uid = 0026 if s3 == 55
replace q3_3uid = 0028 if s3 == 67
replace q3_3uid = 0027 if s3 == 57
replace q3_3uid = 0013 if s3 == 46
replace q3_3uid = 3601 if s3 == 63
*replace q3_3uid = . if s3 == .

replace q3_4uid = 0002 if s4 == 15
replace q3_4uid = 8603 if s4 == 21
replace q3_4uid = 9567 if s4 == 30
replace q3_4uid = 0013 if s4 == 26
replace q3_4uid = 0000 if s4 == 31
replace q3_4uid = 3601 if s4 == 35
replace q3_4uid = 0029 if s4 == 33
*replace q3_4uid = . if s4 == .

replace q3_5uid = 0004 if s5 == 10
*replace q3_5uid = . if s5 == .

/// Additional data preparation procedures
* drop if student id is missing
drop if uid==.
* drop if individuals did not respond to any question on firendship or responded NA
drop if q1_1uid==. | q1_1uid==0

/*
*** anonymize association id
egen new_id = group(q3_1uid)

preserve
keep q3_1uid new_id
bysort new_id: gen t=_n
keep if t==1
drop t
save "$path/Data/Intermediate/map_asso.dta", replace
restore

replace new_id = . if q3_1uid==.
replace new_id = 0 if q3_1uid==0
drop q3_1uid
rename new_id q3_1uid_

forval i=2/4 {
	rename q1_`i'uid q3_1uid
	merge m:1 q3_1uid using "$path/Data/Intermediate/map_asso.dta"
	drop if _merge==2
	drop _merge
	replace new_id = . if q3_1uid==.
	replace new_id = 0 if q3_1uid==0
	rename new_id q1_`i'uid
	drop q3_1uid
}
rename q3_1uid_ q3_1uid
*/
///////////////// create individual data for individual 1 and individual 2
rename * *_i1
save "$path/Data/Raw/base_complete_1314_i1.dta", replace
rename *_i1 *_i2
save "$path/Data/Raw/base_complete_1314_i2.dta", replace


