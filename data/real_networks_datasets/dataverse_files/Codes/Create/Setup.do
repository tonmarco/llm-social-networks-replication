

* install ranktest
ssc install ranktest

* install estab and estpost
cap ssc install estout

* istall ivreg2
cap ssc install ivreg2

* install outreg2
cap ssc install outreg2

* set path (add path here)
global path="C:/Users/wb560757/OneDrive - WBG/Desktop/Network/Replication_Package_Mar2025"

*global path = "/Users/quocanhdo/Monash Uni Enterprise Dropbox/Quoc-Anh Do/Project - Network at Sciences Po/QA - Nicolo/Replication_Package/Replication_Package_Dec2025"
 
*do "$path/Codes/Analysis/IVdyadic.ado" 
*do "$path/Codes/Analysis/Permutation.ado" 

* define type of data to be used for analysis
global confidentiality = "public"