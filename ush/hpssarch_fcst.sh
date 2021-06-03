#!/bin/ksh
set -x

###################################################
# Fanglin Yang, 20180318
# --create bunches of files to be archived to HPSS
###################################################


type=${1:-gfs}                ##gfs, gdas, enkfgdas or enkfggfs

CDATE=${CDATE:-2018010100}
PDY=$(echo $CDATE | cut -c 1-8)
cyc=$(echo $CDATE | cut -c 9-10)
OUTPUT_FILE=${OUTPUT_FILE:-"netcdf"}
OUTPUT_HISTORY=${OUTPUT_HISTORY:-".true."}
SUFFIX=${SUFFIX:-".nc"}
if [ $SUFFIX = ".nc" ]; then
  format="netcdf"
else
  format="nemsio"
fi

#-----------------------------------------------------
  FHMIN_GFS=${FHMIN_GFS:-0}
  FHMAX_GFS=${FHMAX_GFS:-384}
  FHOUT_GFS=${FHOUT_GFS:-3}
  FHMAX_HF_GFS=${FHMAX_HF_GFS:-120}
  FHOUT_HF_GFS=${FHOUT_HF_GFS:-1}

  rm -f ${type}a.txt
  rm -f ${type}_pgrb2b.txt
  rm -f ${type}_flux.txt
  rm -f ${type}b.txt
  rm -f ${type}_${format}b.txt
  rm -f ${type}_restartb.txt
  touch ${type}a.txt
  touch ${type}_pgrb2b.txt
  touch ${type}_flux.txt
  touch ${type}b.txt
  touch ${type}_${format}b.txt
  touch ${type}_restartb.txt

  dirpath="${type}.${PDY}/${cyc}/atmos/"
  dirname="./${dirpath}"

  head="${type}.t${cyc}z."

  #..................
  echo  "./logs/${CDATE}/${type}*.log                          " >>${type}a.txt
  echo  "${dirname}avno.t${cyc}z.cyclone.trackatcfunix         " >>${type}a.txt
  echo  "${dirname}avnop.t${cyc}z.cyclone.trackatcfunix        " >>${type}a.txt
  echo  "${dirname}trak.${type}o.atcfunix.${PDY}${cyc}         " >>${type}a.txt
  echo  "${dirname}trak.${type}o.atcfunix.altg.${PDY}${cyc}    " >>${type}a.txt
  echo  "${dirname}storms.${type}o.atcf_gen.${PDY}${cyc}       " >>${type}a.txt
  echo  "${dirname}storms.${type}o.atcf_gen.altg.${PDY}${cyc}  " >>${type}a.txt
  echo  "${dirname}${head}atminc${SUFFIX}                      " >>${type}a.txt

  fh=0
  while [ $fh -le $FHMAX_GFS ]; do
    fhr=$(printf %03i $fh)
    echo  "${dirname}${head}pgrb2b.0p25.f${fhr}             " >>${type}_pgrb2b.txt
    echo  "${dirname}${head}pgrb2b.0p25.f${fhr}.idx         " >>${type}_pgrb2b.txt
    if [ -s $ROTDIR/${dirpath}${head}pgrb2b.0p50.f${fhr} ]; then
       echo  "${dirname}${head}pgrb2b.0p50.f${fhr}         " >>${type}_pgrb2b.txt
       echo  "${dirname}${head}pgrb2b.0p50.f${fhr}.idx     " >>${type}_pgrb2b.txt
    fi

    echo  "${dirname}${head}sfluxgrbf${fhr}.grib2           " >>${type}_flux.txt
    echo  "${dirname}${head}sfluxgrbf${fhr}.grib2.idx       " >>${type}_flux.txt

    echo  "${dirname}${head}pgrb2.0p25.f${fhr}              " >>${type}a.txt
    echo  "${dirname}${head}pgrb2.0p25.f${fhr}.idx          " >>${type}a.txt
    echo  "${dirname}${head}logf${fhr}.txt                  " >>${type}a.txt

    if [ -s $ROTDIR/${dirpath}${head}pgrb2.0p50.f${fhr} ]; then
       echo  "${dirname}${head}pgrb2.0p50.f${fhr}          " >>${type}b.txt
       echo  "${dirname}${head}pgrb2.0p50.f${fhr}.idx      " >>${type}b.txt
    fi
    if [ -s $ROTDIR/${dirpath}${head}pgrb2.1p00.f${fhr} ]; then
       echo  "${dirname}${head}pgrb2.1p00.f${fhr}          " >>${type}b.txt
       echo  "${dirname}${head}pgrb2.1p00.f${fhr}.idx      " >>${type}b.txt
    fi

    inc=$FHOUT_GFS
    if [ $FHMAX_HF_GFS -gt 0 -a $FHOUT_HF_GFS -gt 0 -a $fh -lt $FHMAX_HF_GFS ]; then
     inc=$FHOUT_HF_GFS
    fi

    fh=$((fh+inc))
  done

  #..................
  if [ $OUTPUT_HISTORY = ".true." ]; then
  fh=0
  while [ $fh -le $FHMAX_FITS ]; do
    fhr=$(printf %03i $fh)
    echo  "${dirname}${head}atmf${fhr}${SUFFIX}        " >>${type}_${format}b.txt
    echo  "${dirname}${head}sfcf${fhr}${SUFFIX}        " >>${type}_${format}b.txt
    fh=$((fh+6))
  done
  fi

  #..................
  if [ $replay -gt 0 ]; then
    echo  "${dirname}RESTART " >>${type}_restartb.txt

    GDATE=`$NDATE -6 $CDATE`
    PDY=$(echo $GDATE | cut -c 1-8)
    cyc=$(echo $GDATE | cut -c 9-10)
    dirpath="${type}.${PDY}/${cyc}/atmos/"
    dirname="./${dirpath}"
    echo  "${dirname}RESTART " >>${type}_restartbm6.txt
  fi

exit 0

