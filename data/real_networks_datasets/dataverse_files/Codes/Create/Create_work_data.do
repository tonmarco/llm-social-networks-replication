
////////////////////////////////////////////////////////////////////////////////
*********** Code to create analysis dataset from individual raw data ***************
////////////////////////////////////////////////////////////////////////////////

////////// Create diadic dataset from individual dataset

* load individual dataset for individual 1
use "$path/Data/Raw/base_complete_1314_i1.dta", clear
* cross with individual dataset for individual 2
cross using "$path/Data/Raw/base_complete_1314_i2.dta"
* drop observations corrisponding to couples of same individuals (diagnoal of the adjency matrix)
drop if uid_i1==uid_i2


////////// Create new variables

/// variable identifying whether couples are friends (undirected link)
* create variable equal to zero
gen LUL = 0
* set variable to 1 if the id of the second individual is among the ids of the friends of the first individual
forval i=1/10 {
	replace LUL=1 if (uid_i2==q1_`i'uid_i1)
}
* set variable to 1 if the id of the first individual is among the ids of the friends of the second individual
forval i=1/10 {
	replace LUL=1 if (uid_i1==q1_`i'uid_i2)
}

/// variable identifying whether couples are friends (directed link)
* create variable equal to zero
gen LDL = 0
* set variable to 1 if the id of the second individual is among the ids of the friends of the first individual
forval i=1/10 {
	replace LDL=1 if (uid_i2==q1_`i'uid_i1) & (uid_i1>uid_i2)
}
* set variable to 1 if the id of the first individual is among the ids of the friends of the second individual
forval i=1/10 {
	replace LDL=1 if (uid_i1==q1_`i'uid_i2) & (uid_i1<uid_i2)
}

/// reverse directed link
gen LDLreverse = 0
* set variable to 1 if the id of the second individual is among the ids of the friends of the first individual
forval i=1/10 {
	replace LDLreverse=1 if (uid_i2==q1_`i'uid_i1) & (uid_i1<uid_i2)
}
* set variable to 1 if the id of the first individual is among the ids of the friends of the second individual
forval i=1/10 {
	replace LDLreverse=1 if (uid_i1==q1_`i'uid_i2) & (uid_i1>uid_i2)
}

/// "AND" network
cap drop LAL
gen LAL = LDL & LDLreverse

/// Intensity of friendship




/// variable identifying couples in same integration group
* create empty variable
gen IG = .
* set to one if individual group variables are equal
replace IG = 1 if Groupestage_integration_i1==Groupestage_integration_i2
* set to 0 if individual group variables are not equal
replace IG = 0 if Groupestage_integration_i1!=Groupestage_integration_i2
* set to 0 if summer group is not reported (NR) for either individual
replace IG = 0 if Groupestage_integration_i1=="NR" | Groupestage_integration_i2=="NR"

/// numeric variable identifying the summer group of each individual
* encode numeric variable from string variable
encode Groupestage_integration_i1, generate(IGno_i1)
encode Groupestage_integration_i2, generate(IGno_i2)
* set numeric variable to missing if string variable is not reported (NR)
replace IGno_i1=. if Groupestage_integration_i1=="NR"
replace IGno_i2=. if Groupestage_integration_i2=="NR"

/// variable recording difference in initial poliical opinion (August 2013)
* rename variable recording individual polical opinion
rename q4b_i1 polpos_i1
rename q4b_i2 polpos_i2
* set individual political opinion to missing if it equal missing value flag (99)
replace polpos_i1=. if polpos_i1==99
replace polpos_i2=. if polpos_i2==99
* compute the absolute difference in political opinion between the two individuals
gen DiffPP=abs(polpos_i1-polpos_i2)

/// variable recording difference in poliical opinion (March 2014)
* rename variable recording individual polical opinion
rename q4a_i1 polposnow_i1
rename q4a_i2 polposnow_i2
* set individual political opinion to missing if it equal missing value flag (99)
replace polposnow_i1=. if polposnow_i1==99
replace polposnow_i2=. if polposnow_i2==99
* compute the absolute difference in political opinion between the two individuals
gen DiffPPa=abs(polposnow_i1-polposnow_i2)


/// variable recording change in poliical opinion (between August 2013 and March 2014)
gen ChangePP=DiffPPa-DiffPP

/// variable recording the interaction between the initial difference in political opinion and a dummy for being in the same integration group
gen IGxDiffPP = IG * DiffPP

/// variable recording the interaction between the initial difference in political opinion and friendship
gen LULxDiffPP = LUL * DiffPP

/// variable identifying couples of same sex individuals
* encode individual numeric variable from individual string variable
encode Sexetudiant_i1, generate(sex_i1)
encode Sexetudiant_i2, generate(sex_i2) 
* generate variable equal to 0
gen SEX=0
* set variable to 1 if the two individuals have the same sex
replace SEX=1 if sex_i1==sex_i2
* set variable to missing if the information on the sex of either individual is missing
replace SEX=. if sex_i2==. | sex_i1==.

/// variable identifying couples of same sex individuals
* generate variable equal to to 1 if both individuals are females and zero otherwise
gen FEMALE = (sex_i1==1) & (sex_i2==1)

/// variable identifying couples of individuals with same nationality
* generate variable equal to 0
gen NAT1=0
* set to 1 oif variable NAT is not missing and if the two individuals share one nationality and their first nationality is not French
replace NAT1=1 if ( ((nat1_i1==nat1_i2) & (nat1_i1~=12)) |  ((nat1_i1==nat2_i2) & (nat1_i1~=12)) | ((nat2_i1==nat1_i2) & (nat1_i2~=12)) | ((nat2_i1==nat2_i2) & (nat1_i1~=12)) ) // nat1==12: FRENCH; nat2==15: FRENCH
replace NAT1=. if nat1_i1==. | nat1_i2==.

/// variable identifying couples of individuals admitted with the same admission procedure
* encode individual numeric variable from individual string variable
encode LibellTypeadmission_i1, generate(admission_i1)
encode LibellTypeadmission_i2, generate(admission_i2)
* generate variable equal to 0
gen ADM=0
* set variable to 1 if both individuals were admitted with the same admission procedure
replace ADM=1 if admission_i1==admission_i2
* set variable to missing if the information on admission procedure of either individual is missing
replace ADM=. if admission_i1==. | admission_i2==.

/// variable identifying couples where both individuals were admitted with a preferintial admission procedure
* generate variable equal to 0
gen ADPR=0
* set variable to 1 if both individuals were admitted with the a preferential procedure
replace ADPR=1 if admission_i1==admission_i2 & admission_i1==1
* set variable to missing if the information on admission procedure of either individual is missing
replace ADPR=. if admission_i1==. | admission_i2==.

/// variable identifying couples where both individuals live in the same ZIP code
* generate variable equal to 0
gen ZIP = 0
* set variable to 1 if both individuals live in the same ZIP code
//replace ZIP = 1 if new_zip_i1 == new_zip_i2
replace ZIP = 1 if Codepostal_adressePR_i1 == Codepostal_adressePR_i2
* set variable to missing if the information on ZIP code of either individual is missing
//replace ZIP=. if new_zip_i1==. |  new_zip_i2==.
replace ZIP=. if Codepostal_adressePR_i1==. |  Codepostal_adressePR_i2==.

/// variable identifying couples where individuals obtained their high school degree in the same geographical department
* generate variable equal to 0
gen DEPB=0
* set variable to 1 if both individuals obtained high school degree in the same department
//replace DEPB=1 if new_depb_i1==new_depb_i2
replace DEPB=1 if departmentbac_i1==departmentbac_i2
* set variable to missing if the information on high school degree department of either individual is missing
//replace DEPB=. if new_depb_i1==. | new_depb_i2==.
replace DEPB=. if departmentbac_i1==. | departmentbac_i2==.
	
/// variable identifying couples where individuals obtained their high school degree in the same region
* generate variable equal to 0
gen REGB=0
* set variable to 1 if both individuals obtained high school degree in the same region
//replace REGB=1 if new_regb_i1==new_regb_i2
replace REGB=1 if regionbac_i1==regionbac_i2
* set variable to missing if the information on high school degree department of either individual is missing
//replace REGB=. if new_regb_i1==.| new_regb_i2==.
replace REGB=. if regionbac_i1==.| regionbac_i2==.

/// variable identifying couples of individuals enrolled in the same undergraduate program
	* comment: programs have two characteristics and the variables capture whether individuals' programs have either of these characteristics in common
* generate variable equal to 0
gen PRO=0
* set variable to 1 if the two individuals' programs have either of the two characteristics in common
//replace PRO=1 if (new_pro1_i1==new_pro1_i2 | (new_pro2_i1==new_pro2_i2 &  new_pro2_i1!=. & new_pro2_i2!=.))
replace PRO=1 if (program1_i1==program1_i2 | (program2_i1==program2_i2 &  program2_i1!=. & program2_i2!=.))
* set variable to missing if the information on the first characteristics of the program is missing
	* COMMENT: missing values for the second characteristics are taken into account in the previous line
//replace PRO=. if new_pro1_i1==. | new_pro1_i2==.
replace PRO=. if program1_i1==. | program1_i2==.

/// varibale identyfing couples of individuals enrolled in the same undergraduate program other than the standard program
* generate variable equal to 0
gen PRO1=0
* set variable to 1 if both individuals are enrolled in the same undergraduate program other than the standard program
//replace PRO1=1 if (new_pro1_i1==new_pro1_i2) & (new_pro1_i1~=1)
replace PRO1=1 if (program1_i1==program1_i2) & (program1_i1~=1)

* set variable to missing if the information on the first characteristics of the program is missing
//replace PRO1=. if new_pro1_i1==. | new_pro1_i2==.
replace PRO1=. if program1_i1==. | program1_i2==.

/// variable identifying couples of individuals with same type of high school diploma
* encode variable recording high school diploma type
encode SrieBaccalauratLib_i1, generate(seriebac_i1)
encode SrieBaccalauratLib_i2, generate(seriebac_i2)
* generate variable equal to 1 if the two individuals have the same type of high school diploma and 0 otherwise
gen SERIEBAC = (seriebac_i1 == seriebac_i2) if seriebac_i1~=. & seriebac_i2 ~=.

/// variable recording the absolute difference in tuition fees paid by the two individuals
* encode individual numeric variable from individual string variable
destring Droitsconstatscumuls_i1, generate(droits_i1) ignore(�) dpcomma
destring Droitsconstatscumuls_i2, generate(droits_i2) ignore(�) dpcomma
* generate variable recording the absolute difference in tuition fees paid
gen DiffDR=abs(droits_i1-droits_i2)	

/// variable identifying couples of wehre either both individuals are exempted from tuition fees or they both pay tuition fees
* generate individual variables equal to 1 if individuals pay 0 tutition fees
gen nofee_i1 = 1 if droits_i1==0
gen nofee_i2 = 1 if droits_i2==0
* set variable to 0 if tution fees variable is not missing and tutition fees are non-zero
replace nofee_i1 = 0 if nofee_i1==. & droits_i1~=.
replace nofee_i2 = 0 if nofee_i2==. & droits_i2~=.
* generate variable equal to 0
gen NOFE=0
* set variable to 1 if the two individuals are either both exempted from tuition fees or they both pay tuition fees
replace NOFE=1 if nofee_i1==nofee_i2
* set variable to missing if the information on tuition fees is missing for either individual
**# Bookmark #1
replace NOFE=. if nofee_i1==. | nofee_i2==.
	
/// variable identifying couples where individuals' political opinions moved in the same direction (strict comovment)
* generate variable equal to 0
gen COMOV = 0
* set to 1 if individuals' political opinions moved in the same direction (strictly both left or both right)
replace COMOV = 1 if (polposnow_i1-polpos_i1>0 & polposnow_i2-polpos_i2>0) | (polposnow_i1-polpos_i1<0 & polposnow_i2-polpos_i2<0)  
* set to missing if past or present political opinions are missing for at least one indivudual  
replace COMOV = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==. 

/// variable identifying couples where individuals' political opinions moved in the same direction (weak comovement)
* generate variable equal to 0
gen COMOVW = 0
* set to 1 if individuals' political opinions moved in the same direction (both left or nomovement or both right or nomovement)
replace COMOVW = 1 if (polposnow_i1-polpos_i1>=0 & polposnow_i2-polpos_i2>=0) | (polposnow_i1-polpos_i1<=0 & polposnow_i2-polpos_i2<=0)   
* set to missing if past or present political opinions are missing for at least one indivudual   
replace COMOVW = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.
	
/// variable identifying couples where individuals' political opinion converged to that of each other	(strict convergence)
* generate variable equal to 0
gen CONV = 0
* set to 1 if political opinions of two individuals were initially different and converged (strictly)
replace CONV = 1 if ((polpos_i1>polpos_i2 &  ((polposnow_i1>=polpos_i2 & polposnow_i1<=polpos_i1 & polposnow_i2>polpos_i2 & polposnow_i2<=polpos_i1) | (polposnow_i1>=polpos_i2 & polposnow_i1<polpos_i1 & polposnow_i2>=polpos_i2 & polposnow_i2<=polpos_i1))) | (polpos_i2>polpos_i1 & ((polposnow_i1>polpos_i1 & polposnow_i1<=polpos_i2 & polposnow_i2>=polpos_i1 & polposnow_i2<=polpos_i2) | (polposnow_i1>=polpos_i1 & polposnow_i1<=polpos_i2 & polposnow_i2>=polpos_i1 & polposnow_i2<polpos_i2)))) 
* set to missing if past or present political opinions are missing for at least one indivudual   
replace CONV = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.
* set to missing if past political opinions of the two individuals were the same  
replace CONV = . if polpos_i1==polpos_i2

/// variable identifying couples where individuals' political opinion converged to that of each other	(weak convergence)
* generate variable equal to 0
gen CONVW = 0
* set to 1 if political opinions of two individuals were initially different and converged (weakly)
replace CONVW = 1 if (polpos_i1>polpos_i2 & inrange(polposnow_i1,polpos_i2,polpos_i1) & inrange(polposnow_i2,polpos_i2,polpos_i1)) | (polpos_i2>polpos_i1 & inrange(polposnow_i1,polpos_i1,polpos_i2) & inrange(polposnow_i2,polpos_i1,polpos_i2))
* set to missing if past or present political opinions are missing for at least one indivudual   
replace CONVW = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.
* set to missing if past political opinions of the two individuals were the same  
replace CONVW = . if polpos_i1==polpos_i2

/// Variable identifying if individual mainting their political opinon
cap drop ST
gen ST = 0
replace ST = 1 if polposnow_i1==polpos_i1 & polposnow_i2==polpos_i2
replace ST = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==. 

/// variable identifying couples where individuals' political opinion diverged relative to that of each other (weak convergence)
* generate variable equal to 0
gen DIVW = 0
* set to 1 if political opinions of two individuals converged (weakly)
replace DIVW = 1 if (polpos_i1>=polpos_i2 & polposnow_i1>=polpos_i1 & polposnow_i2<=polpos_i2) | (polpos_i1<=polpos_i2 & polposnow_i1<=polpos_i1 & polposnow_i2>=polpos_i2)
replace DIVW = 0 if ST==1
* set to missing if past or present political opinions are missing for at least one indivudual   
replace DIVW = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.


/// variable identifying couples where individuals' political opinion diverged relative to that of each other (strict convergence)
* generate variable equal to 0
gen DIVS = 0
* set to 1 if political opinions of two individuals converged (weakly)
replace DIVS = 1 if (polpos_i1>=polpos_i2 & polposnow_i1>polpos_i1 & polposnow_i2<polpos_i2) | (polpos_i1<=polpos_i2 & polposnow_i1<polpos_i1 & polposnow_i2>polpos_i2)
* set to missing if past or present political opinions are missing for at least one indivudual   
replace DIVS = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.

////// Variables based on associations  
/// variable identyfing couples where individuals are enrolled in at least one common association
* generate variable equal to 0
gen SameAsso = 0
* set to 1 if first association of first individual is equal to at least one of the associations of the second individual (and different from missing and from the missing code 0)
replace SameAsso = 1 if (q3_1uid_i1==q3_1uid_i2 | q3_1uid_i1==q3_2uid_i2 | q3_1uid_i1==q3_3uid_i2 | q3_1uid_i1==q3_4uid_i2 | q3_1uid_i1==q3_5uid_i2) & q3_1uid_i1!=. & q3_1uid_i1!=0
* set to 1 if second association of first individual is equal to at least one of the associations of the second individual (and different from missing and from the missing code 0)
replace SameAsso = 1 if (q3_2uid_i1==q3_1uid_i2 | q3_2uid_i1==q3_2uid_i2 | q3_2uid_i1==q3_3uid_i2 | q3_2uid_i1==q3_4uid_i2 | q3_2uid_i1==q3_5uid_i2) & q3_2uid_i1!=. & q3_2uid_i1!=0
* set to 1 if third association of first individual is equal to at least one of the associations of the second individual (and different from missing and from the missing code 0)
replace SameAsso = 1 if (q3_3uid_i1==q3_1uid_i2 | q3_3uid_i1==q3_2uid_i2 | q3_3uid_i1==q3_3uid_i2 | q3_3uid_i1==q3_4uid_i2 | q3_3uid_i1==q3_5uid_i2) & q3_3uid_i1!=. & q3_3uid_i1!=0
* set to 1 if fourth association of first individual is equal to at least one of the associations of the second individual (and different from missing and from the missing code 0)
replace SameAsso = 1 if (q3_4uid_i1==q3_1uid_i2 | q3_4uid_i1==q3_2uid_i2 | q3_4uid_i1==q3_3uid_i2 | q3_4uid_i1==q3_4uid_i2 | q3_4uid_i1==q3_5uid_i2) & q3_4uid_i1!=. & q3_4uid_i1!=0
* set to 1 if fifth association of first individual is equal to at least one of the associations of the second individual (and different from missing and from the missing code 0)
replace SameAsso = 1 if (q3_5uid_i1==q3_1uid_i2 | q3_5uid_i1==q3_2uid_i2 | q3_5uid_i1==q3_3uid_i2 | q3_5uid_i1==q3_4uid_i2 | q3_5uid_i1==q3_5uid_i2) & q3_5uid_i1!=. & q3_5uid_i1!=0
* set to missing if either individual report no association
replace SameAsso = . if q3_1uid_i1==.
replace SameAsso = . if q3_1uid_i2==.
	

/// variable identyfing couples where individuals are both enrolled in the sports association
* create variable identyfing sports associations based on prefix "AS" in association name
forval i = 1/5 {
	gen sports_`i'_i1 = strpos(q3_`i'_i1,"AS ")
	replace sports_`i'_i1 = 0 if q3_`i'uid_i1==.
	gen sports_`i'_i2 = strpos(q3_`i'_i2,"AS ")
	replace sports_`i'_i2 = 0 if q3_`i'uid_i2==.	
}
* create variable recording whether individual does at least one sport 
egen sports_i1 = rowmax(sports_1_i1 sports_2_i1 sports_3_i1 sports_4_i1 sports_5_i1)
egen sports_i2 = rowmax(sports_1_i2 sports_2_i2 sports_3_i2 sports_4_i2 sports_5_i2)
* generate variable equal to 1 if previous variables are the same for the two individuals and zero otherwise
gen SameSports = (sports_i1==sports_i2)
* set to missing if individual sports variables are missing
replace SameSports = . if sports_i1==. | sports_i2==.
* set to missing if individual association variables are missing
replace SameSports = . if q3_1uid_i1==. | q3_1uid_i2==.

* create variable recording whether indoviduals are in the same non-sport association
gen SameNonSports = SameAsso
replace SameNonSports=0 if SameSports==1

/// variables categorising associations in 9 groups (used to construct other variables)

* first association variable for indicdual 1
gen assoc1_i1 = 0
* 1 = Political association (treating mostly political issues, without being affiliated to a political party) + Political Parties/Associations (association directly linked to a political party)
replace assoc1_i1 =1 if s1_i1 == 43 | s1_i1 == 44 |  s1_i1 == 45 | s1_i1 == 46 | s1_i1 == 47 | s1_i1 == 48 | s1_i1 == 61 | s1_i1 == 95 | s1_i1 == 104 | s1_i1 == 105 | s1_i1 == 50 | s1_i1 == 55 | s1_i1 == 60 | s1_i1 == 64 | s1_i1 == 98      
* 2 = Student Unions (sometimes have clear political affiliations or affinities)
replace assoc1_i1 =2 if s1_i1 == 63 | s1_i1 == 83 | s1_i1 == 99
* 3 = Association with some political component (mostly debating societies)
replace assoc1_i1 =3 if s1_i1 == 73 | s1_i1 == 77 | s1_i1 == 78 | s1_i1 == 81 | s1_i1 == 88 | s1_i1 == 91
* 4 = Volunteering/Social Purposes
replace assoc1_i1 =4 if s1_i1 == 25 | s1_i1 == 69 | s1_i1 == 94 | s1_i1 == 100 | s1_i1 == 101 | s1_i1 == 102 | s1_i1 == 103 | s1_i1 == 26
* 5 = LGBTQ+ association
replace assoc1_i1 =5 if s1_i1 == 71
* 6 = Environmental protection association
replace assoc1_i1 =6 if s1_i1 == 89
* 7 = Religious association
replace assoc1_i1 =7 if s1_i1 == 41 | s1_i1 == 84 | s1_i1 == 97
* 8 = Regional/National association
replace assoc1_i1 =8 if s1_i1 == 23 | s1_i1 == 30 | s1_i1 == 42 |  s1_i1 == 57 | s1_i1 == 65 | s1_i1 == 70 | s1_i1 == 80 | s1_i1 == 85 |  s1_i1 == 96
* 9 = Subnational association
replace assoc1_i1 =9 if s1_i1 == 39 | s1_i1 == 86 | s1_i1 == 87 | s1_i1 == 92
* set to missing if association is missing
replace assoc1_i1 = . if s1_i1 == .

* first association variable for indicdual 2 (same classification, same encoding)
gen assoc1_i2 = 0
replace assoc1_i2 =1 if s1_i2 == 43 | s1_i2 == 44 |  s1_i2 == 45 | s1_i2 == 46 | s1_i2 == 47 | s1_i2 == 48 | s1_i2 == 61 | s1_i2 == 95 | s1_i2 == 104 | s1_i2 == 105 | s1_i2 == 50 | s1_i2 == 55 | s1_i2 == 60 | s1_i2 == 64 | s1_i2 == 98      
replace assoc1_i2 =2 if s1_i2 == 63 | s1_i2 == 83 | s1_i2 == 99
replace assoc1_i2 =3 if s1_i2 == 73 | s1_i2 == 77 | s1_i2 == 78 | s1_i2 == 81 | s1_i2 == 88 | s1_i2 == 91
replace assoc1_i2 =4 if s1_i2 == 25 | s1_i2 == 69 | s1_i2 == 94 | s1_i2 == 100 | s1_i2 == 101 | s1_i2 == 102 | s1_i2 == 103 | s1_i2 == 26
replace assoc1_i2 =5 if s1_i2 == 71
replace assoc1_i2 =6 if s1_i2 == 89
replace assoc1_i2 =7 if s1_i2 == 41 | s1_i2 == 84 | s1_i2 == 97
replace assoc1_i2 =8 if s1_i2 == 23 | s1_i2 == 30 | s1_i2 == 42 |  s1_i2 == 57 | s1_i2 == 65 | s1_i2 == 70 | s1_i2 == 80 | s1_i2 == 85 |  s1_i2 == 96
replace assoc1_i2 =9 if s1_i2 == 39 | s1_i2 == 86 | s1_i2 == 87 | s1_i2 == 92
replace assoc1_i2 = . if s1_i2 == .
* second association variable for indivdual 1 (same classification, different encoding compared to first association variable)
gen assoc2_i1 = 0
replace assoc2_i1 =1 if q3_2uid_i1==4788 | q3_2uid_i1==6465 | q3_2uid_i1==4819 | q3_2uid_i1==6771 | q3_2uid_i1==18 | q3_2uid_i1==8138 | q3_2uid_i1==7176 | q3_2uid_i1==9612 | q3_2uid_i1==2 | q3_2uid_i1==8085
replace assoc2_i1 =2 if q3_2uid_i1==3181 | q3_2uid_i1==4218
replace assoc2_i1 =3 if q3_2uid_i1==4 | q3_2uid_i1==19 | q3_2uid_i1==9567 | q3_2uid_i1== 3601
replace assoc2_i1 =4 if q3_2uid_i1==7549 | q3_2uid_i1==7622 | q3_2uid_i1==2280 | q3_2uid_i1==9740 | q3_2_i1== "Unicef" | q3_2_i1=="Unicef Sciences Po"  | q3_2_i1=="UNICEF" 
replace assoc2_i1 =5 if q3_2uid_i1==5908
replace assoc2_i1 =6 if q3_2uid_i1==1056
replace assoc2_i1 =7 if q3_2uid_i1==1945 | q3_2uid_i1==7751
replace assoc2_i1 =8 if q3_2uid_i1==9426 | q3_2uid_i1==2931  | q3_2uid_i1==5478  | q3_2uid_i1==6455 | q3_2_i1=="La Strada"
replace assoc2_i1 = . if s2_i1 == .
* second association variable for indivdual 2 (same classification, different encoding compared to first association variable)
gen assoc2_i2 = 0
replace assoc2_i2 =1 if q3_2uid_i2==4788 | q3_2uid_i2==6465 | q3_2uid_i2==4819 | q3_2uid_i2==6771 | q3_2uid_i2==18 | q3_2uid_i2==8138 | q3_2uid_i2==7176 | q3_2uid_i2==9612 | q3_2uid_i2==2 | q3_2uid_i2==8085
replace assoc2_i2 =2 if q3_2uid_i2==3181 | q3_2uid_i2==4218
replace assoc2_i2 =3 if q3_2uid_i2==4 | q3_2uid_i2==19 | q3_2uid_i2==9567 | q3_2uid_i2== 3601
replace assoc2_i2 =4 if q3_2uid_i2==7549 | q3_2uid_i2==7622 | q3_2uid_i2==2280 | q3_2uid_i2==9740 | q3_2_i2== "Unicef" | q3_2_i2=="Unicef Sciences Po"  | q3_2_i2=="UNICEF" 
replace assoc2_i2 =5 if q3_2uid_i2==5908
replace assoc2_i2 =6 if q3_2uid_i2==1056
replace assoc2_i2 =7 if q3_2uid_i2==1945 | q3_2uid_i2==7751
replace assoc2_i2 =8 if q3_2uid_i2==9426 | q3_2uid_i2==2931  | q3_2uid_i2==5478  | q3_2uid_i2==6455 | q3_2_i2=="La Strada"
replace assoc2_i2 = . if s2_i2 == .
* third association variable for indivdual 1 (same classification, different encoding compared to first association variable)
gen assoc3_i1 = 0
replace assoc3_i1 =1 if s3_i1==36 | s3_i1==59  | s3_i1==29  | s3_i1==38  | s3_i1==32  | s3_i1==39  | s3_i1==43  | s3_i1==31  | s3_i1==61  | s3_i1==44
replace assoc3_i1 =2 if s3_i1==62
replace assoc3_i1 =3 if s3_i1==54 | s3_i1==55 | s3_i1==47
replace assoc3_i1 =4 if s3_i1==56 | s3_i1==41 | s3_i1==63 | s3_i1==20
replace assoc3_i1 =6 if s3_i1==52
replace assoc3_i1 =8 if s3_i1==42 | s3_i1==19 | s3_i1==64 | s3_i1==50
replace assoc3_i1 =9 if s3_i1==51
replace assoc3_i1 = . if s3_i1 == .
* third association variable for indivdual 2 (same classification, different encoding compared to first association variable)
gen assoc3_i2 = 0
replace assoc3_i2 =1 if s3_i2==36 | s3_i2==59  | s3_i2==29  | s3_i2==38  | s3_i2==32  | s3_i2==39  | s3_i2==43  | s3_i2==31  | s3_i2==61  | s3_i2==44
replace assoc3_i2 =2 if s3_i2==62
replace assoc3_i2 =3 if s3_i2==54 | s3_i2==55 | s3_i2==47
replace assoc3_i2 =4 if s3_i2==56 | s3_i2==41 | s3_i2==63 | s3_i2==20
replace assoc3_i2 =6 if s3_i2==52
replace assoc3_i2 =8 if s3_i2==42 | s3_i2==19 | s3_i2==64 | s3_i2==50
replace assoc3_i2 =9 if s3_i2==51
replace assoc3_i2 = . if s3_i2 == .
* fourth association variable for indivdual 3 (same classification, different encoding compared to first association variable)
gen assoc4_i1 = 0
replace assoc4_i1 =1 if s4_i1==15 | s4_i1==16 | s4_i1==17 | s4_i1==18 | s4_i1==20 | s4_i1==24 | s4_i1==34
replace assoc4_i1 =2 if s4_i1==32
replace assoc4_i1 =3 if s4_i1==27 | s4_i1==29 | s4_i1==30
replace assoc4_i1 =4 if s4_i1==35
replace assoc4_i1 =7 if s4_i1==14
replace assoc4_i1 =8 if s4_i1==12 | s4_i1==22 | s4_i1==25
replace assoc4_i1 = . if s4_i1 == .
* fourth association variable for indivdual 1 (same classification, different encoding compared to first association variable)
gen assoc4_i2 = 0
replace assoc4_i2 =1 if s4_i2==15 | s4_i2==16 | s4_i2==17 | s4_i2==18 | s4_i2==20 | s4_i2==24 | s4_i2==34
replace assoc4_i2 =2 if s4_i2==32
replace assoc4_i2 =3 if s4_i2==27 | s4_i2==29 | s4_i2==30
replace assoc4_i2 =4 if s4_i2==35
replace assoc4_i2 =7 if s4_i2==14
replace assoc4_i2 =8 if s4_i2==12 | s4_i2==22 | s4_i2==25
replace assoc4_i2 = . if s4_i2 == .
* fifth association variable for indivdual 1 (same classification, different encoding compared to first association variable)
gen assoc5_i1 = 0
replace assoc5_i1 =1 if s5_i1 == 7 | s5_i1 == 8 
replace assoc5_i1 =3 if s5_i1 == 10 | s5_i1 == 13
replace assoc5_i1 =4 if s5_i1 == 14
replace assoc5_i1 =6 if s5_i1 == 12
replace assoc5_i1 =8 if s5_i1 == 9 
replace assoc5_i1 = . if s5_i1 == .
* fifth association variable for indivdual 2 (same classification, different encoding compared to first association variable)
gen assoc5_i2 = 0
replace assoc5_i2 =1 if s5_i2 == 7 | s5_i2 == 8 
replace assoc5_i2 =3 if s5_i2 == 10 | s5_i2 == 13
replace assoc5_i2 =4 if s5_i2 == 14
replace assoc5_i2 =6 if s5_i2 == 12
replace assoc5_i2 =8 if s5_i2 == 9 
replace assoc5_i2 = . if s5_i2 == .
* drop intermediate variables
drop s1_i1 s2_i1 s3_i1 s4_i1 s5_i1 s1_i2 s2_i2 s3_i2 s4_i2 s5_i2

/// variable identyfing couples where individuals are both enrolled in associations with political characteristics
* generate variable equal to 0
gen SameAsso_Type_Pol = 0
* set to 1 if first association of first individual is equal to at least one of the associations of the second individual and is political association (and different from missing and from the missing code 0)
replace SameAsso_Type_Pol = 1 if (q3_1uid_i1==q3_1uid_i2 | q3_1uid_i1==q3_2uid_i2 | q3_1uid_i1==q3_3uid_i2 | q3_1uid_i1==q3_4uid_i2 | q3_1uid_i1==q3_5uid_i2) & q3_1uid_i1!=. & q3_1uid_i1!=0 & inlist(assoc1_i1,1,2,3)
* set to 1 if second association of first individual is equal to at least one of the associations of the second individual and is political association (and different from missing and from the missing code 0)
replace SameAsso_Type_Pol = 1 if (q3_2uid_i1==q3_1uid_i2 | q3_2uid_i1==q3_2uid_i2 | q3_2uid_i1==q3_3uid_i2 | q3_2uid_i1==q3_4uid_i2 | q3_2uid_i1==q3_5uid_i2) & q3_2uid_i1!=. & q3_2uid_i1!=0 & inlist(assoc2_i1,1,2,3)
* set to 1 if third association of first individual is equal to at least one of the associations of the second individual and is political association (and different from missing and from the missing code 0)
replace SameAsso_Type_Pol = 1 if (q3_3uid_i1==q3_1uid_i2 | q3_3uid_i1==q3_2uid_i2 | q3_3uid_i1==q3_3uid_i2 | q3_3uid_i1==q3_4uid_i2 | q3_3uid_i1==q3_5uid_i2) & q3_3uid_i1!=. & q3_3uid_i1!=0 & inlist(assoc3_i1,1,2,3)
* set to 1 if fourth association of first individual is equal to at least one of the associations of the second individual and is political association (and different from missing and from the missing code 0)
replace SameAsso_Type_Pol = 1 if (q3_4uid_i1==q3_1uid_i2 | q3_4uid_i1==q3_2uid_i2 | q3_4uid_i1==q3_3uid_i2 | q3_4uid_i1==q3_4uid_i2 | q3_4uid_i1==q3_5uid_i2) & q3_4uid_i1!=. & q3_4uid_i1!=0 & inlist(assoc4_i1,1,2,3)
* set to 1 if fifth association of first individual is equal to at least one of the associations of the second individual and is political association (and different from missing and from the missing code 0)
replace SameAsso_Type_Pol = 1 if (q3_5uid_i1==q3_1uid_i2 | q3_5uid_i1==q3_2uid_i2 | q3_5uid_i1==q3_3uid_i2 | q3_5uid_i1==q3_4uid_i2 | q3_5uid_i1==q3_5uid_i2) & q3_5uid_i1!=. & q3_5uid_i1!=0 & inlist(assoc5_i1,1,2,3)
* set to missing if either individual report no association
replace SameAsso_Type_Pol = . if q3_1uid_i1==.
replace SameAsso_Type_Pol = . if q3_1uid_i2==.
	
/// variable identyfing couples where individuals are both enrolled in associations with a policy focus
* generate variable equal to 0
gen SameAsso_Type_Ply = 0
* set to 1 if first association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Ply = 1 if (q3_1uid_i1==q3_1uid_i2 | q3_1uid_i1==q3_2uid_i2 | q3_1uid_i1==q3_3uid_i2 | q3_1uid_i1==q3_4uid_i2 | q3_1uid_i1==q3_5uid_i2) & q3_1uid_i1!=. & q3_1uid_i1!=0 & inlist(assoc1_i1,4,6)
* set to 1 if second association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Ply = 1 if (q3_2uid_i1==q3_1uid_i2 | q3_2uid_i1==q3_2uid_i2 | q3_2uid_i1==q3_3uid_i2 | q3_2uid_i1==q3_4uid_i2 | q3_2uid_i1==q3_5uid_i2) & q3_2uid_i1!=. & q3_2uid_i1!=0 & inlist(assoc2_i1,4,6)
* set to 1 if third association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Ply = 1 if (q3_3uid_i1==q3_1uid_i2 | q3_3uid_i1==q3_2uid_i2 | q3_3uid_i1==q3_3uid_i2 | q3_3uid_i1==q3_4uid_i2 | q3_3uid_i1==q3_5uid_i2) & q3_3uid_i1!=. & q3_3uid_i1!=0 & inlist(assoc3_i1,4,6)
* set to 1 if fourth association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Ply = 1 if (q3_4uid_i1==q3_1uid_i2 | q3_4uid_i1==q3_2uid_i2 | q3_4uid_i1==q3_3uid_i2 | q3_4uid_i1==q3_4uid_i2 | q3_4uid_i1==q3_5uid_i2) & q3_4uid_i1!=. & q3_4uid_i1!=0 & inlist(assoc4_i1,4,6)
* set to 1 if fifth association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Ply = 1 if (q3_5uid_i1==q3_1uid_i2 | q3_5uid_i1==q3_2uid_i2 | q3_5uid_i1==q3_3uid_i2 | q3_5uid_i1==q3_4uid_i2 | q3_5uid_i1==q3_5uid_i2) & q3_5uid_i1!=. & q3_5uid_i1!=0 & inlist(assoc5_i1,4,6)
* set to missing if either individual report no association
replace SameAsso_Type_Ply = . if q3_1uid_i1==.
replace SameAsso_Type_Ply = . if q3_1uid_i2==.
	
/// variable identyfing couples where individuals are both enrolled in associations related to individuals' identities
* generate variable equal to 0
gen SameAsso_Type_Iden = 0
* set to 1 if first association of first individual is equal to at least one of the associations of the second individual and is an identity focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Iden = 1 if (q3_1uid_i1==q3_1uid_i2 | q3_1uid_i1==q3_2uid_i2 | q3_1uid_i1==q3_3uid_i2 | q3_1uid_i1==q3_4uid_i2 | q3_1uid_i1==q3_5uid_i2) & q3_1uid_i1!=. & q3_1uid_i1!=0 & inlist(assoc1_i1,5,7,8,9)
* set to 1 if second association of first individual is equal to at least one of the associations of the second individual and is an identity focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Iden = 1 if (q3_2uid_i1==q3_1uid_i2 | q3_2uid_i1==q3_2uid_i2 | q3_2uid_i1==q3_3uid_i2 | q3_2uid_i1==q3_4uid_i2 | q3_2uid_i1==q3_5uid_i2) & q3_2uid_i1!=. & q3_2uid_i1!=0 & inlist(assoc2_i1,5,7,8,9)
* set to 1 if third association of first individual is equal to at least one of the associations of the second individual and is a identity focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Iden = 1 if (q3_3uid_i1==q3_1uid_i2 | q3_3uid_i1==q3_2uid_i2 | q3_3uid_i1==q3_3uid_i2 | q3_3uid_i1==q3_4uid_i2 | q3_3uid_i1==q3_5uid_i2) & q3_3uid_i1!=. & q3_3uid_i1!=0 & inlist(assoc3_i1,5,7,8,9)
* set to 1 if fourth association of first individual is equal to at least one of the associations of the second individual and is a identity focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Iden = 1 if (q3_4uid_i1==q3_1uid_i2 | q3_4uid_i1==q3_2uid_i2 | q3_4uid_i1==q3_3uid_i2 | q3_4uid_i1==q3_4uid_i2 | q3_4uid_i1==q3_5uid_i2) & q3_4uid_i1!=. & q3_4uid_i1!=0 & inlist(assoc4_i1,5,7,8,9)
* set to 1 if fifth association of first individual is equal to at least one of the associations of the second individual and is a policy focused association (and different from missing and from the missing code 0)
replace SameAsso_Type_Iden = 1 if (q3_5uid_i1==q3_1uid_i2 | q3_5uid_i1==q3_2uid_i2 | q3_5uid_i1==q3_3uid_i2 | q3_5uid_i1==q3_4uid_i2 | q3_5uid_i1==q3_5uid_i2) & q3_5uid_i1!=. & q3_5uid_i1!=0 & inlist(assoc5_i1,5,7,8,9)
* set to missing if either individual report no association
replace SameAsso_Type_Iden = . if q3_1uid_i1==.
replace SameAsso_Type_Iden = . if q3_1uid_i2==.

/// variable identifying whether couples of individuals are enrolled in a political association (not necessarily the same one)
*** individual variables
global Asso123List = "2, 1396, 4788, 4819, 6100, 6465, 7176, 8085, 8399, 9612,3181, 4218, 6264, 4, 3601, 8434, 9567"
gen Asso123_i1 = 0
replace Asso123_i1 = 1 if inlist(q3_1uid_i1,$Asso123List) | inlist(q3_2uid_i1,$Asso123List) | inlist(q3_3uid_i1,$Asso123List) | inlist(q3_4uid_i1,$Asso123List) | inlist(q3_5uid_i1,$Asso123List)
replace Asso123_i1 = . if q3_1uid_i1==.
gen Asso123_i2 = 0
replace Asso123_i2 = 1 if inlist(q3_1uid_i2,$Asso123List) | inlist(q3_2uid_i2,$Asso123List) | inlist(q3_3uid_i2,$Asso123List) | inlist(q3_4uid_i2,$Asso123List) | inlist(q3_5uid_i2,$Asso123List)
replace Asso123_i2 = . if q3_1uid_i2==.
*** both are enrolled in political associations
gen BothAsso123 = (min(Asso123_i1,Asso123_i2)==1)
replace BothAsso123 = . if Asso123_i1==. | Asso123_i2==.
*** both are enrolled in political associations but not in the same association
gen BothTypeDiffAsso123 = 0
replace BothTypeDiffAsso123 = 1 if BothAsso123==1 & SameAsso_Type_Pol==0
replace BothTypeDiffAsso123 = . if Asso123_i1==. | Asso123_i2==.

/// variable identifying couples where both individuals are living in Paris or both are living outside of Paris
* create variable equal to 1 if both individuals live in Paris or both individuals live outside of Paris and zero otherwse
gen Paris =.
replace Paris = 1 if code_i1==code_i2
replace Paris = 0 if code_i1!=code_i2
* set variable to missing if the variable recording the zip code for either individual is missing 
replace Paris=. if code_i1==.
replace Paris=. if code_i2==.	
	
/// variable identyfing couples where both individuals did their high-school in the Paris region
* create variable equal to 1 if both individuals studied in the Paris region and 0 otherwise 
//gen IDFBAC = (new_regb_i1==12) & (new_regb_i2==12)
gen IDFBAC = (regionbac_i1==12) & (regionbac_i2==12)
	
/// variable identifying couples of individuals whose parents have the same profession
* encode string variables on parents professions
encode CSPniv3parent1_i1, generate(parent1_i1)
encode CSPniv3parent2_i1, generate(parent2_i1)
encode CSPniv3parent1_i2, generate(parent1_i2)
encode CSPniv3parent2_i2, generate(parent2_i2)
* generate occupational class for parent 1 individual 1
gen pari1_i1=.
replace pari1_i1=1 if parent1_i1==16 | parent1_i1==17
replace pari1_i1=2 if parent1_i1==3
replace pari1_i1=3 if parent1_i1==4 | parent1_i1==5 | parent1_i1==6
replace pari1_i1=4 if parent1_i1==1 | parent1_i1==2 | parent1_i1==8 | parent1_i1==28 | parent1_i1==27
replace pari1_i1=5 if parent1_i1==10 | parent1_i1==11 | parent1_i1==12 | parent1_i1==14 | parent1_i1==19 | parent1_i1==18 | parent1_i1==31 | parent1_i1==30
replace pari1_i1=6 if parent1_i1==9 | parent1_i1==13 | parent1_i1==24 | parent1_i1==23 | parent1_i1==25 | parent1_i1==29
replace pari1_i1=7 if parent1_i1==7
replace pari1_i1=8 if parent1_i1==20
replace pari1_i1=9 if parent1_i1==21 | parent1_i1==22
replace pari1_i1=10 if parent1_i1==26
* generate occupational class for parent 2 individual 1
gen pari2_i1=.
replace pari2_i1=1 if parent2_i1==17 | parent2_i1==18
replace pari2_i1=2 if parent2_i1==3 | parent2_i1==7
replace pari2_i1=3 if parent2_i1==4 | parent2_i1==5 | parent2_i1==6
replace pari2_i1=4 if parent2_i1==1 | parent2_i1==2 | parent2_i1==9
replace pari2_i1=5 if parent2_i1==11 | parent2_i1==12 | parent2_i1==13 | parent2_i1==15 | parent2_i1==20 | parent2_i1==19 | parent2_i1==30 | parent2_i1==29
replace pari2_i1=6 if parent2_i1==10 | parent2_i1==14 | parent2_i1==25 | parent2_i1==24 | parent2_i1==26 | parent2_i1==28
replace pari2_i1=7 if parent2_i1==8
replace pari2_i1=8 if parent2_i1==21
replace pari2_i1=9 if parent2_i1==22 | parent2_i1==23
replace pari2_i1=10 if parent2_i1==27
* generate occupational class for parent 1 individual 2
gen pari1_i2=.
replace pari1_i2=1 if parent1_i2==16 | parent1_i2==17
replace pari1_i2=2 if parent1_i2==3
replace pari1_i2=3 if parent1_i2==4 | parent1_i2==5 | parent1_i2==6
replace pari1_i2=4 if parent1_i2==1 | parent1_i2==2 | parent1_i2==8 | parent1_i2==28 | parent1_i2==27
replace pari1_i2=5 if parent1_i2==10 | parent1_i2==11 | parent1_i2==12 | parent1_i2==14 | parent1_i2==19 | parent1_i2==18 | parent1_i2==31 | parent1_i2==30
replace pari1_i2=6 if parent1_i2==9 | parent1_i2==13 | parent1_i2==24 | parent1_i2==23 | parent1_i2==25 | parent1_i2==29
replace pari1_i2=7 if parent1_i2==7
replace pari1_i2=8 if parent1_i2==20
replace pari1_i2=9 if parent1_i2==21 | parent1_i2==22
replace pari1_i2=10 if parent1_i2==26
* generate occupational class for parent 2 individual 2
gen pari2_i2=.
replace pari2_i2=1 if parent2_i2==17 | parent2_i2==18
replace pari2_i2=2 if parent2_i2==3 | parent2_i2==7
replace pari2_i2=3 if parent2_i2==4 | parent2_i2==5 | parent2_i2==6
replace pari2_i2=4 if parent2_i2==1 | parent2_i2==2 | parent2_i2==9
replace pari2_i2=5 if parent2_i2==11 | parent2_i2==12 | parent2_i2==13 | parent2_i2==15 | parent2_i2==20 | parent2_i2==19 | parent2_i2==30 | parent2_i2==29
replace pari2_i2=6 if parent2_i2==10 | parent2_i2==14 | parent2_i2==25 | parent2_i2==24 | parent2_i2==26 | parent2_i2==28
replace pari2_i2=7 if parent2_i2==8
replace pari2_i2=8 if parent2_i2==21
replace pari2_i2=9 if parent2_i2==22 | parent2_i2==23
replace pari2_i2=10 if parent2_i2==27
* create variable equal to 0
gen PARI=0
* set variable to 1 if individulas have at least one parent in the same occupational category
replace PARI=1 if pari1_i1==pari1_i2 | pari1_i1==pari2_i2 | pari2_i1==pari1_i2 | pari2_i1==pari2_i2
* set to missing if occupation of any parent is missing
replace PARI=. if pari1_i1==. | pari2_i1==. | pari1_i2==. | pari2_i2==.

/// variable identifying couples that did their high school diploma in the same region
//gen REGBAC = (new_regb_i1 == new_regb_i2) if new_regb_i1~=. & new_regb_i2~=.
gen REGBAC = (regionbac_i1 == regionbac_i2) if regionbac_i1~=. & regionbac_i2~=.

/// variable identifying couples where both individuals do not pay any tuition fees
* create variable equal to 1 if individuals are in the same tuition fee category (no tutiton vs tuition)
gen NOFEE = (nofee_i1==nofee_i2)

/// variable flagging convergence in political opinion
* generate variables recording direction of change in political opinion for each individual
gen DIR_i1 = sign(polposnow_i1-polpos_i1)
gen DIR_i2 = sign(polposnow_i2-polpos_i2)
* generate variable equal to 1 if the individuals' political opinion is weakly converging 
gen CONV2 = ((DIR_i1 >=0) & (DIR_i2 <=0) & (polposnow_i1 <= polposnow_i2)) | ((DIR_i1 <=0) & (DIR_i2 >=0) & (polposnow_i1 >= polposnow_i2))
* generate variable equal to 1 if the individuals' political opinion is strictly converging 
gen CONVS2 = CONV2
replace CONVS2 = 0 if DIR_i1==0 | DIR_i2==0

////// Variables for permutation test (based on external ranking)
*** merge name ranking for individual 1
merge m:1 uid_i1 using "$path/Data/Intermediate/name_ranking_i1.dta"
keep if _merge!=2
drop _merge
*** merge name ranking for individual 2
merge m:1 uid_i2 using "$path/Data/Intermediate/name_ranking_i2.dta"
keep if _merge!=2
drop _merge
*** generate variable recording distance in ranking of names between the two individuals
gen DiffAlphaRankExt = abs(AlphaRankExt_i1 - AlphaRankExt_i2)
*** generate variable recording close difference in ranking (less or equal to 30)
gen CloseAlphaRankExt=(DiffAlphaRankExt<=30)

////// Variables for permutation test (based on internal ranking)
*** merge name ranking for individual 1
merge m:1 uid_i1 using "$path/Data/Intermediate/name_ranking_internal_i1.dta"
keep if _merge!=2
drop _merge
*** merge name ranking for individual 2
merge m:1 uid_i2 using "$path/Data/Intermediate/name_ranking_internal_i2.dta"
keep if _merge!=2
drop _merge
*** generate variable recording distance in ranking of names between the two individuals
gen DiffAlphaRank = abs(AlphaRank_i1 - AlphaRank_i2)
*** generate circular ranking distance
gen DistAlphaRank = min(DiffAlphaRank, 799-DiffAlphaRank)
*** generate variable equal to 1 if the circular distance is below 48 and 0 otherwise
gen CloseAlphaRank=(DistAlphaRank<=32)
*** generate variable that is the minumum between the circular distance and 32 (equal to the average size of an integration group)
gen AlphaDistIV = min(DistAlphaRank, 24)
*** generate variable that is equal to 1 if both individuals are in the same predicted integration group based on their ranking of names (based on average group size of 32)
gen AlphaHypGroup_i1 = ceil((AlphaRank_i1+15)/16)
gen AlphaHypGroup_i2 = ceil((AlphaRank_i2+15)/16)
gen SameAlphaHypGroupIV = (AlphaHypGroup_i1==AlphaHypGroup_i2)


////// additional based on 2015 survey
* merge with 2015 data
merge m:1 uid_i1 using "$path/Data/Raw/2015_individual_i1.dta"
drop _merge
merge m:1 uid_i2 using "$path/Data/Raw/2015_individual_i2.dta"
drop _merge

* create variable on ong-term change in political opinions
cap drop DiffPPa_15 DiffPP_15
gen DiffPPa_15 = abs(polposnow_15_i1-polposnow_15_i2)
gen DiffPP_15 = abs(polpos_15_i1-polpos_15_i2)
cap drop ChangePP_15 ChangePP_Long ChangePPa
gen ChangePP_15 = DiffPPa_15 - DiffPP_15
gen ChangePP_Long = DiffPPa_15 - DiffPP
gen ChangePPa = DiffPPa_15 - DiffPPa

cap drop DIR_Long_i1 DIR_Long_i2
cap drop CONV2_Long CONVS2_Long
gen DIR_Long_i1 = sign(polposnow_15_i1-polpos_i1)
gen DIR_Long_i2 = sign(polposnow_15_i2-polpos_i2)

cap drop CONV2_Long CONVS2_Long
gen CONV2_Long = ((DIR_Long_i1 >=0) & (DIR_Long_i2 <=0) & (polposnow_15_i1 <= polposnow_15_i2)) | ((DIR_Long_i1 <=0) & (DIR_Long_i2 >=0) & (polposnow_15_i1 >= polposnow_15_i2))
replace CONV2_Long = . if DIR_Long_i1==. | DIR_Long_i2==.
gen CONVS2_Long = CONV2_Long
replace CONVS2_Long = 0 if DIR_Long_i1==0 | DIR_Long_i2==0
replace CONVS2_Long = . if DIR_Long_i1==. | DIR_Long_i2==.

cap drop DIVW_Long
gen DIVW_Long = 0
replace DIVW_Long = 1 if (polpos_i1>=polpos_i2 & DIR_Long_i1>=0 & DIR_Long_i2<=0) | (polpos_i1<=polpos_i2 & DIR_Long_i1<=0 & DIR_Long_i2>=0)
replace DIVW_Long = . if polposnow_15_i1==. | polpos_i1==. | polposnow_15_i2==. | polpos_i2==.
replace  DIVW_Long = . if DIR_Long_i1==. | DIR_Long_i2==.

cap drop DIV_Long 
gen DIV_Long = 0
replace DIV_Long = 1 if (polpos_i1>=polpos_i2 & DIR_Long_i1>0 & DIR_Long_i2<0) | (polpos_i1<=polpos_i2 & DIR_Long_i1<0 & DIR_Long_i2>0)
replace DIV_Long = . if polposnow_i1==. | polpos_i1==. | polposnow_i2==. | polpos_i2==.
replace  DIV_Long = . if DIR_Long_i1==. | DIR_Long_i2==.

cap drop DIVS_Long
ren DIV_Long DIVS_Long

cap drop COMOV_Long
gen COMOV_Long = 0
replace COMOV_Long = 1 if DIR_Long_i1 * DIR_Long_i2 > 0
replace COMOV_Long = . if polposnow_15_i1==. | polpos_15_i1==. | polposnow_15_i2==. | polpos_15_i2==.  // move in same direction
replace  COMOV_Long = . if DIR_Long_i1==. | DIR_Long_i2==.


** variable counting the number of sciences po firends
gen fr_i1=0
replace fr_i1=1 if q1_1uid_i1 !=. & q1_1uid_i1 !=0
replace fr_i1=2 if q1_2uid_i1 !=. & q1_2uid_i1 !=0
replace fr_i1=3 if q1_3uid_i1 !=. & q1_3uid_i1 !=0
replace fr_i1=4 if q1_4uid_i1 !=. & q1_4uid_i1 !=0
replace fr_i1=5 if q1_5uid_i1 !=. & q1_5uid_i1 !=0
replace fr_i1=6 if q1_6uid_i1 !=. & q1_6uid_i1 !=0
replace fr_i1=7 if q1_7uid_i1 !=. & q1_7uid_i1 !=0
replace fr_i1=8 if q1_8uid_i1 !=. & q1_8uid_i1 !=0
replace fr_i1=9 if q1_9uid_i1 !=. & q1_9uid_i1 !=0
replace fr_i1=10 if q1_10uid_i1 !=. & q1_10uid_i1 !=0
replace fr_i1=. if q1_1uid_i1==.

gen fr_i2=0
replace fr_i2=1 if q1_1uid_i2 !=. & q1_1uid_i2 !=0
replace fr_i2=2 if q1_2uid_i2 !=. & q1_2uid_i2 !=0
replace fr_i2=3 if q1_3uid_i2 !=. & q1_3uid_i2 !=0
replace fr_i2=4 if q1_4uid_i2 !=. & q1_4uid_i2 !=0
replace fr_i2=5 if q1_5uid_i2 !=. & q1_5uid_i2 !=0
replace fr_i2=6 if q1_6uid_i2 !=. & q1_6uid_i2 !=0
replace fr_i2=7 if q1_7uid_i2 !=. & q1_7uid_i2 !=0
replace fr_i2=8 if q1_8uid_i2 !=. & q1_8uid_i2 !=0
replace fr_i2=9 if q1_9uid_i2 !=. & q1_9uid_i2 !=0
replace fr_i2=10 if q1_10uid_i2 !=. & q1_10uid_i2 !=0
replace fr_i2=. if q1_1uid_i2==.

**  variable recording where friends met
gen meet_i1 = .
replace meet_i1 = q1_1if_i1 if q1_1uid_i1==uid_i2
replace meet_i1 = q1_2if_i1 if q1_2uid_i1==uid_i2
replace meet_i1 = q1_3if_i1 if q1_3uid_i1==uid_i2
replace meet_i1 = q1_4if_i1 if q1_4uid_i1==uid_i2
replace meet_i1 = q1_5if_i1 if q1_5uid_i1==uid_i2
replace meet_i1 = q1_6if_i1 if q1_6uid_i1==uid_i2
replace meet_i1 = q1_7if_i1 if q1_7uid_i1==uid_i2
replace meet_i1 = q1_8if_i1 if q1_8uid_i1==uid_i2
replace meet_i1 = q1_9if_i1 if q1_9uid_i1==uid_i2
replace meet_i1 = q1_10if_i1 if q1_10uid_i1==uid_i2

gen meet_i2 = .
replace meet_i2 = q1_1if_i2 if q1_1uid_i2==uid_i1
replace meet_i2 = q1_2if_i2 if q1_2uid_i2==uid_i1
replace meet_i2 = q1_3if_i2 if q1_3uid_i2==uid_i1
replace meet_i2 = q1_4if_i2 if q1_4uid_i2==uid_i1
replace meet_i2 = q1_5if_i2 if q1_5uid_i2==uid_i1
replace meet_i2 = q1_6if_i2 if q1_6uid_i2==uid_i1
replace meet_i2 = q1_7if_i2 if q1_7uid_i2==uid_i1
replace meet_i2 = q1_8if_i2 if q1_8uid_i2==uid_i1
replace meet_i2 = q1_9if_i2 if q1_9uid_i2==uid_i1
replace meet_i2 = q1_10if_i2 if q1_10uid_i2==uid_i1


** based on the amount of time spent together
gen time_i1 = .
replace time_i1 = q1_1at_i1 if q1_1uid_i1==uid_i2
replace time_i1 = q1_2at_i1 if q1_2uid_i1==uid_i2
replace time_i1 = q1_3at_i1 if q1_3uid_i1==uid_i2
replace time_i1 = q1_4at_i1 if q1_4uid_i1==uid_i2
replace time_i1 = q1_5at_i1 if q1_5uid_i1==uid_i2
replace time_i1 = q1_6at_i1 if q1_6uid_i1==uid_i2
replace time_i1 = q1_7at_i1 if q1_7uid_i1==uid_i2
replace time_i1 = q1_8at_i1 if q1_8uid_i1==uid_i2
replace time_i1 = q1_9at_i1 if q1_9uid_i1==uid_i2
replace time_i1 = q1_10at_i1 if q1_10uid_i1==uid_i2

gen time_i2 = .
replace time_i2 = q1_1at_i2 if q1_1uid_i2==uid_i1
replace time_i2 = q1_2at_i2 if q1_2uid_i2==uid_i1
replace time_i2 = q1_3at_i2 if q1_3uid_i2==uid_i1
replace time_i2 = q1_4at_i2 if q1_4uid_i2==uid_i1
replace time_i2 = q1_5at_i2 if q1_5uid_i2==uid_i1
replace time_i2 = q1_6at_i2 if q1_6uid_i2==uid_i1
replace time_i2 = q1_7at_i2 if q1_7uid_i2==uid_i1
replace time_i2 = q1_8at_i2 if q1_8uid_i2==uid_i1
replace time_i2 = q1_9at_i2 if q1_9uid_i2==uid_i1
replace time_i2 = q1_10at_i2 if q1_10uid_i2==uid_i1

cap drop LULtime*
forval i = 1/4 {
	gen LULtime`i' = LUL & ((time_i1==`i')|(time_i2==`i'))   // time_i1 = q1_1at_i1, etc.
}
 

** variable based on the activities perfomed with the other member of the couple
gen activity_i1 = .
replace activity_i1 = q1_1cb_i1 if q1_1uid_i1==uid_i2
replace activity_i1 = q1_2cb_i1 if q1_2uid_i1==uid_i2
replace activity_i1 = q1_3cb_i1 if q1_3uid_i1==uid_i2
replace activity_i1 = q1_4cb_i1 if q1_4uid_i1==uid_i2
replace activity_i1 = q1_5cb_i1 if q1_5uid_i1==uid_i2
replace activity_i1 = q1_6cb_i1 if q1_6uid_i1==uid_i2
replace activity_i1 = q1_7cb_i1 if q1_7uid_i1==uid_i2
replace activity_i1 = q1_8cb_i1 if q1_8uid_i1==uid_i2
replace activity_i1 = q1_9cb_i1 if q1_9uid_i1==uid_i2
replace activity_i1 = q1_10cb_i1 if q1_10uid_i1==uid_i2

gen activity_i2 = .
replace activity_i2 = q1_1cb_i2 if q1_1uid_i2==uid_i1
replace activity_i2 = q1_2cb_i2 if q1_2uid_i2==uid_i1
replace activity_i2 = q1_3cb_i2 if q1_3uid_i2==uid_i1
replace activity_i2 = q1_4cb_i2 if q1_4uid_i2==uid_i1
replace activity_i2 = q1_5cb_i2 if q1_5uid_i2==uid_i1
replace activity_i2 = q1_6cb_i2 if q1_6uid_i2==uid_i1
replace activity_i2 = q1_7cb_i2 if q1_7uid_i2==uid_i1
replace activity_i2 = q1_8cb_i2 if q1_8uid_i2==uid_i1
replace activity_i2 = q1_9cb_i2 if q1_9uid_i2==uid_i1
replace activity_i2 = q1_10cb_i2 if q1_10uid_i2==uid_i1
*/

cap drop LULactiv*
forval i = 1/5 {
	gen LULactiv`i' = LUL & ((activity_i1==`i')|(activity_i2==`i'))   // activity_i1 = q1_1cb_i1, q1_2cb_i1, q1_3cb_i1 etc.
}


