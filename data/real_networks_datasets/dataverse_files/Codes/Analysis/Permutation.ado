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
