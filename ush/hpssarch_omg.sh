#!/bin/ksh
set -x

###################################################
# Fanglin Yang, 20180318
# --create bunches of files to be archived to HPSS
###################################################


type=${1:-gfs}                ##gfs, gdas

CDATE=${CDATE:-2018010100}
PDY=$(echo $CDATE | cut -c 1-8)
cyc=$(echo $CDATE | cut -c 9-10)

rm -f ${type}omg.txt
touch ${type}omg.txt

dirpath="${type}.${PDY}/${cyc}/atmos/"
dirname="./${dirpath}"
head="${type}.t${cyc}z."
SUFFIX=${SUFFIX:-".nc"}

if [ -s $ROTDIR/${dirname}${head}gsistat ]; then
   echo  "${dirname}${head}gsistat" >>${type}omg.txt
fi
if [ -s $ROTDIR/${dirpath}${head}cnvstat ]; then
   echo  "${dirname}${head}cnvstat" >>${type}omg.txt
fi
if [ -s $ROTDIR/${dirpath}${head}oznstat ]; then
   echo  "${dirname}${head}oznstat" >>${type}omg.txt
fi
if [ -s $ROTDIR/${dirpath}${head}radstat ]; then
   echo  "${dirname}${head}radstat" >>${type}omg.txt
fi

# run replayinc for free mode for diagnostic purpose
# atminc.nc is in standard archive for other mode
echo "${dirname}${head}atminc*" >>${type}omg.txt

exit 0

