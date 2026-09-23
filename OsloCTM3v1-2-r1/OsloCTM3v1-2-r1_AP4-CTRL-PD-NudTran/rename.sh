#!/bin/bash
if [[ $# -eq 0 ]]
   then echo "usage: ${0} <file>"
   exit 1
fi


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
cmd_nco="ncks -O -4 --chunk_policy nco"
cmd_cdo="cdo -O -f nc4 -k auto copy"
threedcmd="cdo -O -f nc4 -k auto copy"

# That's the config: var_name:aerocom_var_name:lowest level
3d_arr=(\
"co:concco:1" \
"hno3:vmrhno3:1" \
"no2:concno2:1" \
"no:concno:1" \
"o3:vmro3:1" \
"so2:concso2:1" \
)

# var lists
#make a varlist from user friendly definition above
for ((i=0; i < ${#3d_arr[*]}; i += 1))
   do CciVars[${i}]=`echo ${3d_arr[${i}]} | cut -d= -f2`
   AerocomVars[${i}]=`echo ${3d_arr[${i}]} | cut -d= -f1`
done

echo ${CciVars[*]}
echo ${#CciVars[*]}


set -x
for file in "$@"
   do echo ${file}
   cmd=${cmd_nco}
   # special treatment for 3d files...
   if [[ ${file} =~ .*Level_.* ]]
      then
      cmd=${threedcmd}
   fi

   _var=$(basename ${file} | rev | cut -d_ -f4 | rev)
   

expname=`dirname ${file} | rev | cut '-d/' -f1 | rev`
#adjust the experiment name to standard
if [[ ${expname} == 'EXP-SS-DUST' ]]
then
expname='EXP-DUST-SS'
fi

#outfile=`basename ${file}`
#outfile="./${outfile}3"
outfile=`basename ${file} | sed -e "s/MATCH/MATCH\.cams61\.${expname}/g"`
outmodelname=`echo ${outfile} | cut -d_ -f2`
outdir="${basedir}/${outmodelname}/renamed/"
if [[ ! -d ${outdir} ]]
then 
mkdir -p ${outdir}
fi
outfile="${basedir}/${outmodelname}/renamed/${outfile}"
if [[ ! -e ${outfile} ]]
then echo "output file: ${outfile}"
${cmd} ${file} ${outfile}
else
if [[ ${updateflag} -eq 0 ]]
then
echo "warning: target file ${outfile} exists! skipping..."
else
echo "updating target file ${outfile}"
backupoutdir="${basedir}/${outmodelname}/backup/"
if [[ ! -d ${backupoutdir} ]]
		  then
		  mkdir -p ${backupoutdir}
fi
backupfile=`basename ${outfile}`
mv ${outfile} "${backupoutdir}/${backupfile}.${date}"
${cmd} ${file} ${outfile}
fi
fi

done