** variable based on the strength of relationship
gen strength_i1 = .
replace strength_i1 = q1_1fr_i1 if q1_1uid_i1==uid_i2
replace strength_i1 = q1_2fr_i1 if q1_2uid_i1==uid_i2
replace strength_i1 = q1_3fr_i1 if q1_3uid_i1==uid_i2
replace strength_i1 = q1_4fr_i1 if q1_4uid_i1==uid_i2
replace strength_i1 = q1_5fr_i1 if q1_5uid_i1==uid_i2
replace strength_i1 = q1_6fr_i1 if q1_6uid_i1==uid_i2
replace strength_i1 = q1_7fr_i1 if q1_7uid_i1==uid_i2
replace strength_i1 = q1_8fr_i1 if q1_8uid_i1==uid_i2
replace strength_i1 = q1_9fr_i1 if q1_9uid_i1==uid_i2
replace strength_i1 = q1_10fr_i1 if q1_10uid_i1==uid_i2

gen strength_i2 = .
replace strength_i2 = q1_1fr_i2 if q1_1uid_i2==uid_i1
replace strength_i2 = q1_2fr_i2 if q1_2uid_i2==uid_i1
replace strength_i2 = q1_3fr_i2 if q1_3uid_i2==uid_i1
replace strength_i2 = q1_4fr_i2 if q1_4uid_i2==uid_i1
replace strength_i2 = q1_5fr_i2 if q1_5uid_i2==uid_i1
replace strength_i2 = q1_6fr_i2 if q1_6uid_i2==uid_i1
replace strength_i2 = q1_7fr_i2 if q1_7uid_i2==uid_i1
replace strength_i2 = q1_8fr_i2 if q1_8uid_i2==uid_i1
replace strength_i2 = q1_9fr_i2 if q1_9uid_i2==uid_i1
replace strength_i2 = q1_10fr_i2 if q1_10uid_i2==uid_i1

