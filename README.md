# Crosswalk
Stata program to transform variables using an external crosswalk csv file.

It is especially useful when constructing master data sets from multiple smaller data sets that do not name or encode variables consistently across files.

## Package description

'CROSSWALK': transforms variables using an external crosswalk csv

Keywords: _crosswalk | encode | rename | translate_

## Installation

  **crosswalk** is currently not published on [SSC](https://www.stata.com/support/ssc-installation/), so it cannot be installed through `ssc install`.

  If you want to install the most recent carefully curated version of  **crosswalk** then you can use the code below:
```
net install dependencies, from("https://raw.githubusercontent.com/dianagold/crosswalk/master/src") replace
```

  Please check the help file, installed with the package, for more information on how to use **crosswalk**.

## Author

  **Diana Goldemberg** [ [diana_goldemberg@g.harvard.edu](mailto:diana_goldemberg@g.harvard.edu) ]

### Acknowledgements

This program was inspired by similar efforts made by:
* Sally Hudson & team functions [renamefrom + encodefrom](https://github.com/slhudson/rename-and-encode)
* Hongxi Zhao & J.P Azevedo template for harmonizing MELQO surveys (no public link exist)
