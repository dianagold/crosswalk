* Example based on the auto dataset

* The file location should reflect your repository clone
global clone "C:/Users/`c(username)'/Documents/Github/crosswalk/src"

* Load most recent version of the ado from clone
quietly do "${clone}/crosswalk.ado"

* Usage example
sysuse auto, clear
codebook, compact

sysuse auto, clear
crosswalk using "${clone}/crosswalk_auto.csv", keeping("make price mpg") to_var(varname_target) from_var(varname_original) to_type(vartype_target) to_value(value_target) from_value(value_original) to_labelvar(varlabel_target) to_labelvalues(valuelabel_target)
codebook, compact

sysuse auto, clear
crosswalk using "${clone}/crosswalk_auto.csv", keeping("make price mpg") to_var(varname_target) from_var(varname_original) to_type(vartype_target) to_value(value_target) from_value(value_original)
codebook, compact

sysuse auto, clear
crosswalk using "${clone}/crosswalk_auto.csv", keeping("make price mpg") to_var(varname_target) from_var(varname_original) to_type(vartype_target) 
codebook, compact


crosswalk using "${clone}/crosswalk_auto.csv", default keeping("make price mpg")