gen LULint=strength_i1
replace LULint=strength_i2 if strength_i1==.
replace LULint=1 if LULint==0 & LUL==1
replace LULint=0 if LULint==.

* variables recording friendship intensity by level (separately)
gen str_fr_1=0
replace str_fr_1 = 1 if q1_1uid_i1 == uid_i2 & q1_1fr_i1>=1
replace str_fr_1 = 1 if q1_2uid_i1 == uid_i2 & q1_2fr_i1>=1
replace str_fr_1 = 1 if q1_3uid_i1 == uid_i2 & q1_3fr_i1>=1
replace str_fr_1 = 1 if q1_4uid_i1 == uid_i2 & q1_4fr_i1>=1
replace str_fr_1 = 1 if q1_5uid_i1 == uid_i2 & q1_5fr_i1>=1
replace str_fr_1 = 1 if q1_6uid_i1 == uid_i2 & q1_6fr_i1>=1
replace str_fr_1 = 1 if q1_7uid_i1 == uid_i2 & q1_7fr_i1>=1
replace str_fr_1 = 1 if q1_8uid_i1 == uid_i2 & q1_8fr_i1>=1
replace str_fr_1 = 1 if q1_9uid_i1 == uid_i2 & q1_9fr_i1>=1
replace str_fr_1 = 1 if q1_10uid_i1 == uid_i2 & q1_10fr_i1>=1
replace str_fr_1 = 1 if q1_1uid_i2 == uid_i1 & q1_1fr_i2>=1
replace str_fr_1 = 1 if q1_2uid_i2 == uid_i1 & q1_2fr_i2>=1
replace str_fr_1 = 1 if q1_3uid_i2 == uid_i1 & q1_3fr_i2>=1
replace str_fr_1 = 1 if q1_4uid_i2 == uid_i1 & q1_4fr_i2>=1
replace str_fr_1 = 1 if q1_5uid_i2 == uid_i1 & q1_5fr_i2>=1
replace str_fr_1 = 1 if q1_6uid_i2 == uid_i1 & q1_6fr_i2>=1
replace str_fr_1 = 1 if q1_7uid_i2 == uid_i1 & q1_7fr_i2>=1
replace str_fr_1 = 1 if q1_8uid_i2 == uid_i1 & q1_8fr_i2>=1
replace str_fr_1 = 1 if q1_9uid_i2 == uid_i1 & q1_9fr_i2>=1
replace str_fr_1 = 1 if q1_10uid_i2 == uid_i1 & q1_10fr_i2>=1

