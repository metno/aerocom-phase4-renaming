# aerocom-phase4-renaming
project to contain renaming scripts to make aerocom phase 4 data readable by pyaerocom / aeroval


## conventions
- one renaming script per model
- directory structure is `model name` and then the model specific data
- no data files in the repository
- naming for rename scripts is `rename.sh`
- in order to allow hyphens (`-`) in the model name, we removed the trailing `aerocom` in the model files

## bin directory
The `bin` directory contains scripts that are commonly used for all models. At the time
of this writing there's only the script [calc_concso4](./bin/calc_concso4.sh) in there
that converts the units of the variable `mmrso4` from `kg kg-1` to `ug m-3`

### description of `calc_concso4.sh`
script that uses the variables `mmrso4`, `ts` and `ps` to convert the unit to `ug m-3`. Takes a file list with 
model files of the variable `mmrso4` as parameters and uses time corresponding models files with the variables
`ts` and `ps` for the calculation.
