* Example based on the auto dataset
sysuse auto, clear

* The file location should reflect your repository clone
local clone "C:/Users/`c(username)'/Documents/Github/crosswalk"
local crosswalk_auto_csv "`clone'/test/crosswalk_auto.csv"

* Load most recent version of the ado from clone
quietly do "`clone'/src/crosswalk.ado"

* Usage example
codebook, compact
crosswalk using "`crosswalk_auto_csv'", keeping("make price mpg")
codebook, compact
