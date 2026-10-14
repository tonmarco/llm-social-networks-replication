////////////////////////////////////////////////////////////////////////////////
*********** Code to crate codebooks ***************
////////////////////////////////////////////////////////////////////////////////

*cd "$path/Results/"

cap log close
log using "$path/Results/Codebook", replace
use "$path/Data/Raw/base_complete_1314_i1.dta", clear

codebook

use "$path/Data/Raw/2015_individual_i1.dta", clear

codebook

cap log close
