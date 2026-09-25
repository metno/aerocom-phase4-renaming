#!/bin/bash

#script to create data that is readable by pyaerocom

IFS=$(echo -en "\n\b")

usage() { echo "Usage: $0 [-U] <infiles>" 
        echo "-U to update existing file with backup"
        exit 0
}

if [[ $# -eq 0 ]]
   then usage
fi

updateflag=0

while getopts ":U" opt; do
  case $opt in
    U)
      echo "-U was triggered!" >&2
      arg=${OPTARG}
      updateflag=1
                #remove the -U from $@
                shift 1
      ;;
    \?)
      usage
      ;;
  esac
done

date=$(date '+%Y%m%d_%H%M%S')
RND=${RANDOM}
tmpfile="./dummy_${RND}.nc"
cmd_nco="ncks -O -4 --chunk_policy nco"
cmd_cdo="cdo -O -f nc4 -k auto copy"
threedcmd="cdo -O -f nc4 -k auto copy"


# tools, because mamba run -n cdo cd is massively slower
# e.g. cdo=$(mamba run -n cdo which cdo) would also work, but is also quite slow
CDO='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/cdo/bin/cdo'
NCKS='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncks'
NCDUMP='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncdump'
NCRENAME='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncrename'
NCAP2='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncap2'
NCATTED='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncatted'
NCWA='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncwa'

set -x
basedir='/lustre/storeB/project/aerocom/aerocom-users-database/AEROCOM-PHASE-IV/'

declare -A aerocom_vars
aerocom_vars[mmrso4]="concso4"
aerocom_vars[ta]="ts"
aerocom_vars[pfull]="ps"


create_dir () {
    dir=${1}
    if [[ ! -d ${outdir} ]]
        then 
        mkdir -p ${outdir}
        echo 'created'
    else
        echo 'exists'
    fi
    }

# for unit adjustments we need the temperature...
# prepare yearly files of that...

for file in "$@"
	do echo ${file}
	var=$(basename ${file} | cut -d_ -f3)
	calc_var=${aerocom_vars[${var}]}
	outfile=$(echo ${file} | sed -e "s/${var}_/${calc_var}_/g")
	ts_file=$(echo ${file} | sed -e "s/${var}_/ts_/g")
	ps_file=$(echo ${file} | sed -e "s/${var}_/ps_/g")
	#formula: res_cube = ps / 287.0 / ts * mmrso4_surf * 1.0e9
	#add ts
	cp ${file} ${tmpfile}
	# add the variable ts to the file
	${NCKS} -A -v ts ${ts_file} ${tmpfile}
	# also add the variable ps if the file exists
	if [[ -f ${ps_file} ]]
		then 
		${NCKS} -A -v ps ${ps_file} ${tmpfile}
	fi

	# that's the actual calculation
	ncap2 -O -s "${calc_var}=ps/287.0/ts*${var}*1.0e9" ${tmpfile} ${outfile}
	# adjust attributes
	${NCATTED} -O -a "standard_name,${calc_var},o,c,mass_concentration_of_sulfate_ambient_aerosol_particles_in_air" \
		-a "units,${calc_var},o,c,ug m-3" \
		${outfile}
	rm ${tmpfile}

done
