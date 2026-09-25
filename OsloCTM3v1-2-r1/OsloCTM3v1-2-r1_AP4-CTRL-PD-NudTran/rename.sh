#!/bin/bash
if [[ $# -eq 0 ]]
   then echo "usage: ${0} <file>"
   exit 1
fi

# tools, because mamba run -n cdo cd is massively slower
# e.g. cdo=$(mamba run -n cdo which cdo) would also work, but is also quite slow
cdo='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/cdo/bin/cdo'
ncks='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncks'
ncdump='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncdump'
ncrename='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncrename'
ncap2='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncap2'
ncatted='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncatted'
ncwa='/modules/rhel8/user-apps/aerocom/miniforge-23.11/envs/nco/bin/ncwa'


#we assume that the downloaded data is organiosed as 
# <basedir>/<modeldir>/download/<experiment_id>/filename.nc

# outdir will be 
# <basedir>/<modeldir>/renamed
# with model dir like
basedir='/lustre/storeB/project/aerocom/aerocom-users-database/AEROCOM-PHASE-IV/'
Model=$(pwd | rev | cut -d/ -f1 | rev)

updateflag=0

date=$(date '+%Y%m%d_%H%M%S')
RND=${RANDOM}
tmpfile="./dummy_${RND}.nc"
cmd_nco="${ncks} -O -4 --chunk_policy nco"
cmd_cdo="${cdo} -O -f nc4 -k auto copy"
threedcmd="${cdo} -O -f nc4 -k auto copy"

##### Model specific part start
lowest_level=0
# All vars we can handle should be in here
declare -A aerocom_vars
aerocom_vars[o3]="vmro3"
aerocom_vars[mmrso4]="mmrso4"
aerocom_vars[ta]="ts"
aerocom_vars[pfull]="ps"
aerocom_vars[no2]="vmrno2"
aerocom_vars[so2]="vmrso2"
aerocom_vars[no]="vmrno"
aerocom_vars[co]="vmrco"
aerocom_vars[nh3]="vmrnh3"


##### Model specific part end


set -x
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

   _var=$(basename ${file} | rev | cut -d_ -f4 | rev)
   _file_rest=$(echo ${file} | rev | cut -d_ -f1-3 | rev)
   _basedir=$(dirname ${file})
   outdir=$(echo ${_basedir} | sed -e "s/download/renamed/g")
   if [[ ! -d ${outdir} ]]
      then 
      mkdir -p ${outdir}
   fi
   break_flag=0
   if [[ -v aerocom_vars[${_var}] ]]
   then
      _aerocom_var=${aerocom_vars[${_var}]}
   else
      _aerocom_var=${_var}
   fi
   outfile="${outdir}/${Model}_${_aerocom_var}_${_file_rest}"
   if [[ -e ${outfile} ]]
      then

      if [[ ${updateflag} -eq 0 ]]
         then
         echo "warning: target file ${outfile} exists! skipping..."
         continue
      else
         echo "updating target file ${outfile}"
      fi
   fi

   if [[ ${threedflag} -eq 1 ]]
   then #3d file: extract lowest layer
      outfile=$(echo ${outfile} | sed -e "s/_ModelLevel_/_Surface_/g")
      ${ncks} -O -4 --chunk_policy nco -d lev,${lowest_level} -v ${_var} ${file} ${outfile}
      ${ncwa} -O -a lev ${outfile} ${outfile}
      ${ncrename} -O -v ${_var},${_aerocom_var} ${outfile}
      # ${cmd} ${tmpfile} ${outfile}
   else
      ${cmd} ${file} ${outfile}
   fi


done