gen str_fr_2=0
replace str_fr_2 = 1 if q1_1uid_i1 == uid_i2 & q1_1fr_i1>=2
replace str_fr_2 = 1 if q1_2uid_i1 == uid_i2 & q1_2fr_i1>=2
replace str_fr_2 = 1 if q1_3uid_i1 == uid_i2 & q1_3fr_i1>=2
replace str_fr_2 = 1 if q1_4uid_i1 == uid_i2 & q1_4fr_i1>=2
replace str_fr_2 = 1 if q1_5uid_i1 == uid_i2 & q1_5fr_i1>=2
replace str_fr_2 = 1 if q1_6uid_i1 == uid_i2 & q1_6fr_i1>=2
replace str_fr_2 = 1 if q1_7uid_i1 == uid_i2 & q1_7fr_i1>=2
replace str_fr_2 = 1 if q1_8uid_i1 == uid_i2 & q1_8fr_i1>=2
replace str_fr_2 = 1 if q1_9uid_i1 == uid_i2 & q1_9fr_i1>=2
replace str_fr_2 = 1 if q1_10uid_i1 == uid_i2 & q1_10fr_i1>=2
replace str_fr_2 = 1 if q1_1uid_i2 == uid_i1 & q1_1fr_i2>=2
replace str_fr_2 = 1 if q1_2uid_i2 == uid_i1 & q1_2fr_i2>=2
replace str_fr_2 = 1 if q1_3uid_i2 == uid_i1 & q1_3fr_i2>=2
replace str_fr_2 = 1 if q1_4uid_i2 == uid_i1 & q1_4fr_i2>=2
replace str_fr_2 = 1 if q1_5uid_i2 == uid_i1 & q1_5fr_i2>=2
replace str_fr_2 = 1 if q1_6uid_i2 == uid_i1 & q1_6fr_i2>=2
replace str_fr_2 = 1 if q1_7uid_i2 == uid_i1 & q1_7fr_i2>=2
replace str_fr_2 = 1 if q1_8uid_i2 == uid_i1 & q1_8fr_i2>=2
replace str_fr_2 = 1 if q1_9uid_i2 == uid_i1 & q1_9fr_i2>=2
replace str_fr_2 = 1 if q1_10uid_i2 == uid_i1 & q1_10fr_i2>=2

