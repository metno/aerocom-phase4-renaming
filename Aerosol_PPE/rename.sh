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


# e.g. cdo=$(mamba run -n cdo which cdo) would also work, but is also quite slow
cdo='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/cdo/bin/cdo'
ncks='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncks'
ncdump='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncdump'
ncrename='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncrename'
ncap2='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncap2'
ncatted='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncatted'
ncwa='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncwa'




set -x
basedir='/lustre/storeB/project/aerocom/aerocom-users-database/AEROCOM-PHASE-IV/Aerosol_PPE/'
Model=`pwd | rev | cut -d/ -f1 | rev`
outdir="${basedir}/${Model}/renamed/"
lowest_level=0


declare -A aerocom_vars
aerocom_vars[o3]="vmro3"
# aerocom_vars[mmrso4]="mmrso4"
aerocom_vars[ta]="ts"
aerocom_vars[pfull]="ps"
aerocom_vars[no2]="vmrno2"
aerocom_vars[so2]="vmrso2"
aerocom_vars[no]="vmrno"
aerocom_vars[co]="vmrco"
aerocom_vars[nh3]="vmrnh3"

declare -A aerocom_time_codes
aerocom_time_codes[mon]="monthly"

# default is Surface, so only variables not being Surface must be listed here
declare -A aerocom_bla_codes
aerocom_bla_codes["od550aer"]="Column"


# for unit adjustments we need the temperature...
# prepare yearly files of that...

for file in "$@"
   do echo ${file}
   if [[ ! -e ${file} ]]
      then echo "${file} not found! skipping..."
      continue
   fi
   cmd=${cmd_nco}
   threedflag=0
   # special treatment for 3d files...
   if [[ ${file} =~ .*Level_.* ]]
      then
      cmd=${threedcmd}
      threedflag=1
   fi



	_var=$(basename ${file} | cut -d_ -f1)
	timecode=$(basename ${file} | cut -d_ -f3)
   timecode=${aerocom_time_codes[${timecode}]}
	# split file into years
   # in principle not necessary here, but it adds the years to the temp files
	${cdo} -O splityear ${file} splityear_${RND}_
   
	# extract lowest layer if necessary
	for yearfile in $(find . -name "splityear_${RND}_*.nc" | sort)
		do echo ${yearfile}
		year=$(echo ${yearfile} | cut -d_ -f3 | cut -d. -f1)
		#${CDO} -O splitlevel,0.992556 ${yearfile} splitlevel_${RND}_
      if [[ threedflag -eq 1 ]]
         then
		   ${NCKS} -O -d lev,${lowest_level} -v ${var} ${yearfile} ${yearfile}
		   ${NCWA} -O -a lev ${yearfile} ${yearfile}
      fi
      if [[ -v aerocom_vars[${_var}] ]]
      then
         _aerocom_var=${aerocom_vars[${_var}]}
         ${ncrename} -O -v ${_var},${aerocom_vars[${_var}]} ${yearfile}
      else
         _aerocom_var=${_var}
      fi
      # set the bla code
      if [[ -v aerocom_bla_codes[${_var}] ]]
         then _bla_code=${aerocom_bla_codes[${_var}]}
      else
         _bla_code="Surface"
      fi
      # make sure to put in a gregorian calenda since pyaerocom handles only that
      ${ncatted} -O -a "calendar,time,o,c,gregorian" ${yearfile}
		outfile="${Model}_${_aerocom_var}_${_bla_code}_${year}_${timecode}.nc"
      
		mv ${yearfile} renamed/${outfile}
		# rm ${yearfile} 
	done

done

