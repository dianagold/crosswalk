{smcl}
{* *! version 0.1 12 FEB 2020}{...}
{cmd:help crosswalk}{...}
{right:also see:  {help "rename"} {help "recode"} {help "destring"} {help "label"}}
{hline}

{title:Title}

{pstd}
{hi:crosswalk} {hline 2} Transforms variables using an external crosswalk csv

{title:Syntax}

{pstd} Transforms variables using an external crosswalk csv. It is especially useful when constructing master data sets from multiple smaller data sets that do not name or encode variables consistently across files. It is an automated and scalable substitute for performing a sequence of rename and recode of original variables.

{p 8 15 2}
{cmd:crosswalk} {opt using }{it:filename.csv}, [ {opt keeping(varlist)}]
{p_end}

{synoptset 30 tabbed}{...}
{synopthdr :Options}
{synoptline}
{synopt :{opt using}}indicates the {it:filename.csv} to be used as crosswalk (set of instructions to create new variables) [{it:required}]{p_end}
{synopt :{opt keeping(varlist)}}original variables from the original dataset that should be kept (original variables are dropped by default) [{it:optional}]{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:crosswalk} transforms variables using an external crosswalk csv.

{pstd} The operations of {cmd:crosswalk} always create new variables, by:

{pstd} ( 1 ) copying values from an original variable (exactly as they are)

{pstd} ( 2 ) copying values from an original variable, with a destring/tostring

{pstd} ( 3 ) recoding an original variable

{pstd} ( 4 ) performing simple arithmetic operations over original variables (ie: addition / subtraction / multiplication / division)

{pstd} ( 5 ) deriving an indicator (0/1) from a condition on an original variable

{pstd} Additionally, the newly created variable and its values can be labeled, by using the corresponding columns in the crosswalk csv.

{dlgtab:Options}

{phang} {cmdab:using} {it:filename.csv}{cmd:} indicates the csv file to be used as crosswalk ()

{phang} {cmdab:keeping(}{it:varlist}{cmd:)} original variables from the original dataset that should be kept


{title:Example}

{pstd}All operations that can be performed by {cmd:crosswalk} can be exemplified with the ancillary file {it: crosswalk_auto.csv} included in this package. First, you will need to download the file:{p_end}
{phang2}. {stata `"net get crosswalk, from("https://raw.githubusercontent.com/dianagold/crosswalk/master/src") replace"'}{p_end}

{pstd}Before using the {cmd:crosswalk}, you will need to have the {it:auto} dataset loaded in memory:{p_end}
{phang2}. {stata `"sysuse auto, clear"'}{p_end}

{pstd}A handy way to visualize the changes in the dataset is to compare the codebook before and after {cmd:crosswalk}:{p_end}
{phang2}. {stata `"codebook, compact"'}{p_end}

{pstd}Now we finally apply the {cmd:crosswalk}:{p_end}
{phang2}. {stata `"crosswalk using "crosswalk_auto.csv", keeping("make price mpg")"'}{p_end}

{pstd}We can now look at the resulting dataset:{p_end}
{phang2}. {stata `"codebook, compact"'}{p_end}


{title:Author}

{pstd}Diana Goldemberg{p_end}
{pstd}diana_goldemberg@g.harvard.edu{p_end}


{title:Acknowledgements}

{phang}This program was inspired by similar efforts made by:{p_end}
{phang}* Sally Hudson & team functions {cmd:renamefrom} and {cmd:encodefrom}, available in SSC{p_end}
{phang}* Hongxi Zhao & J.P Azevedo template for harmonizing MELQO surveys{p_end}

{phang}You can see the code, make comments to the code, report bugs, and submit additions or
      edits to the code through the {browse "https://github.com/dianagold/crosswalk":GitHub repository of crosswalk}.{p_end}