gen str_fr_3=0
replace str_fr_3 = 1 if q1_1uid_i1 == uid_i2 & q1_1fr_i1>=3
replace str_fr_3 = 1 if q1_2uid_i1 == uid_i2 & q1_2fr_i1>=3
replace str_fr_3 = 1 if q1_3uid_i1 == uid_i2 & q1_3fr_i1>=3
replace str_fr_3 = 1 if q1_4uid_i1 == uid_i2 & q1_4fr_i1>=3
replace str_fr_3 = 1 if q1_5uid_i1 == uid_i2 & q1_5fr_i1>=3
replace str_fr_3 = 1 if q1_6uid_i1 == uid_i2 & q1_6fr_i1>=3
replace str_fr_3 = 1 if q1_7uid_i1 == uid_i2 & q1_7fr_i1>=3
replace str_fr_3 = 1 if q1_8uid_i1 == uid_i2 & q1_8fr_i1>=3
replace str_fr_3 = 1 if q1_9uid_i1 == uid_i2 & q1_9fr_i1>=3
replace str_fr_3 = 1 if q1_10uid_i1 == uid_i2 & q1_10fr_i1>=3
replace str_fr_3 = 1 if q1_1uid_i2 == uid_i1 & q1_1fr_i2>=3
replace str_fr_3 = 1 if q1_2uid_i2 == uid_i1 & q1_2fr_i2>=3
replace str_fr_3 = 1 if q1_3uid_i2 == uid_i1 & q1_3fr_i2>=3
replace str_fr_3 = 1 if q1_4uid_i2 == uid_i1 & q1_4fr_i2>=3
replace str_fr_3 = 1 if q1_5uid_i2 == uid_i1 & q1_5fr_i2>=3
replace str_fr_3 = 1 if q1_6uid_i2 == uid_i1 & q1_6fr_i2>=3
replace str_fr_3 = 1 if q1_7uid_i2 == uid_i1 & q1_7fr_i2>=3
replace str_fr_3 = 1 if q1_8uid_i2 == uid_i1 & q1_8fr_i2>=3
replace str_fr_3 = 1 if q1_9uid_i2 == uid_i1 & q1_9fr_i2>=3
replace str_fr_3 = 1 if q1_10uid_i2 == uid_i1 & q1_10fr_i2>=3

