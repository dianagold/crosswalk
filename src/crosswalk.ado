*! version 0.1  12feb2020  Diana Goldemberg, diana_goldemberg@g.harvard.edu

/*------------------------------------------------------------------------------
This program maps raw/original values to clean/target labeled values
  using an external crosswalk csv file.
------------------------------------------------------------------------------*/

capture program drop crosswalk
program define crosswalk, nclass

  syntax using/, [keeping(varlist)]

  version 13
  local syntax_error 2222

  * Display process comment
  noi display as text "applying to dataset in memory the crosswalk `using'..."

  /*----------------------------------------------------------------------------
  1. Store the original_varlist as a local and preserve the original dataset
  2. Import and check the crosswalk csv for consistency
  3. Write a temporary crosswalk do-file that does variable transformations
  4. Restores the original dataset and executes the temporary crosswalk do-file
  *---------------------------------------------------------------------------*/

  *----------------------------------------------------------------------------*
  * 1. Store the original_varlist as a local and preserve the original dataset
  *----------------------------------------------------------------------------*
  * Store the original variables in rawdata and their type as locals so that
  * a destring can be performed as needed (when the vartype_target is numeric)
  quietly ds
  local original_varlist "`r(varlist)'"
  foreach v of varlist `original_varlist' {
    local `v'_type: type `v'
    * Not differentiating between str4 or str12 or strL
    if substr("``v'_type'", 1, 3) == "str"  local `v'_type "string"
    * Also not differentiating between byte, int, long, float or double
    else local `v'_type "numeric"
    * All we care is whether it is string vs numeric
  }

  * Preserve the rawdata before opening the crosswalk file
  preserve


  *----------------------------------------------------------------------------*
  * 2. Import and check the crosswalk csv for consistency
  *----------------------------------------------------------------------------*
  * Must be able to locate the crosswalk file
  confirm file `"`using'"'
  * Check that extension is indeed a csv
  mata : st_local("extension", pathsuffix(`"`using'"'))
  if `"`extension'"' != ".csv" {
    noi display as error `"using must specify a file ending with .csv - you provided `using'"'
    exit `syntax_error'
  }

  * Import the crosswalk csv file
  quietly import delimited `"`using'"', varnames(1) encoding("utf-8") clear

  * Expected variables in the csv file
  local mandatory "varname_original varname_target vartype_target"
  local optional_recoding "value_original value_target"
  local optional_label_var "varlabel_target"
  local optional_label_value "valuelabel_target"
  * Without the mandatory variables in the crosswalk csv, will exit
  capture confirm variable `mandatory', exact
  if _rc {
    noi display as error "The crosswalk csv must contain the following column names in the first row: `mandatory'."
    exit `syntax_error'
  }
  * The optional variable groups are checked, but only generate warnings, no exit
  capture confirm variable `optional_recoding', exact
  if _rc {
    noi display as error "WARNING! The columns for recoding (`optional_recoding') were not found in the csv. Will proceed only with renaming/simple expression transformations."
    local has_recoding = 0
  }
  else local has_recoding = 1
  capture confirm variable `optional_label_var', exact
  if _rc {
    noi display as error "WARNING! The column `optional_label_var' was not found in the csv. Will proceed creating variables without variable labels."
    local has_varlabel = 0
  }
  else local has_varlabel = 1
  capture confirm variable `optional_label_value', exact
  if _rc {
    noi display as error "WARNING! The column `optional_label_value' was not found in the csv. Will proceed creating variables without assigning value labels."
    local has_valuelabel = 0
  }
  else local has_valuelabel = 1

  * Organize the crosswalk file
  sort varname_target
  gen linenum = _n

  * Options must be valid
  cap assert inlist(vartype_target, "numeric", "string")
  if _rc {
    noi display as error "The crosswalk csv has invalid vartypes_target. Valid vartypes_target: numeric, string."
    exit `syntax_error'
  }

  /* PLACEHOLDER: more errors to check
  - value_target is defined iff value_original is defined
  - !missing(varname_target) iff !missing(varname_original)
  */


  *----------------------------------------------------------------------------*
  * 3. Write a temporary crosswalk do-file that does variable transformations
  *----------------------------------------------------------------------------*

  * Start temporary do-file
  tempname crosswalk_do
  tempfile temp_do_file
  quietly file open `crosswalk_do' using "`temp_do_file'", write text replace

  * Shortcut to make it easier to edit everyline with filewrite
  local fw "file write `crosswalk_do'"

  * Create header
  `fw' "*===========================================*" _n
  `fw' "* Automatically generated crosswalk do-file *" _n
  `fw' "*===========================================*" _n _n

  * Processing all variables
  quietly levelsof varname_target, local(target_varlist)
  foreach varname of local target_varlist {

    *------------------------------------------------
    * 3.1. Prepare to process this variable `varname'
    *------------------------------------------------

    * Return the lines between which the variable is matched: L1 L2
    quietly sum linenum if varname_target == "`varname'"
    local Lmin = `r(min)'
    local Lmax = `r(max)'

    * Boolean for this target variable being a string/numeric as per first line
    if      "`=vartype_target[`Lmin']'" == "string"  local to_string = 1
    else if "`=vartype_target[`Lmin']'" == "numeric" local to_string = 0
    else {
      noi display as error `"variable `varname' must be either string OR numeric"'
      exit `syntax_error'
    }

    * Ensures this variable is of a single type
    quietly tab vartype_target if varname_target == "`varname'"
    cap assert `r(r)' == 1
    if _rc {
      noi display as error `"variable `varname' cannot be both string AND numeric"'
      exit `syntax_error'
    }

    * Ensures that the variable name is not yet taken by an original variable
    local varname_is_taken : list varname in original_varlist
    if `varname_is_taken' {
      noi display as error `"cannot create target variable `varname': varname already taken in original dataset"'
      exit `syntax_error'
    }

    * Varname_original must either be an existing variable, or a valid expression (numeric, single line, dummy)
    forvalues line=`Lmin'(1)`Lmax' {
      local v_original_thisline "`=varname_original[`line']'"
      local v_original_exists : list v_original_thisline in original_varlist
      * Not an existing original_variable means a candidate expression
      if `v_original_exists' == 0 {
        * To be valid, the expression should start/end with ( & )
        if substr("`v_original_thisline'", 1, 1) != "(" | substr("`v_original_thisline'", -1, 1) != ")" {
          noi display as error `"cannot create target variable `varname': it makes reference to `v_original_thisline' which should be either an existing variable or (expression of existing variables)"'
          exit `syntax_error'
        }
        * It should also be single lined
        if `Lmin'!=`Lmax' {
          noi display as error `"cannot create target variable `varname': it must be given in a single line because it contains an expression on existing variables `v_original_thisline'"'
          exit `syntax_error'
        }
        * And be numeric without value (it will become a dummy)
        if `to_string' | "`=value_target[`line']'" != "" {
        * ATTENTION!!!! WHAT IF THIS COLUMN IS NUMERIC???
          noi display as error `"cannot create target variable `varname': it must be of vartype_target numeric and no value_target should be specified for it, as it will become a dummy based on the expression `v_original_thisline'"'
          exit `syntax_error'
        }
      }
    }

    * Check if a valuelabel should be created for this new variable
    if `has_valuelabel' == 1 {
      quietly tab valuelabel_target if varname_target == "`varname'"
      if `r(r)' == 0 local to_valuelabel = 0
      else           local to_valuelabel = 1
    }
    else local to_valuelabel = 0

    //* Progress tracker
    //display as text "Processing `varname'"

    *------------------------------------------------------
    * 3.2. Write dofile section on this variable `varname'
    *------------------------------------------------------

    * DDI marker open
    `fw' `"*<_`varname'_>"' _n

    * Generate empty variable
    if `to_string'   `fw' `"generate `varname' = "" "' _n
    else             `fw' `"generate `varname' = .  "' _n

    * Generate empty label
    if `to_valuelabel'  `fw' `"label define `varname', replace"' _n

    * For each line of instruction
    forvalues line=`Lmin'(1)`Lmax' {

      * If there is no value_target, it should just replace for varname_original
      * ATTENTION!!!! WHAT IF THIS COLUMN IS NUMERIC???
      if "`=value_target[`line']'" == ""  ///
        `fw' `"replace `varname' = `=varname_original[`line']' "' _n

      * If there is some value_target, writes the line in two steps
      else {
        * First step is to replace variable with the value_target
        if `to_string'   `fw' `"replace `varname' = "`=value_target[`line']'" "'
        else             `fw' `"replace `varname' =  `=value_target[`line']'  "'

        * If there is no values correspondence (at all or for this variable), ends the line
        if `has_recoding' == 0                      `fw' `" "' _n
        else if "`=value_original[`line']'" == ""   `fw' `" "' _n

        * If there is some value_original to recode from, continues the line as an if condition
        else {

          * But before the if, needs a boolean for original variable being a string/numeric
          if      "``=varname_original[`line']'_type'" == "string"  local from_string = 1
          else if "``=varname_original[`line']'_type'" == "numeric" local from_string = 0
          else {
            noi display as error `"Programming error (not clear the vartype of `=varname_original[`line']')"'
            exit `syntax_error'
          }

          * Finish that replace line using or not using quotes
          if `from_string'   `fw' `" if `=varname_original[`line']' == "`=value_original[`line']'" "' _n
          else               `fw' `" if `=varname_original[`line']' ==  `=value_original[`line']'  "' _n
        }

        if `to_valuelabel' & "`=valuelabel_target[`line']'" != "" ///
          `fw' `"label define `varname' `=value_target[`line']' "`=valuelabel_target[`line']'", modify"' _n
      }
    }

    * Apply label to variable
    if `to_valuelabel'  `fw' `"label values `varname' `varname'"' _n

    * Label new variable
    if `has_varlabel'  `fw' `"label var `varname' "`=varlabel_target[`Lmin']'" "' _n
    * DDI marker close
    `fw' `"*</_`varname'_>"' _n _n

  }

  *------------------------------------------------
  * 3.3. Final lines in the dofile being created
  *------------------------------------------------

  * Keep only specified original variables and the new ones
  if "`keeping'" == "" local varlist_to_keep "`target_varlist'"
  else  local varlist_to_keep : list keeping | target_varlist
  * Stripe the quotes out so that the list can be used in the do-file
  local varlist_to_keep : list clean varlist_to_keep
  `fw' `"keep `varlist_to_keep'"' _n

  * Compress the file
  `fw' `"compress"' _n

  * Close temp do file
  quietly file close `crosswalk_do'


  *----------------------------------------------------------------------------*
  * 4. Restores the original dataset and executes the temporary crosswalk do-file
  *----------------------------------------------------------------------------*
  * Reopen the rawdata
  restore

  * Run the temp do file
  qui do "`temp_do_file'"

  * Display process comment
  noi display as result "done"

end
