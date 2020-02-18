*! version 0.2  20feb2020  Diana Goldemberg, diana_goldemberg@g.harvard.edu

/*------------------------------------------------------------------------------
This program maps raw/original values to clean/target labeled values
  using an external crosswalk csv file.
------------------------------------------------------------------------------*/

capture program drop crosswalk
program define crosswalk, nclass

  syntax using/, [default] [from_var(string) to_var(string) to_type(string)]  ///
    [from_value(string) to_value(string) to_labelvar(string) to_labelvalues(string)] ///
    [keeping(varlist) keepall]

  version 13
  * Define error code (pegar carona no expresso... 2222!)
  local syntax_error 2222

  * Display process comment
  noi display as text "applying to dataset in memory the crosswalk `using'..."

  /*----------------------------------------------------------------------------
  0. Check specified options
  1. Store the original_varlist as a local and preserve the original dataset
  2. Import and check the crosswalk csv for consistency
  3. Write a temporary crosswalk do-file that does variable transformations
  4. Restores the original dataset and executes the temporary crosswalk do-file
  *---------------------------------------------------------------------------*/

  *----------------------------------------------------------------------------*
  * 0. Check specified options
  *----------------------------------------------------------------------------*
  * Options -keeping- and -keeping_all- should not be combined
  if "`keepall'" != "" & "`keeping'" != "" {
    noi display as error `"options {it:keeping(varlist)} and {it:keepall} may not be combined"'
    exit `syntax_error'
  }

  * Column names that are expected in a 'default' crosswalk.csv in the 1st row
  local mandatory_columns "from_var to_var to_type"
  local all_columns "from_var from_value to_var to_type to_value to_labelvar to_labelvalues"

  * Default options presumes that the column names in the rosswalk csv file will
  * follow the expected standardized names. Otherwise, column names must be provided
  * at the minimum for the mandatory columns
  if "`default'" == "" {
    foreach column of local mandatory_columns {
      if "``column''" == "" {
        noi display as error `"unless option {it:default} is used, options {it:`mandatory_columns'} must be specified"'
        exit `syntax_error'
      }
    }
  }

  * If default is in use, should not specify ANY columns (so default is always default to all columns)
  else {
    foreach column of local all_columns {
      if "``column''" != "" {
        noi display as error `"option {it:default} cannot be combined with column names options and you specified {it:`column'(``column'')}"'
        exit `syntax_error'
      }
    }
  }

  *----------------------------------------------------------------------------*
  * 1. Store the original_varlist as a local and preserve the original dataset
  *----------------------------------------------------------------------------*
  * Store the original variables in rawdata and their type as locals so that
  * a destring can be performed as needed (when the to_type is numeric)
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
  local mandatory   "from_var to_var to_type"
  local optional_recoding    "to_value from_value"
  local optional_label_var   "to_labelvar"
  local optional_label_value "to_labelvalues"

  * Unless the default option is activated, each varname passed in the options is renamed to default
  if "`default'" == "" {
    foreach option of local all_columns {
      cap rename ``option'' `option'
    }
  }

  * Without the mandatory variables in the crosswalk csv, will exit
  capture confirm variable `mandatory', exact
  if _rc {
    if "`default'" == "" noi display as error "the crosswalk csv must contain the columns: `from_var' `to_var' `to_type'."
    else noi display as error "since {it:default} is on, the crosswalk csv must contain the columns: `mandatory'."
    exit `syntax_error'
  }

  * The optional variable groups are checked, but only generate warnings, no exit

  * Column pair that allow for recoding of values
  capture confirm variable `optional_recoding', exact
  if _rc {
    noi display as error "the columns for recoding values were not found in the csv: will proceed only renaming/simple expressions"
    local has_recoding = 0
  }
  else local has_recoding = 1

  * Column that allows for labeling variables
  capture confirm variable `optional_label_var', exact
  if _rc {
    noi display as error "the column for labeling new variables was not found in the csv: will proceed without variable labels"
    local has_varlabel = 0
  }
  else local has_varlabel = 1

  * Column that allows for creating value labels
  capture confirm variable `optional_label_value', exact
  if _rc {
    noi display as error "the column for creating value labels was not found in the csv: will proceed without assigning value labels"
    local has_valuelabel = 0
  }
  else local has_valuelabel = 1

  * Type options must be valid
  cap assert inlist(to_type, "numeric", "string")
  if _rc {
    noi display as error "the crosswalk csv has invalid to_type (only numeric or string accepted)"
    exit `syntax_error'
  }

  /* PLACEHOLDER: more errors to check
  - to_value is defined iff from_value is defined
  - !missing(to_var) iff !missing(from_var)
  */

  *----------------------------------------------------------------------------*
  * 3. Write a temporary crosswalk do-file that does variable transformations
  *----------------------------------------------------------------------------*
  * Sort the crosswalk file consistenly, because the line numbers will be used
  sort to_var
  gen linenum = _n

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
  quietly levelsof to_var, local(target_varlist)
  foreach varname of local target_varlist {

    *------------------------------------------------
    * 3.1. Prepare to process this variable `varname'
    *------------------------------------------------

    * Return the lines between which the variable is matched: Lmin Lmax
    quietly sum linenum if to_var == "`varname'"
    local Lmin = `r(min)'
    local Lmax = `r(max)'

    * Boolean for this target variable being a string/numeric as per first line
    if      "`=to_type[`Lmin']'" == "string"  local to_string = 1
    else if "`=to_type[`Lmin']'" == "numeric" local to_string = 0
    else {
      noi display as error `"variable `varname' must be either string OR numeric"'
      exit `syntax_error'
    }

    * Ensures this variable is of a single type
    quietly tab to_type if to_var == "`varname'"
    cap assert `r(r)' == 1
    if _rc {
      noi display as error `"variable `varname' cannot be both string AND numeric"'
      exit `syntax_error'
    }

    * Ensures that the variable name is not yet taken by an original variable
    local varname_is_taken : list varname in original_varlist
    if `varname_is_taken' {
      noi display as error `"cannot create variable `varname': varname already taken in original dataset"'
      exit `syntax_error'
    }

    * Operations that may be performed:
    * - Single Line:
    *   - rename + [destring/tostring] of existing variable
    *   - simple expression in parenthesis, like (mpg*30) or (mpg*mpg)
    * - Multiple Lines:
    *   - recoding of existing variable(s)

    * If it is multiple lines it is surely a recoding, so 2 conditions are checked
    if `Lmin'!=`Lmax' {
      * 1. the crosswalk file must have recoding columns (has_recoding)
      if `has_recoding' == 0 {
        noi display as error `"cannot create variable `varname': it is a recoding over multiple lines, but recoding columns were not provided"'
        exit `syntax_error'
      }
      * 2. the original from_var must exist (may be different in every line)
      forvalues line=`Lmin'(1)`Lmax' {
        local v_original_thisline "`=from_var[`line']'"
        local v_original_exists : list v_original_thisline in original_varlist
        if `v_original_exists' == 0 {
          noi display as error `"cannot create variable `varname': it is a recoding over multiple lines, based on {it:`v_original_thisline'}, not found in the original dataset"'
          exit `syntax_error'
        }
      }
      local this_varname = "recoding"
    }

    * If it is a single line, it can be a rename/tostring/destring or expression
    else {
      local v_original_thisline "`=from_var[`Lmin']'"
      local v_original_exists : list v_original_thisline in original_varlist
      * Based on existing original_variable means it is a rename/tostring/destring
      if `v_original_exists' == 1 {
        local this_varname = "renaming"
      }

      * Not an existing original_variable means it is an expression
      else {
        * To be valid, the expression should start/end with ( & )
        if substr(`"`v_original_thisline'"', 1, 1) != "(" | substr(`"`v_original_thisline'"', -1, 1) != ")" {
          noi display as error `"cannot create variable `varname': it makes reference to `v_original_thisline' which should be either an existing variable or (expression of existing variables)"'
          exit `syntax_error'
        }
        * And be numeric without value (it will become a dummy)
        if `to_string' == 1 {
        * ATTENTION!!!! WHAT IF THIS COLUMN IS NUMERIC???
          noi display as error `"cannot create target variable `varname': it must be of to_type numeric, as it will become a dummy based on the expression `v_original_thisline'"'
          exit `syntax_error'
        }
        if `has_recoding' == 1 {
          if "`=to_value[`line']'" != "" {
            noi display as error `"cannot create target variable `varname': no to_value should be specified for it, as it will become a dummy based on the expression `v_original_thisline'"'
            exit `syntax_error'
          }
        }
        local this_varname = "expression"
      }

    }

    * Check if a valuelabel should be created for this new variable
    if `has_valuelabel' == 1 {
      quietly tab to_labelvalues if to_var == "`varname'"
      if `r(r)' == 0 local to_valuelabel = 0
      else           local to_valuelabel = 1
    }
    else local to_valuelabel = 0


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


      * ATTENTION!!!! WHAT IF THIS COLUMN IS NUMERIC???

      * If there is no to_value, it should just replace for from_var
      if `has_recoding' == 0 `fw' `"replace `varname' = `=from_var[`line']' "' _n
      else {
        if "`=to_value[`line']'" == "" `fw' `"replace `varname' = `=from_var[`line']' "' _n

        * If there is some to_value, writes the line in two steps
        else {
          * First step is to replace variable with the to_value
          if `to_string'   `fw' `"replace `varname' = "`=to_value[`line']'" "'
          else             `fw' `"replace `varname' =  `=to_value[`line']'  "'

          * If there is no values correspondence (at all or for this variable), ends the line
          if `has_recoding' == 0                  `fw' `" "' _n
          else if "`=from_value[`line']'" == ""   `fw' `" "' _n

          * If there is some from_value to recode from, continues the line as an if condition
          else {

            * But before the if, needs a boolean for original variable being a string/numeric
            if      "``=from_var[`line']'_type'" == "string"  local from_string = 1
            else if "``=from_var[`line']'_type'" == "numeric" local from_string = 0
            else {
              noi display as error `"Programming error (not clear the vartype of `=from_var[`line']')"'
              exit `syntax_error'
            }

            * Finish that replace line using or not using quotes
            if `from_string'   `fw' `" if `=from_var[`line']' == "`=from_value[`line']'" "' _n
            else               `fw' `" if `=from_var[`line']' ==  `=from_value[`line']'  "' _n
          }
        }

        if `to_valuelabel' {
          if "`=to_labelvalues[`line']'" != "" ///
          `fw' `"label define `varname' `=to_value[`line']' "`=to_labelvalues[`line']'", modify"' _n
        }
      }
    }

    * Apply label to variable
    if `to_valuelabel'  `fw' `"label values `varname' `varname'"' _n

    * Label new variable
    if `has_varlabel' {
      `fw' `"label var `varname' "`=to_labelvar[`Lmin']'" "' _n
    }
    * DDI marker close
    `fw' `"*</_`varname'_>"' _n _n

  }

  *------------------------------------------------
  * 3.3. Final lines in the dofile being created
  *------------------------------------------------

  * Keep only specified original variables and the new ones
  if "`keeping'" == "" local varlist_to_keep "`target_varlist'"
  if "`keepall'" != "" local varlist_to_keep : list original_varlist | target_varlist
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