gen str_fr_4=0
replace str_fr_4 = 1 if q1_1uid_i1 == uid_i2 & q1_1fr_i1>=4
replace str_fr_4 = 1 if q1_2uid_i1 == uid_i2 & q1_2fr_i1>=4
replace str_fr_4 = 1 if q1_3uid_i1 == uid_i2 & q1_3fr_i1>=4
replace str_fr_4 = 1 if q1_4uid_i1 == uid_i2 & q1_4fr_i1>=4
replace str_fr_4 = 1 if q1_5uid_i1 == uid_i2 & q1_5fr_i1>=4
replace str_fr_4 = 1 if q1_6uid_i1 == uid_i2 & q1_6fr_i1>=4
replace str_fr_4 = 1 if q1_7uid_i1 == uid_i2 & q1_7fr_i1>=4
replace str_fr_4 = 1 if q1_8uid_i1 == uid_i2 & q1_8fr_i1>=4
replace str_fr_4 = 1 if q1_9uid_i1 == uid_i2 & q1_9fr_i1>=4
replace str_fr_4 = 1 if q1_10uid_i1 == uid_i2 & q1_10fr_i1>=4
replace str_fr_4 = 1 if q1_1uid_i2 == uid_i1 & q1_1fr_i2>=4
replace str_fr_4 = 1 if q1_2uid_i2 == uid_i1 & q1_2fr_i2>=4
replace str_fr_4 = 1 if q1_3uid_i2 == uid_i1 & q1_3fr_i2>=4
replace str_fr_4 = 1 if q1_4uid_i2 == uid_i1 & q1_4fr_i2>=4
replace str_fr_4 = 1 if q1_5uid_i2 == uid_i1 & q1_5fr_i2>=4
replace str_fr_4 = 1 if q1_6uid_i2 == uid_i1 & q1_6fr_i2>=4
replace str_fr_4 = 1 if q1_7uid_i2 == uid_i1 & q1_7fr_i2>=4
replace str_fr_4 = 1 if q1_8uid_i2 == uid_i1 & q1_8fr_i2>=4
replace str_fr_4 = 1 if q1_9uid_i2 == uid_i1 & q1_9fr_i2>=4
replace str_fr_4 = 1 if q1_10uid_i2 == uid_i1 & q1_10fr_i2>=4

