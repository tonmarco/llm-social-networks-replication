
* define number of groups to cluster
global Ngroup = 52

/// First function to compute clustered standard errors
cap program drop IVdyadic
program define IVdyadic, eclass
	syntax varlist(min=2) [if] [in], IV(varlist) groups(varlist)

	marksample touse
	tokenize `varlist'
	local lhsvar "`1'"
	di "LHS: `lhsvar'"
	mac shift 1
	local Xvar "`*'"
	di "RHS: `Xvar'"
	local IVedvar "`1'"
	mac shift 1
	local covar "`*'"
	di "Covariates: `covar'"
	local Zvar "`iv' `covar'"
	di "Groups: `groups'"
	di "IV: `iv'"

	if wordcount("`groups'")~=2 {
		di "Error: there must be exactly 2 group IDs"
	}
	tokenize `groups'
	local IG_i1 "`1'"
	di "Group i1: `IG_i1'"
	local IG_i2 "`2'"
	di "Group i2: `IG_i2'"


	preserve
	keep if `touse'
	count if `touse'
	keep uid_i1 uid_i2 `IG_i1' `IG_i2' `lhsvar' `Xvar' `iv'
	
	// Start the work
	sort `IG_i1' `IG_i2'

	global N = _N
	global Ngroup = 52 // fixed in advance
	global Nvar = wordcount("`Xvar'") + 1 // control variables + IVed/treatment variable + the constant
	di "Nvar $Nvar"
	di "N $N"
	//codebook 
	
	tempname Beta VCV
	mata: b = .; StdErr = .; p = .; V = .
	mata: m_ivreg("`lhsvar'", "`Xvar'", "`iv'", "`groups'", b, StdErr, p, V)

	
	*mata: st_matrix("`Beta'",b)
	*mata: st_matrix("`VCV'",V)
	*mata: st_matrix("p",p)
	
	*mat list `Beta'

	*di "`Xvar' _cons"
	mat colnames Beta = `Xvar' _cons
	mat colnames VCV = `Xvar' _cons
	mat rownames VCV = `Xvar' _cons
	mat colnames StdErr = `Xvar' _cons
	mat colnames pvalues = `Xvar' _cons
	*mat list VCV
	*mat list e(V)
	
	ereturn mat Beta = Beta
	ereturn mat VCV = VCV
	ereturn mat StdErr = StdErr
	ereturn mat pvalues = pvalues
	
	ereturn scalar F_1 = F_1
	ereturn scalar F_all = F_all
	ereturn scalar F_IV = F_IV
	*ereturn post Beta VCV
	*ereturn repost b=Beta V=VCV //, esample(`touse')
			
	restore 

end



/// Second function to compute clustered standard errors
cap mata mata drop m_ivreg()
mata mata clear
version 18
mata:
void m_ivreg(string scalar lhsvar, string scalar Xvar, string scalar iv, string scalar groups, real colvector b, real colvector StdErr, real colvector p, real matrix V)
{

		X = st_data(.,Xvar)
		noX_1 = cols(X)+1

		N = rows(X)

		X = (X,J(N,1,1))

		Z = st_data(.,iv)
		noIV_1 = cols(Z)+1

		Z = (Z,X[.,noIV_1..noX_1])  // To be generalized for the case with more than one IV

		Y = st_data(.,lhsvar)

		ZeeZ = J(noX_1,noX_1,0)
		
		invZX = luinv(Z'*X)
		b = invZX * cross(Z,Y)
		resid = Y -  X*b
		"Beta:"
				
		gr = tokens(groups)
		if (cols(gr)~=2) {
			errprintf("Error: Number of integration group variables must be 2")
		}
		IG_i1 = st_data(.,gr[1])
		IG_i2 = st_data(.,gr[2])
	
		timer_clear()
		timer_on(1)
		for (i=1; i<=N; i++) {

			IG1_i = IG_i1[i]		
			IG2_i = IG_i2[i]
			eZi = resid[i]*Z[i,.]
			Selection = J(N,1,0)

			Find1j = (IG_i1:==IG1_i) :| (IG_i2:==IG1_i)
			Find2j = (IG_i2:==IG2_i) :| (IG_i1:==IG2_i)
				
			Selection = Find1j :| Find2j

			SelZ = select(Z,Selection)
			Selresid = select(resid,Selection)
			eZ_Sel = cross(Selresid,SelZ)
			
			ZeeZ = ZeeZ + cross(eZi,eZ_Sel)
		}
		timer_off(1)
		timer(1)

		V = invZX * ZeeZ * invZX'
		V = V* (2*$Ngroup) / (2*$Ngroup - 1) * (N) / (N - noX_1 + 1)
		Vdiag = diagonal(V)
		"Diagonal of V:"
		Vdiag
		StdErr = sqrt(Vdiag)

		eVectors = .; eValues = .
		symeigensystem(V,eVectors,eValues)
		
				I = eValues:<0 // Not(I): !I
		
		"eValues:"
		eValues

		for (i=1; (i>0) & any(Vdiag:<0); i=i-0.01) {

				eValuesadj = eValues:*(!I) + (i*eValues):*I
		
				V = eVectors*diag(eValuesadj)*eVectors'
				Vdiag = diagonal(V)
				
		}	
		
		"Adjustment factor i"
		i

		

		StdErr = sqrt(Vdiag)
		"Standard errors:"
		StdErr'
		
		t = b:/StdErr
		p = J(rows(b),1,1)
		for (i=1; i<=rows(b); i++) {
			p[i] = (1 - normal(abs(t[i])))*2
		}
		"p-values:"
		p'
				
		Nv = noX_1 - 1
		

		F_all = b[1..Nv]'*luinv(V[1..Nv,1..Nv])*b[1..Nv]/Nv
		printf("F-stat for all: %f\n",F_all)
		F_1 = b[1]^2*V[1,1]^(-1)
		printf("F-stat for first coefficient: %f\n",F_1)
		noIV = noIV_1 - 1
		noIV
		F_IV = b[1..noIV]'*luinv(V[1..noIV,1..noIV])*b[1..noIV]/noIV
		printf("F-stat for IVed coefficients: %f\n",F_IV)	
		
		st_matrix("Beta",b')
		st_matrix("VCV",V)
		st_matrix("StdErr",StdErr')
		st_matrix("pvalues",p')
		
		st_numscalar("F_1",F_1)
		st_numscalar("F_all",F_all)
		st_numscalar("F_IV",F_IV)
}
end