*** variables on probability of reciprocal friendship
gen rec = 0 if LUL==1
replace rec = 1 if LUL==1 & LAL==1 


// Varibale on initial political category
gen lrc_i1=.
replace lrc_i1=1 if polpos_i1>=1 & polpos_i1<=4
replace lrc_i1=2 if polpos_i1==5 | polpos_i1==6
replace lrc_i1=3 if polpos_i1>=7 & polpos_i1<=10
replace lrc_i1=. if polpos_i1==.

gen lrc_i2=.
replace lrc_i2=1 if polpos_i2>=1 & polpos_i2<=4
replace lrc_i2=2 if polpos_i2==5 | polpos_i2==6
replace lrc_i2=3 if polpos_i2>=7 & polpos_i2<=10
replace lrc_i2=. if polpos_i2==.

* both left   
gen LCR = 1 if  lrc_i1==1  & lrc_i2==1
* both right   
replace LCR = 2 if lrc_i1==3  & lrc_i2==3
* both center   
replace LCR = 3 if lrc_i1==2  & lrc_i2==2
* both left-right   
replace LCR = 4 if ((lrc_i1==1  & lrc_i2==3) | (lrc_i1==3  & lrc_i2==1))
* both left-center   
replace LCR = 5 if ((lrc_i1==1  & lrc_i2==2) | (lrc_i1==2  & lrc_i2==1))
* both center-right   
replace LCR = 6 if ((lrc_i1==2  & lrc_i2==3) | (lrc_i1==3  & lrc_i2==2))


// Varibale recording the change in the sum of political opinions
gen SumPP=abs(polpos_i1+polpos_i2)
gen SumPPa=abs(polposnow_i1+polposnow_i2)
gen ChangeSumPP = SumPPa-SumPP

// variable containing first letter of surnames
gen LettFirst_i1 = substr(name_i1,1,1)
gen LettFirst_i2 = substr(name_i2,1,1)

// Include information on degree and path in network (for summary stats only)
merge 1:1 uid_i1 uid_i2 using "$path/Data/Raw/network.dta", nogen


////// save confidential file
save "$path/Data/Analysis/work_data_confidential.dta", replace


///// Clean work data for confidentiality
* drop variables not used in analysis and sensitive variables
drop ID_i1 agree_i1 betweeness_cent_i1 eigen_bonacich_cent_i1 katz_bonacich_cent_i1 Anonymat_i1 Semestrepdagogique_i1 Libellenseignement_i1 Libellunitpdagogique_i1 Programmeactuel_i1 Revenutotaux20132014_i1 Nb_part_ScPo20132014_i1 Revenutotaux20142015_i1 Nb_part_ScPo201320142_i1 Groupestage_integration_i1 name_i1 email_i1 pass_i1 done_i1 promo_i1 group_i1 intro_i1 q1_1uid_i1 q1_2uid_i1 q1_3uid_i1 q1_4uid_i1 q1_5uid_i1 q1_6uid_i1 q1_7uid_i1 q1_8uid_i1 q1_9uid_i1 q1_10uid_i1 q1_none_i1 q1_i1 q1_1if_i1 q1_2if_i1 q1_3if_i1 q1_4if_i1 q1_5if_i1 q1_6if_i1 q1_7if_i1 q1_8if_i1 q1_9if_i1 q1_10if_i1 q1_1cb_i1 q1_2cb_i1 q1_3cb_i1 q1_4cb_i1 q1_5cb_i1 q1_6cb_i1 q1_7cb_i1 q1_8cb_i1 q1_9cb_i1 q1_10cb_i1 q1_1at_i1 q1_2at_i1 q1_3at_i1 q1_4at_i1 q1_5at_i1 q1_6at_i1 q1_7at_i1 q1_8at_i1 q1_9at_i1 q1_10at_i1 q1_1fr_i1 q1_2fr_i1 q1_3fr_i1 q1_4fr_i1 q1_5fr_i1 q1_6fr_i1 q1_7fr_i1 q1_8fr_i1 q1_9fr_i1 q1_10fr_i1 q1b_i1 q1_nbclose_i1 q1_nbvclose_i1 q1c_i1 q2_1_i1 q2_1uid_i1 q2_2_i1 q2_2uid_i1 q2_3_i1 q2_3uid_i1 q2_4_i1 q2_4uid_i1 q2_5_i1 q2_5uid_i1 q2_6_i1 q2_6uid_i1 q2_7_i1 q2_7uid_i1 q2_8_i1 q2_8uid_i1 q2_9_i1 q2_9uid_i1 q2_10_i1 q2_10uid_i1 q2_none_i1 q2_i1 q2_1if_i1 q2_2if_i1 q2_3if_i1 q2_4if_i1 q2_5if_i1 q2_6if_i1 q2_7if_i1 q2_8if_i1 q2_9if_i1 q2_10if_i1 q2_1cb_i1 q2_2cb_i1 q2_3cb_i1 q2_4cb_i1 q2_5cb_i1 q2_6cb_i1 q2_7cb_i1 q2_8cb_i1 q2_9cb_i1 q2_10cb_i1 q2_1at_i1 q2_2at_i1 q2_3at_i1 q2_4at_i1 q2_5at_i1 q2_6at_i1 q2_7at_i1 q2_8at_i1 q2_9at_i1 q2_10at_i1 q2_1fr_i1 q2_2fr_i1 q2_3fr_i1 q2_4fr_i1 q2_5fr_i1 q2_6fr_i1 q2_7fr_i1 q2_8fr_i1 q2_9fr_i1 q2_10fr_i1 q2b_i1 q2_nbvclose_i1 q2_nbclose_i1 q2c_i1 q3_1_i1 q3_2_i1 q3_2uid_i1 q3_3_i1 q3_3uid_i1 q3_4_i1 q3_4uid_i1 q3_5_i1 q3_5uid_i1 q3_6_i1 q3_6uid_i1 q3_7_i1 q3_7uid_i1 q3_8_i1 q3_8uid_i1 q3_9_i1 q3_9uid_i1 q3_10_i1 q3_10uid_i1 q3_none1_i1 q3_none2_i1 q3_i1 q4c_i1 q4d_i1 q4_i1 q5a_i1 q5a_p1_i1 q5a_p1b_i1 q5a_p2_i1 q5a_p2b_i1 q5b_i1 q5b_p1_i1 q5b_p1b_i1 q5c_1_i1 q5c_2_i1 q5d_i1 q5_i1 q6a1_i1 q6a2_i1 q6b1_i1 q6b2_i1 q6c_1_i1 q6c_2_i1 q6c_3_i1 q6c_4_i1 q6c_5_i1 q6d_1_i1 q6d_2_i1 q6d_3_i1 q6d_4_i1 q6d_5_i1 q6e_i1 q6f_1_i1 q6f_2_i1 q6f_3_i1 q6f_4_i1 q6f_5_i1 q6f_6_i1 q6f_6txt_i1 q6_i1 dtime_i1 non_fini_i1 Sexetudiant_i1 Libellnationalit1_i1 Libellnationalit2_i1 Libellstatutadministratif_i1 LibellTypeadmission_i1 Annedanslediplme_i1 Libellspcialit_i1 Libellspcialit2_i1 Campustudiant_i1 Codeniveauprogcycle_i1 EffectifRel_i1 CSPniv3parent1_i1 CSPniv3parent2_i1 SrieBaccalauratLib_i1 Mentiontrsbien_i1 Droitsconstatscumuls_i1 droits_i1 merge_bis_i1 _merge_cent intro1_i1 intro2_i1 intro11_i1 intro12_i1 intro13_i1 intro21_i1 intro22_i1 intro23_i1 t_st_fr_i1 d_st_fr_i1 q11_i1 q12_i1 q111_i1 q112_i1 q113_i1 q121_i1 q122_i1 q123_i1 t_f_fr_i1 d_f_fr_i1 numfriends_i1 code_i1 new_zip_i1 new_depb_i1 new_regb_i1 new_pro1_i1 new_pro2_i1 ID_i2 betweeness_cent_i2 eigen_bonacich_cent_i2 katz_bonacich_cent_i2 Anonymat_i2 Semestrepdagogique_i2 Libellenseignement_i2 Libellunitpdagogique_i2 Programmeactuel_i2 Revenutotaux20132014_i2 Nb_part_ScPo20132014_i2 Revenutotaux20142015_i2 Nb_part_ScPo201320142_i2 Groupestage_integration_i2 name_i2 email_i2 pass_i2 done_i2 promo_i2 group_i2 agree_i2 intro_i2 q1_1uid_i2 q1_2uid_i2 q1_3uid_i2 q1_4uid_i2 q1_5uid_i2 q1_6uid_i2 q1_7uid_i2 q1_8uid_i2 q1_9uid_i2 q1_10uid_i2 q1_none_i2 q1_i2 q1_1if_i2 q1_2if_i2 q1_3if_i2 q1_4if_i2 q1_5if_i2 q1_6if_i2 q1_7if_i2 q1_8if_i2 q1_9if_i2 q1_10if_i2 q1_1cb_i2 q1_2cb_i2 q1_3cb_i2 q1_4cb_i2 q1_5cb_i2 q1_6cb_i2 q1_7cb_i2 q1_8cb_i2 q1_9cb_i2 q1_10cb_i2 q1_1at_i2 q1_2at_i2 q1_3at_i2 q1_4at_i2 q1_5at_i2 q1_6at_i2 q1_7at_i2 q1_8at_i2 q1_9at_i2 q1_10at_i2 q1_1fr_i2 q1_2fr_i2 q1_3fr_i2 q1_4fr_i2 q1_5fr_i2 q1_6fr_i2 q1_7fr_i2 q1_8fr_i2 q1_9fr_i2 q1_10fr_i2 q1b_i2 q1_nbclose_i2 q1_nbvclose_i2 q1c_i2 q2_1_i2 q2_1uid_i2 q2_2_i2 q2_2uid_i2 q2_3_i2 q2_3uid_i2 q2_4_i2 q2_4uid_i2 q2_5_i2 q2_5uid_i2 q2_6_i2 q2_6uid_i2 q2_7_i2 q2_7uid_i2 q2_8_i2 q2_8uid_i2 q2_9_i2 q2_9uid_i2 q2_10_i2 q2_10uid_i2 q2_none_i2 q2_i2 q2_1if_i2 q2_2if_i2 q2_3if_i2 q2_4if_i2 q2_5if_i2 q2_6if_i2 q2_7if_i2 q2_8if_i2 q2_9if_i2 q2_10if_i2 q2_1cb_i2 q2_2cb_i2 q2_3cb_i2 q2_4cb_i2 q2_5cb_i2 q2_6cb_i2 q2_7cb_i2 q2_8cb_i2 q2_9cb_i2 q2_10cb_i2 q2_1at_i2 q2_2at_i2 q2_3at_i2 q2_4at_i2 q2_5at_i2 q2_6at_i2 q2_7at_i2 q2_8at_i2 q2_9at_i2 q2_10at_i2 q2_1fr_i2 q2_2fr_i2 q2_3fr_i2 q2_4fr_i2 q2_5fr_i2 q2_6fr_i2 q2_7fr_i2 q2_8fr_i2 q2_9fr_i2 q2_10fr_i2 q2b_i2 q2_nbvclose_i2 q2_nbclose_i2 q2c_i2 q3_1_i2 q3_2_i2 q3_2uid_i2 q3_3_i2 q3_3uid_i2 q3_4_i2 q3_4uid_i2 q3_5_i2 q3_5uid_i2 q3_6_i2 q3_6uid_i2 q3_7_i2 q3_7uid_i2 q3_8_i2 q3_8uid_i2 q3_9_i2 q3_9uid_i2 q3_10_i2 q3_10uid_i2 q3_none1_i2 q3_none2_i2 q3_i2 q4c_i2 q4d_i2 q4_i2 q5a_i2 q5a_p1_i2 q5a_p1b_i2 q5a_p2_i2 q5a_p2b_i2 q5b_i2 q5b_p1_i2 q5b_p1b_i2 q5c_1_i2 q5c_2_i2 q5d_i2 q5_i2 q6a1_i2 q6a2_i2 q6b1_i2 q6b2_i2 q6c_1_i2 q6c_2_i2 q6c_3_i2 q6c_4_i2 q6c_5_i2 q6d_1_i2 q6d_2_i2 q6d_3_i2 q6d_4_i2 q6d_5_i2 q6e_i2 q6f_1_i2 q6f_2_i2 q6f_3_i2 q6f_4_i2 q6f_5_i2 q6f_6_i2 q6f_6txt_i2 q6_i2 dtime_i2 non_fini_i2 Sexetudiant_i2 Libellnationalit1_i2 Libellnationalit2_i2 Libellstatutadministratif_i2 LibellTypeadmission_i2 Annedanslediplme_i2 Libellspcialit_i2 Libellspcialit2_i2 Campustudiant_i2 Codeniveauprogcycle_i2 EffectifRel_i2 CSPniv3parent1_i2 CSPniv3parent2_i2 SrieBaccalauratLib_i2 Mentiontrsbien_i2 Droitsconstatscumuls_i2 droits_i2 merge_bis_i2 intro1_i2 intro2_i2 intro11_i2 intro12_i2 intro13_i2 intro21_i2 intro22_i2 intro23_i2 t_st_fr_i2 d_st_fr_i2 q11_i2 q12_i2 q111_i2 q112_i2 q113_i2 q121_i2 q122_i2 q123_i2 t_f_fr_i2 d_f_fr_i2 numfriends_i2 code_i2 new_zip_i2 new_depb_i2 new_regb_i2 new_pro1_i2 new_pro2_i2 sex_i1 sex_i2 nat1_i1 nat1_i2 nat2_i1 nat2_i2 admission_i1 admission_i2 seriebac_i1 seriebac_i2 nofee_i1 nofee_i2 sports_1_i1 sports_1_i2 sports_2_i1 sports_2_i2 sports_3_i1 sports_3_i2 sports_4_i1 sports_4_i2 sports_5_i1 sports_5_i2 sports_i1 sports_i2 assoc1_i1 assoc1_i2 assoc2_i1 assoc2_i2 assoc3_i1 assoc3_i2 assoc4_i1 assoc4_i2 assoc5_i1 assoc5_i2 parent1_i1 parent2_i1 parent1_i2 parent2_i2 pari1_i1 pari2_i1 pari1_i2 pari2_i2 DIR_i1 DIR_i2 AlphaRankExt_i1 AlphaRankExt_i2 AlphaRank_i1 AlphaRank_i2 AlphaHypGroup_i1 AlphaHypGroup_i2 SumPP SumPPa lrc_i1 lrc_i2

drop polposnow_i1 polpos_i1 polposnow_i2 polpos_i2 polposnow_15_i1 polpos_15_i1 polpos2013_15_i1 polposnow_15_i2 polpos_15_i2 polpos2013_15_i2

// change id to anonymized id
* drop real student id
drop uid_*

* rename artificial student id
rename new_id_* uid_* 

* reshuffle IG numbers while preserving allocation
set seed 12345  
preserve
bysort IGno_i1: keep if _n == 1
keep IGno_i1
gen double rand = runiform()
sort rand
gen IGno_i1_new = _n
tempfile map
save `map'
restore
merge m:1 IGno_i1 using `map', nogen
drop IGno_i1 rand
rename IGno_i1_new IGno_i1

set seed 12345  
preserve
bysort IGno_i2: keep if _n == 1
keep IGno_i2
gen double rand = runiform()
sort rand
gen IGno_i2_new = _n
tempfile map
save `map'
restore
merge m:1 IGno_i2 using `map', nogen
drop IGno_i2 rand
rename IGno_i2_new IGno_i2

////// save public file
save "$path/Data/Analysis/work_data_public.dta", replace

